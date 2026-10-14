#!/usr/bin/env fish
#
# Verification script for fish completion script
#
# Tests that completions/claude.fish can be sourced and provides expected
# completions. Fish can source completions and query them directly via
# `complete -C`, so no expect/interactive testing is needed.
#
# Exit codes:
#   0 - Verification passed
#   1 - Verification failed

set -l script_dir (status dirname)
set -l repo_root (builtin realpath "$script_dir/..")
set -l completion_file "$repo_root/completions/claude.fish"

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
set -l completions (complete -C "claude " 2>/dev/null)
if test (count $completions) -lt 5
    echo "FAIL: Too few completions registered (got "(count $completions)")"
    exit 1
end

set -l required_subcommands mcp plugin auth agents auto-mode doctor install update setup-token remote-control
for cmd in $required_subcommands
    if not string match -q "*$cmd*" -- $completions
        echo "FAIL: Missing subcommand: $cmd"
        exit 1
    end
end

# Test 3: Check mcp subcommand completions
echo "  [3/$total_tests] Checking mcp subcommand completions..."
set -l mcp_completions (complete -C "claude mcp " 2>/dev/null)
for subcmd in add list remove serve get add-json add-from-claude-desktop reset-project-choices
    if not string match -q "*$subcmd*" -- $mcp_completions
        echo "FAIL: Missing mcp subcommand: $subcmd"
        exit 1
    end
end

# Test 4: Check flag completions
echo "  [4/$total_tests] Checking flag completions..."
set -l flag_completions (complete -C "claude -" 2>/dev/null)
for flag in print model continue resume help version bare brief effort permission-mode
    if not string match -q "*$flag*" -- $flag_completions
        echo "FAIL: Missing flag: --$flag"
        exit 1
    end
end

# Test 5: Check plugin i alias
echo "  [5/$total_tests] Checking plugin i alias..."
set -l plugin_completions (complete -C "claude plugin " 2>/dev/null)
set -l plugin_words (string replace -r '\t.*' '' -- $plugin_completions)
if not contains -- i $plugin_words
    echo "FAIL: Missing plugin alias: i"
    exit 1
end

# Test 6: Helper function existence
echo "  [6/$total_tests] Checking helper functions..."
for fn in __fish_claude_mcp_servers __fish_claude_sessions __fish_claude_agents \
          __claude_installed_plugins __claude_enabled_plugins __claude_disabled_plugins \
          __claude_available_plugins __claude_marketplace_names
    if not functions -q $fn
        echo "FAIL: Missing helper function: $fn"
        exit 1
    end
end

# Test 7: auth subcommand completions
echo "  [7/$total_tests] Checking auth subcommand completions..."
set -l auth_completions (complete -C "claude auth " 2>/dev/null)
for subcmd in login logout status
    if not string match -q "*$subcmd*" -- $auth_completions
        echo "FAIL: Missing auth subcommand: $subcmd"
        exit 1
    end
end

# Test 8: plugin marketplace subcommand completions
echo "  [8/$total_tests] Checking plugin marketplace subcommand completions..."
set -l mp_completions (complete -C "claude plugin marketplace " 2>/dev/null)
for subcmd in add remove list update
    if not string match -q "*$subcmd*" -- $mp_completions
        echo "FAIL: Missing plugin marketplace subcommand: $subcmd"
        exit 1
    end
end

# Test 9: Flag value completions (enumerated flags)
echo "  [9/$total_tests] Checking flag value completions..."
set -l model_completions (complete -C "claude --model " 2>/dev/null)
for val in sonnet opus haiku
    if not string match -q "*$val*" -- $model_completions
        echo "FAIL: Missing model value: $val"
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
