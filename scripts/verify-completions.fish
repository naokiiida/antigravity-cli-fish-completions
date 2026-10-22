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

# Isolate completion path so tests do not autoload stale installed completions
set -g fish_complete_path "$repo_root/completions"

echo "Verifying completion script: $completion_file"

set -l total_tests 13

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

set -l completion_tokens (string replace -r '\t.*' '' -- $completions)
set -l required_subcommands agent changelog help install mcp mic-serve models plugin remote-control update
for cmd in $required_subcommands
    if not contains -- $cmd $completion_tokens
        echo "FAIL: Missing subcommand: $cmd"
        exit 1
    end
end

# Regression guard: aliases should be hidden from top-level completions
set -l hidden_aliases agents plugins
for alias_cmd in $hidden_aliases
    if contains -- $alias_cmd $completion_tokens
        echo "FAIL: Alias should be hidden from top-level completions: $alias_cmd"
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
for flag in add-dir agent continue conversation dangerously-skip-permissions disable-slash-commands \
    effort input-format json-schema log-file mode model new-project output-format print print-timeout \
    project prompt prompt-interactive remote-control sandbox
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

set -l validate_completions (complete -C "agy plugin validate -" 2>/dev/null)
for flag in strict json
    if not string match -q "*$flag*" -- $validate_completions
        echo "FAIL: Missing plugin validate flag: --$flag"
        exit 1
    end
end

# Test 6: Helper function existence
echo "  [6/$total_tests] Checking helper functions..."
for fn in __fish_agy_conversations __fish_agy_agents __fish_agy_mcp_servers \
    __fish_agy_mcp_enabled_servers __fish_agy_mcp_disabled_servers \
    __fish_agy_installed_plugins __fish_agy_enabled_plugins __fish_agy_disabled_plugins \
    __fish_agy_cache_dir __fish_agy_marketplace_dirs __fish_agy_marketplaces \
    __fish_agy_marketplace_plugins __fish_agy_mcp_add_command \
    __fish_agy_plugin_install_target __fish_agy_plugin_link_token_count \
    __fish_agy_plugin_link_arg1 __fish_agy_plugin_link_arg2
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

# Test 8: Check subcommand flag completions
echo "  [8/$total_tests] Checking subcommand flag completions..."
set -l install_completions (complete -C "agy install -" 2>/dev/null)
for flag in dir skip-aliases skip-path
    if not string match -q "*$flag*" -- $install_completions
        echo "FAIL: Missing install flag: --$flag"
        exit 1
    end
end

set -l mcp_add_flags (complete -C "agy mcp add -" 2>/dev/null)
for flag in env header type
    if not string match -q "*$flag*" -- $mcp_add_flags
        echo "FAIL: Missing mcp add flag: --$flag"
        exit 1
    end
end

set -l mic_serve_flags (complete -C "agy mic-serve -" 2>/dev/null)
if not string match -q "*addr*" -- $mic_serve_flags
    echo "FAIL: Missing mic-serve flag: --addr"
    exit 1
end

set -l rc_start_flags (complete -C "agy remote-control start -" 2>/dev/null)
for flag in name session
    if not string match -q "*$flag*" -- $rc_start_flags
        echo "FAIL: Missing remote-control start flag: --$flag"
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

set -l timeout_completions (complete -C "agy --print-timeout " 2>/dev/null)
for val in 30s 1m 5m 10m 1h
    if not string match -q "*$val*" -- $timeout_completions
        echo "FAIL: Missing print-timeout preset value: $val"
        exit 1
    end
end

set -l input_fmt_completions (complete -C "agy --input-format " 2>/dev/null)
for val in text stream-json
    if not string match -q "*$val*" -- $input_fmt_completions
        echo "FAIL: Missing input-format value: $val"
        exit 1
    end
end

set -l output_fmt_completions (complete -C "agy --output-format " 2>/dev/null)
for val in text json stream-json
    if not string match -q "*$val*" -- $output_fmt_completions
        echo "FAIL: Missing output-format value: $val"
        exit 1
    end
end

set -l mcp_type_completions (complete -C "agy mcp add --type " 2>/dev/null)
for val in stdio http
    if not string match -q "*$val*" -- $mcp_type_completions
        echo "FAIL: Missing mcp add --type value: $val"
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

# Test 11: Top-level flags do not leak into subcommands (regression guard)
echo "  [11/$total_tests] Checking subcommand flag isolation..."
set -l rc_start_flags (complete -C "agy remote-control start --" 2>/dev/null)
for leaked in continue conversation effort mode model print sandbox
    if string match -q "*--$leaked*" -- $rc_start_flags
        echo "FAIL: Leaked top-level flag into subcommand: --$leaked"
        exit 1
    end
end

# Test 12: Check positional completions (mcp add, plugin install, plugin link)
echo "  [12/$total_tests] Checking positional completions..."
set -l mcp_add_cmd (complete -C "agy mcp add test-server " 2>/dev/null)
if test (count $mcp_add_cmd) -lt 5
    echo "FAIL: mcp add failed to provide command completions (got "(count $mcp_add_cmd)")"
    exit 1
end

set -l plugin_install_comp (complete -C "agy plugin install " 2>/dev/null)
if test (count $plugin_install_comp) -lt 1
    echo "FAIL: plugin install failed to provide completions"
    exit 1
end

set -l plugin_link_comp (complete -C "agy plugin link " 2>/dev/null)
if not string match -q "*antigravity-plugins-official*" -- $plugin_link_comp
    echo "FAIL: plugin link failed to complete marketplace name"
    exit 1
end

# Test 13: Model completion verification
echo "  [13/$total_tests] Checking model options in __fish_agy_known_models..."
set -l known_models (__fish_agy_known_models | string replace -r '\t.*' '')
for model in gemini-4-argon-high gemini-4-argon-medium gemini-4-argon-low \
    gemini-3.8-flash-high gemini-3.8-flash-medium gemini-3.8-flash-low \
    claude-opus-5-5-high claude-sonnet-5-5-high gpt-oss-120b-medium
    if not contains -- $model $known_models
        echo "FAIL: Missing known model option: $model"
        exit 1
    end
end

echo ""
echo "VERIFICATION PASSED"
echo "==================="
echo "All checks passed. "(count $completions)" top-level completions registered."
exit 0
