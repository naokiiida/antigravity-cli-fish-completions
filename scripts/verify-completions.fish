#!/usr/bin/env fish
#
# Verification script for fish completion script
#
# Tests that completions/agy.fish can be sourced and provides expected
# completions. Fish can source completions and query them directly via
# `complete -C`, so no expect/interactive testing is needed.
#
# Exit codes:
#   0 - Verification passed
#   1 - Verification failed

set -l script_dir (status dirname)
set -l repo_root (builtin realpath "$script_dir/..")
set -l completion_file "$repo_root/completions/agy.fish"

if not test -f "$completion_file"
    echo "Error: Completion file not found: $completion_file"
    exit 1
end

echo "Verifying completion script: $completion_file"

set -l total_tests 10

# Test 1: Syntax check
echo "  [1/$total_tests] Running syntax check..."
if not fish -n "$completion_file" 2>&1
    echo ""
    echo "FAIL: Syntax error in $completion_file"
    exit 1
end

# Test 2: Source and check basic completions
echo "  [2/$total_tests] Checking subcommand completions..."
source "$completion_file"
set -l completions (complete -C "agy " 2>/dev/null)
if test (count $completions) -lt 5
    echo "FAIL: Too few completions registered (got "(count $completions)")"
    exit 1
end

set -l required_subcommands agent agents changelog help install mcp mic-serve models plugin plugins remote-control update
for cmd in $required_subcommands
    if not string match -q "*$cmd*" -- $completions
        echo "FAIL: Missing subcommand: $cmd"
        exit 1
    end
end

# Test 3: Check mcp subcommand completions
echo "  [3/$total_tests] Checking mcp subcommand completions..."
set -l mcp_completions (complete -C "agy mcp " 2>/dev/null)
for subcmd in add list remove enable disable
    if not string match -q "*$subcmd*" -- $mcp_completions
        echo "FAIL: Missing mcp subcommand: $subcmd"
        exit 1
    end
end

# Test 4: Check flag completions
echo "  [4/$total_tests] Checking flag completions..."
set -l flag_completions (complete -C "agy -" 2>/dev/null)
for flag in continue conversation effort mode model output-format sandbox print dangerously-skip-permissions
    if not string match -q "*$flag*" -- $flag_completions
        echo "FAIL: Missing flag: --$flag"
        exit 1
    end
end

# Test 5: Check plugin subcommand completions
echo "  [5/$total_tests] Checking plugin subcommand completions..."
set -l plugin_completions (complete -C "agy plugin " 2>/dev/null)
for subcmd in list import install uninstall enable disable validate link
    if not string match -q "*$subcmd*" -- $plugin_completions
        echo "FAIL: Missing plugin subcommand: $subcmd"
        exit 1
    end
end

# Test 6: Helper function existence
echo "  [6/$total_tests] Checking helper functions..."
for fn in __fish_agy_conversations __fish_agy_agents __fish_agy_mcp_servers \
          __fish_agy_mcp_enabled_servers __fish_agy_mcp_disabled_servers \
          __fish_agy_installed_plugins __fish_agy_enabled_plugins __fish_agy_disabled_plugins
    if not functions -q $fn
        echo "FAIL: Missing helper function: $fn"
        exit 1
    end
end

# Test 7: Check remote-control subcommand completions
echo "  [7/$total_tests] Checking remote-control subcommand completions..."
set -l rc_completions (complete -C "agy remote-control " 2>/dev/null)
for subcmd in start status stop
    if not string match -q "*$subcmd*" -- $rc_completions
        echo "FAIL: Missing remote-control subcommand: $subcmd"
        exit 1
    end
end

# Test 8: Check install subcommand flag completions
echo "  [8/$total_tests] Checking install subcommand flags..."
set -l install_completions (complete -C "agy install -" 2>/dev/null)
for flag in dir skip-aliases skip-path
    if not string match -q "*$flag*" -- $install_completions
        echo "FAIL: Missing install flag: --$flag"
        exit 1
    end
end

# Test 9: Flag value completions (enumerated flags)
echo "  [9/$total_tests] Checking flag value completions..."
set -l effort_completions (complete -C "agy --effort " 2>/dev/null)
for val in low medium high xhigh max
    if not string match -q "*$val*" -- $effort_completions
        echo "FAIL: Missing effort value: $val"
        exit 1
    end
end

set -l mode_completions (complete -C "agy --mode " 2>/dev/null)
for val in accept-edits auto plan
    if not string match -q "*$val*" -- $mode_completions
        echo "FAIL: Missing mode value: $val"
        exit 1
    end
end

# Test 10: No legacy external commands (regression guard)
echo "  [10/$total_tests] Checking for legacy external commands..."
set -l src (cat "$completion_file")
for legacy in "stat -f" "stat -c" "date +%s" "(basename "
    if string match -q "*$legacy*" -- $src
        echo "FAIL: Legacy external command found: $legacy"
        exit 1
    end
end

echo ""
echo "VERIFICATION PASSED"
echo "==================="
echo "All checks passed. "(count $completions)" top-level completions registered."
exit 0
