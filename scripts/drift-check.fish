#!/usr/bin/env fish
#
# Drift detection: compare fish completions against actual `claude --help` output.
#
# Requires: claude CLI in PATH
#
# Note: This script sources the completion file and registers completions
# in the running shell. Run as `fish scripts/drift-check.fish` (subprocess)
# rather than `source scripts/drift-check.fish` in an interactive session.
#
# Exit codes:
#   0 - No drift detected (or only hidden-command INFO)
#   1 - Drift detected (completions missing something from --help)
#   2 - claude CLI not available

set -l script_dir (status dirname)
set -l repo_root (builtin realpath "$script_dir/..")
set -l completion_file "$repo_root/completions/claude.fish"

# --- Prerequisites -----------------------------------------------------------

if not command -q claude
    echo "ERROR: claude CLI not found in PATH"
    exit 2
end

if not test -f "$completion_file"
    echo "ERROR: Completion file not found: $completion_file"
    exit 1
end

source "$completion_file"

set -l drift 0
set -l warnings 0

# --- Helpers ------------------------------------------------------------------

# Parse subcommands from a help output.
# Reads stdin, prints one subcommand per line (expanding aliases like plugin|plugins).
#
# Format: "  subcmd [options] <args>  Description" — exactly 2-space indent,
# then a word that looks like a command (lowercase, hyphens, pipes for aliases).
# Continuation lines have deeper indent; empty lines or non-matching lines end the section.
function __drift_parse_subcmds
    set -l in_commands 0
    while read -l line
        if string match -q "Commands:" -- $line
            set in_commands 1
            continue
        end
        if test $in_commands -eq 1
            # Only match lines starting with exactly 2 spaces then a command-like word
            # This skips: continuation lines (6+ spaces), Examples:, blank lines, comments
            set -l cmd (string match -rg '^  ([a-z][-a-z0-9|]+)' -- $line)
            if test -n "$cmd"
                # Skip "help [command]" — not a real subcommand for completion
                string match -q "help" -- $cmd; and continue
                # Expand aliases: "plugin|plugins" → "plugin" "plugins"
                for c in (string split "|" -- $cmd)
                    echo $c
                end
            end
        end
    end
end

# Parse long flags from a help output.
# Only considers lines in the Options section (starts with "  -" or "  --").
function __drift_parse_flags
    set -l in_options 0
    while read -l line
        if string match -q "Options:" -- $line
            set in_options 1
            continue
        end
        # Options section ends at Commands: or end of input
        if string match -q "Commands:" -- $line
            set in_options 0
            continue
        end
        if test $in_options -eq 1
            # Only parse flag lines (start with spaces then -)
            if string match -qr '^\s+-' -- $line
                for flag in (string match -rga -- '--([a-zA-Z][-a-zA-Z0-9]*)' $line)
                    set -l clean (string replace -r '^--' '' -- $flag)
                    if test -n "$clean"
                        echo $clean
                    end
                end
            end
        end
    end | sort -u
end

# Extract completion words from `complete -C` output (strip tab+description).
function __drift_completion_words
    complete -C "$argv[1]" 2>/dev/null | string replace -r '\t.*' ''
end

# Known hidden commands (present in completions but not in --help).
set -l hidden_commands remote-control

# --- Test 1: Top-level subcommands -------------------------------------------

echo "Drift check: top-level subcommands"

set -l help_subcmds (claude --help 2>&1 | __drift_parse_subcmds | sort -u)
set -l comp_subcmds (__drift_completion_words "claude " | string match -rv '^-' | sort -u)

# Check: every help subcommand should appear in completions
for cmd in $help_subcmds
    if not contains -- $cmd $comp_subcmds
        echo "  MISSING in completions: $cmd"
        set drift 1
    end
end

# Check: every completion subcommand should appear in help (or be hidden)
for cmd in $comp_subcmds
    if not contains -- $cmd $help_subcmds
        if contains -- $cmd $hidden_commands
            echo "  INFO: hidden command in completions (OK): $cmd"
        else
            echo "  WARN: in completions but not in --help: $cmd"
            set warnings (math $warnings + 1)
        end
    end
end

if test $drift -eq 0 -a $warnings -eq 0
    echo "  OK"
end

# --- Test 2: Top-level flags -------------------------------------------------

echo "Drift check: top-level flags"

set -l help_flags (claude --help 2>&1 | __drift_parse_flags)
set -l comp_flags (__drift_completion_words "claude -" | string match -rg '^--(.*)')

# Normalize: some flags have aliases (allowedTools → allowed-tools)
# We check that every help flag is present in completions
for flag in $help_flags
    if not contains -- $flag $comp_flags
        # Check common alias patterns (camelCase ↔ kebab-case)
        set -l found 0
        # e.g. "allowed-tools" might cover "--allowedTools"
        if contains -- (string replace -a '-' '' -- $flag) (string replace -a '-' '' -- $comp_flags)
            set found 1
        end
        if test $found -eq 0
            echo "  MISSING in completions: --$flag"
            set drift 1
        end
    end
end

if test $drift -eq 0
    echo "  OK"
end

# --- Test 3: Subcommand trees ------------------------------------------------

# Only check subcommands that have actual sub-subcommands (not positional args).
# `install [target]` uses positional args (stable/latest), not subcommands.
set -l subcmd_checks mcp auth auto-mode plugin

for subcmd in $subcmd_checks
    echo "Drift check: $subcmd subcommands"

    set -l sub_help_cmds (claude $subcmd --help 2>&1 | __drift_parse_subcmds | sort -u)
    set -l sub_comp_cmds (__drift_completion_words "claude $subcmd " | string match -rv '^-' | sort -u)

    set -l test_drift 0
    set -l test_warnings 0

    for cmd in $sub_help_cmds
        if not contains -- $cmd $sub_comp_cmds
            echo "  MISSING in completions: claude $subcmd $cmd"
            set test_drift 1
        end
    end

    for cmd in $sub_comp_cmds
        if not contains -- $cmd $sub_help_cmds
            echo "  WARN: in completions but not in help: claude $subcmd $cmd"
            set test_warnings (math $test_warnings + 1)
        end
    end

    if test $test_drift -eq 0 -a $test_warnings -eq 0
        echo "  OK"
    end

    set drift (math "$drift + $test_drift")
    set warnings (math "$warnings + $test_warnings")
end

# --- Test 4: Subcommand flags ------------------------------------------------

# Check flags for subcommands that have their own flags
set -l flag_checks \
    "mcp add" \
    "install" \
    "auth login" \
    "auth status" \
    "auto-mode critique"

for subcmd in $flag_checks
    echo "Drift check: $subcmd flags"

    set -l subcmd_parts (string split " " -- $subcmd)
    set -l sub_help_flags (claude $subcmd_parts --help 2>&1 | __drift_parse_flags)
    set -l sub_comp_flags (__drift_completion_words "claude $subcmd -" | string match -rg '^--(.*)')

    set -l test_drift 0

    for flag in $sub_help_flags
        if not contains -- $flag $sub_comp_flags
            # Skip -h/--help as it's universally added
            test "$flag" = "help"; and continue
            echo "  MISSING in completions: claude $subcmd --$flag"
            set test_drift 1
        end
    end

    if test $test_drift -eq 0
        echo "  OK"
    end

    set drift (math "$drift + $test_drift")
end

# --- Summary ------------------------------------------------------------------

echo ""
if test $drift -gt 0
    echo "DRIFT DETECTED — completions need updating"
    exit 1
else if test $warnings -gt 0
    echo "PASSED with $warnings warning(s) — completions have extras not in --help"
    exit 0
else
    echo "NO DRIFT — completions match CLI"
    exit 0
end
