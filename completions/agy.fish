# Fish shell completions for Google Antigravity CLI (agy)
# https://github.com/naokiiida/antigravity-cli-fish-completions

# Clear existing completions and disable file completions by default
complete -c agy -e
complete -c agy -f

# Propagate completions to common alias
complete -c antigravity -w agy

# =============================================================================
# Helper Functions
# =============================================================================

function __fish_agy_conversations
    set -l conv_dir "$HOME/.gemini/antigravity-cli/conversations"
    if not test -d "$conv_dir"
        return
    end

    for file in (ls -t "$conv_dir"/*.db 2>/dev/null)
        set -l uuid (path basename -E "$file")
        if not string match -qr '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' $uuid
            continue
        end

        set -l diff (path mtime -R "$file")
        if test -z "$diff"
            echo "$uuid"
            continue
        end

        set -l desc ""
        if test $diff -lt 60
            set desc "just now"
        else if test $diff -lt 3600
            set desc (math "floor($diff / 60)")"m ago"
        else if test $diff -lt 86400
            set desc (math "floor($diff / 3600)")"h ago"
        else
            set desc (math "floor($diff / 86400)")"d ago"
        end
        echo -e "$uuid\t($desc)"
    end
end

function __fish_agy_agents
    set -l found 0

    # Source 1: Custom agents from workspace or user directories
    for agents_dir in .agents/agents "$HOME/.gemini/config/agents"
        if test -d "$agents_dir"
            for f in "$agents_dir"/*.md
                test -f "$f"; or continue
                set -l name (path basename -E "$f")
                set found 1

                # Extract description from YAML frontmatter (between --- delimiters)
                set -l desc ""
                set -l in_frontmatter 0
                set -l line_num 0
                while read -l line
                    set line_num (math $line_num + 1)
                    if test $line_num -eq 1 -a "$line" = ---
                        set in_frontmatter 1
                        continue
                    end
                    if test $in_frontmatter -eq 1
                        if test "$line" = ---
                            break
                        end
                        set -l match (string match -rg '^description:\s*(.+)' -- "$line")
                        if test -n "$match"
                            set desc $match
                        end
                    end
                end <"$f"

                if test -n "$desc"
                    printf '%s\t%s\n' "$name" "$desc"
                else
                    echo "$name"
                end
            end
        end
    end

    # Source 2: agy agents CLI output
    set -l cli_agents
    if command -q agy
        set cli_agents (command agy agents 2>/dev/null | string match -rv '^Available agents:|^\\s*$' | string trim)
    end
    for a in $cli_agents
        echo $a
    end
end

function __fish_agy_mcp_servers
    set -l servers

    # Source 1: Config directories in ~/.gemini/antigravity-cli/mcp/
    set -l mcp_dir "$HOME/.gemini/antigravity-cli/mcp"
    if test -d "$mcp_dir"
        for d in "$mcp_dir"/*/
            test -d "$d"; or continue
            set -a servers (path basename "$d")
        end
    end

    # Source 2: agy mcp list output
    if command -q agy
        set -l list_output (command agy mcp list 2>/dev/null)
        if test -n "$list_output"
            set -a servers (printf '%s\n' $list_output | string match -rg '^(\S+)\s+(?:stdio|http)\s+(?:enabled|disabled)')
        end
    end

    printf '%s\n' $servers | sort -u
end

function __fish_agy_mcp_enabled_servers
    command -q agy; or return
    set -l list_output (command agy mcp list 2>/dev/null)
    test -n "$list_output"; or return
    printf '%s\n' $list_output | string match -rg '^(\S+)\s+(?:stdio|http)\s+enabled'
end

function __fish_agy_mcp_disabled_servers
    command -q agy; or return
    set -l list_output (command agy mcp list 2>/dev/null)
    test -n "$list_output"; or return
    printf '%s\n' $list_output | string match -rg '^(\S+)\s+(?:stdio|http)\s+disabled'
end

function __fish_agy_installed_plugins
    command -q agy; or return
    set -l json (command agy plugin list --json 2>/dev/null | string join ' ')
    test -n "$json"; or return
    set -l json (string replace -ra '\}\s*,\s*\{' '}\n{' -- $json)
    for chunk in (string split \n -- $json)
        set -l name (string match -r '"name"\s*:\s*"([^"]*)"' -- $chunk)[2]
        if test -n "$name"
            echo $name
        end
    end
end

function __fish_agy_enabled_plugins
    command -q agy; or return
    set -l json (command agy plugin list --json 2>/dev/null | string join ' ')
    test -n "$json"; or return
    set -l json (string replace -ra '\}\s*,\s*\{' '}\n{' -- $json)
    for chunk in (string split \n -- $json)
        set -l name (string match -r '"name"\s*:\s*"([^"]*)"' -- $chunk)[2]
        set -l enabled (string match -r '"enabled"\s*:\s*(true|false)' -- $chunk)[2]
        if test -n "$name" -a "$enabled" = true
            echo $name
        end
    end
end

function __fish_agy_disabled_plugins
    command -q agy; or return
    set -l json (command agy plugin list --json 2>/dev/null | string join ' ')
    test -n "$json"; or return
    set -l json (string replace -ra '\}\s*,\s*\{' '}\n{' -- $json)
    for chunk in (string split \n -- $json)
        set -l name (string match -r '"name"\s*:\s*"([^"]*)"' -- $chunk)[2]
        set -l enabled (string match -r '"enabled"\s*:\s*(true|false)' -- $chunk)[2]
        if test -n "$name" -a "$enabled" = false
            echo $name
        end
    end
end

function __fish_agy_cache_dir
    # Priority 1: User & environment variable overrides
    if set -q ANTIGRAVITY_CACHE_DIR; and test -d "$ANTIGRAVITY_CACHE_DIR"
        echo "$ANTIGRAVITY_CACHE_DIR"
        return
    end
    if set -q ANTIGRAVITY_APP_DATA_DIR; and test -d "$ANTIGRAVITY_APP_DATA_DIR/cache"
        echo "$ANTIGRAVITY_APP_DATA_DIR/cache"
        return
    end
    if set -q GEMINI_CLI_HOME; and test -d "$GEMINI_CLI_HOME/cache"
        echo "$GEMINI_CLI_HOME/cache"
        return
    end

    # Priority 2: Standard CLI location
    if test -d "$HOME/.gemini/antigravity-cli/cache"
        echo "$HOME/.gemini/antigravity-cli/cache"
        return
    end

    # Priority 3: XDG and OS standard cache locations
    if set -q XDG_CACHE_HOME; and test -d "$XDG_CACHE_HOME/antigravity-cli"
        echo "$XDG_CACHE_HOME/antigravity-cli"
        return
    else if test -d "$HOME/.cache/antigravity-cli"
        echo "$HOME/.cache/antigravity-cli"
        return
    end
    if test -d "$HOME/Library/Caches/antigravity-cli"
        echo "$HOME/Library/Caches/antigravity-cli"
        return
    end
end

function __fish_agy_marketplace_dirs
    set -l cache_dir (__fish_agy_cache_dir)
    if test -n "$cache_dir" -a -d "$cache_dir/marketplaces"
        echo "$cache_dir/marketplaces"
    end
    # Also probe alternative / future standalone marketplace paths
    for dir in "$HOME/.gemini/antigravity-cli/marketplaces" "$HOME/.gemini/config/marketplaces"
        test -d "$dir"; and echo "$dir"
    end
end

function __fish_agy_marketplaces
    for mp_dir in (__fish_agy_marketplace_dirs)
        for d in "$mp_dir"/*/
            test -d "$d"; or continue
            path basename "$d"
        end
    end
end

function __fish_agy_marketplace_plugins
    for mp_dir in (__fish_agy_marketplace_dirs)
        for f in "$mp_dir"/*/marketplace.json
            test -f "$f"; or continue
            set -l in_plugin 0
            set -l name ""
            set -l desc ""
            while read -l line
                if string match -qr '"name":\s*"([^"]+)"' -- $line
                    set -l m (string match -r '"name":\s*"([^"]+)"' -- $line)
                    if test $in_plugin -eq 0
                        set in_plugin 1
                        continue
                    end
                    set name $m[2]
                else if test $in_plugin -eq 1 -a -n "$name"; and string match -qr '"description":\s*"([^"]+)"' -- $line
                    set -l m (string match -r '"description":\s*"([^"]+)"' -- $line)
                    set desc $m[2]
                    printf '%s\t%s\n' "$name" "$desc"
                    set name ""
                    set desc ""
                end
            end <"$f"
        end
    end
end

function __fish_agy_mcp_add_command
    set -l tokens (commandline -cop)
    set -l add_idx 0
    for i in (seq (count $tokens))
        if test "$tokens[$i]" = add
            set add_idx $i
            break
        end
    end
    test $add_idx -gt 0; or return 1

    set -l pos_args 0
    set -l in_skip 0
    for tok in $tokens[(math $add_idx + 1)..-1]
        if test $in_skip -eq 1
            set in_skip 0
            continue
        end
        if string match -q -- '-*' $tok
            if contains -- $tok -H --header -e --env -t --type
                set in_skip 1
            end
            continue
        end
        set pos_args (math $pos_args + 1)
    end
    # Argument 1 is <name>, Argument 2 is <commandOrUrl>
    if test $pos_args -eq 1
        __fish_complete_command
    end
end

function __fish_agy_plugin_install_target
    set -l tokens (commandline -cop)
    set -l idx 0
    for i in (seq (count $tokens))
        if test "$tokens[$i]" = install
            set idx $i
            break
        end
    end
    test $idx -gt 0; or return 1

    set -l pos_args 0
    for tok in $tokens[(math $idx + 1)..-1]
        string match -q -- '-*' $tok; and continue
        set pos_args (math $pos_args + 1)
    end
    test $pos_args -eq 0; or return 1
    __fish_complete_directories
    __fish_agy_marketplace_plugins
end

function __fish_agy_plugin_link_token_count
    set -l tokens (commandline -cop)
    set -l link_idx 0
    for i in (seq (count $tokens))
        if test "$tokens[$i]" = link
            set link_idx $i
            break
        end
    end
    test $link_idx -gt 0; or return 1

    set -l pos_args 0
    for tok in $tokens[(math $link_idx + 1)..-1]
        string match -q -- '-*' $tok; and continue
        set pos_args (math $pos_args + 1)
    end
    echo $pos_args
end

function __fish_agy_plugin_link_arg1
    test (__fish_agy_plugin_link_token_count) -eq 0; or return 1
    __fish_agy_marketplaces
end

function __fish_agy_plugin_link_arg2
    test (__fish_agy_plugin_link_token_count) -eq 1; or return 1
    __fish_complete_directories
end

# =============================================================================
# Subcommands (when no subcommand present)
# Canonical subcommands only (aliases like `agents` and `plugins` are hidden)
# =============================================================================

complete -c agy -n __fish_use_subcommand -xa acp -d "Start the Agent Client Protocol (ACP) stdio server"
complete -c agy -n __fish_use_subcommand -xa agent -d "List available agents"
complete -c agy -n __fish_use_subcommand -xa changelog -d "Show changelog and release notes"
complete -c agy -n __fish_use_subcommand -xa help -d "Show help for subcommands"
complete -c agy -n __fish_use_subcommand -xa install -d "Configure environment paths and shell settings"
complete -c agy -n __fish_use_subcommand -xa mcp -d "Manage MCP servers (add, remove, list, enable, disable)"
complete -c agy -n __fish_use_subcommand -xa mic-serve -d "Serve this machine's microphone to a CLI on another host"
complete -c agy -n __fish_use_subcommand -xa models -d "List available models"
complete -c agy -n __fish_use_subcommand -xa plugin -d "Manage plugins (install, uninstall, list, enable, disable)"
complete -c agy -n __fish_use_subcommand -xa remote-control -d "Manage the remote-control background daemon (start, status, stop)"
complete -c agy -n __fish_use_subcommand -xa update -d "Update CLI"

# =============================================================================
# Top-level flags
# =============================================================================

# Simple toggles & common flags
complete -c agy -n __fish_use_subcommand -s c -l continue -d "Continue the most recent conversation"
complete -c agy -n __fish_use_subcommand -l dangerously-skip-permissions -d "Auto-approve all tool permission requests without prompting"
complete -c agy -n __fish_use_subcommand -l disable-slash-commands -d "Disable slash command and skill expansion in print mode"
complete -c agy -n __fish_use_subcommand -l new-project -d "Create a new project for this session"
complete -c agy -n __fish_use_subcommand -s p -l print -d "Run a single prompt non-interactively and print the response"
complete -c agy -n __fish_use_subcommand -l prompt -d "Alias for --print"
complete -c agy -n __fish_use_subcommand -l remote-agent -d "Run this session's conversations using remote agents"
complete -c agy -n __fish_use_subcommand -l remote-control -d "Create a remote connection for the CLI session on start up"
complete -c agy -n __fish_use_subcommand -l sandbox -d "Run in a sandbox with terminal restrictions enabled"
complete -c agy -n __fish_use_subcommand -l version -d "Output the version number"
complete -c agy -n __fish_use_subcommand -s h -l help -d "Show help"

# Enumerated value flags
complete -c agy -n __fish_use_subcommand -l effort -d "Reasoning effort for the current CLI session" -rxa "low medium high xhigh max"
complete -c agy -n __fish_use_subcommand -l mode -d "Set the agent execution mode for this session" -rxa "accept-edits auto plan"
complete -c agy -n __fish_use_subcommand -l input-format -d "Input format for print mode" -rxa "text stream-json"
complete -c agy -n __fish_use_subcommand -l output-format -d "Output format for print mode" -rxa "text json stream-json"

# Model completion (known available models + descriptions)
function __fish_agy_known_models
    printf '%s\t%s\n' \
        gemini-4-argon-high "Gemini 4 Argon (High)" \
        gemini-4-argon-medium "Gemini 4 Argon (Medium)" \
        gemini-4-argon-low "Gemini 4 Argon (Low)" \
        "gemini-3.8-flash-high" "Gemini 3.8 Flash (High)" \
        "gemini-3.8-flash-medium" "Gemini 3.8 Flash (Medium)" \
        "gemini-3.8-flash-low" "Gemini 3.8 Flash (Low)" \
        claude-opus-5-5-high "Claude Opus 5.5 (High)" \
        claude-opus-5-5-medium "Claude Opus 5.5 (Medium)" \
        claude-opus-5-5-low "Claude Opus 5.5 (Low)" \
        claude-sonnet-5-5-high "Claude Sonnet 5.5 (High)" \
        claude-sonnet-5-5-medium "Claude Sonnet 5.5 (Medium)" \
        claude-sonnet-5-5-low "Claude Sonnet 5.5 (Low)" \
        gpt-oss-120b-medium "GPT-OSS 120B (Medium)"
end
complete -c agy -n __fish_use_subcommand -l model -d "Model for the current CLI session" -rxa "(__fish_agy_known_models)"

# Dynamic value flags
complete -c agy -n __fish_use_subcommand -l conversation -d "Resume a previous conversation by ID" -rxa "(__fish_agy_conversations)"
complete -c agy -n __fish_use_subcommand -l agent -d "Agent for the current CLI session" -rxa "(__fish_agy_agents)"
complete -c agy -n __fish_use_subcommand -l add-dir -d "Add a directory to the workspace (repeatable)" -rxa "(__fish_complete_directories)"

# File and string value flags
complete -c agy -n __fish_use_subcommand -s i -l prompt-interactive -d "Run an initial prompt interactively and continue the session" -rx
complete -c agy -n __fish_use_subcommand -l print-timeout -d "Optional time limit for print mode (e.g. 30s, 5m)" -rxa "30s 1m 5m 10m 1h"
complete -c agy -n __fish_use_subcommand -l project -d "Project ID or project name for the current CLI session" -rx
complete -c agy -n __fish_use_subcommand -l json-schema -d "Optional JSON schema string or path to schema file" -rF
complete -c agy -n __fish_use_subcommand -l log-file -d "Override CLI log file path" -rF
complete -c agy -n __fish_use_subcommand -l settings -d "Settings for this session only, never saved: a JSON object of settings.json keys, inline or as a file path" -rF

# =============================================================================
# acp subcommand
# =============================================================================

complete -c agy -n "__fish_seen_subcommand_from acp" -l add-dir -d "Add a directory to the workspace (repeatable)" -rxa "(__fish_complete_directories)"
complete -c agy -n "__fish_seen_subcommand_from acp" -l agent -d "Agent for the ACP session" -rxa "(__fish_agy_agents)"
complete -c agy -n "__fish_seen_subcommand_from acp" -l app-data-dir -d "Path where application data is stored" -rxa "(__fish_complete_directories)"
complete -c agy -n "__fish_seen_subcommand_from acp" -l app_data_dir -d "Path where application data is stored" -rxa "(__fish_complete_directories)"
complete -c agy -n "__fish_seen_subcommand_from acp" -l cli_dir_name -d "Subdirectory under app_data_dir for CLI settings and logs" -rx
complete -c agy -n "__fish_seen_subcommand_from acp" -l cli_log_file -d "Override ACP log file path" -rF
complete -c agy -n "__fish_seen_subcommand_from acp" -l cloud_code_endpoint -d "CCPA API URL" -rx
complete -c agy -n "__fish_seen_subcommand_from acp" -l dangerously-skip-permissions -d "Auto-approve all tool permission requests"
complete -c agy -n "__fish_seen_subcommand_from acp" -l disable-telemetry -d "If true, disable telemetry"
complete -c agy -n "__fish_seen_subcommand_from acp" -l disable_telemetry -d "If true, disable telemetry"
complete -c agy -n "__fish_seen_subcommand_from acp" -l gemini-dir -d "Path where Gemini files are stored" -rxa "(__fish_complete_directories)"
complete -c agy -n "__fish_seen_subcommand_from acp" -l gemini_dir -d "Path where Gemini files are stored" -rxa "(__fish_complete_directories)"
complete -c agy -n "__fish_seen_subcommand_from acp" -s h -l help -d "Show help"
complete -c agy -n "__fish_seen_subcommand_from acp" -l ide-mcp-port -d "Port for host IDE tools MCP server (requires 'nc' in \$PATH)" -rx
complete -c agy -n "__fish_seen_subcommand_from acp" -l ide_mcp_port -d "Port for host IDE tools MCP server (requires 'nc' in \$PATH)" -rx
complete -c agy -n "__fish_seen_subcommand_from acp" -l include-default-customizations -d "Include default customizations"
complete -c agy -n "__fish_seen_subcommand_from acp" -l is_google3_workspace -d "Whether running in Google environment"
complete -c agy -n "__fish_seen_subcommand_from acp" -l is_google_internal -d "Deprecated: use is_google3_workspace"
complete -c agy -n "__fish_seen_subcommand_from acp" -l log-file -d "Override ACP log file path" -rF
complete -c agy -n "__fish_seen_subcommand_from acp" -l login -d "Log in with Google interactively, then exit (ACP terminal auth)"
complete -c agy -n "__fish_seen_subcommand_from acp" -l override_user_agent_name -d "Override user agent name for HTTP requests" -rx
complete -c agy -n "__fish_seen_subcommand_from acp" -l process-per-session -d "Serve each session from an isolated worker process"
complete -c agy -n "__fish_seen_subcommand_from acp" -l sandbox -d "Run in a sandbox with terminal restrictions enabled"
complete -c agy -n "__fish_seen_subcommand_from acp" -l stdio -d "Use stdio JSON-RPC transport (default)"
complete -c agy -n "__fish_seen_subcommand_from acp" -l use_stubby_auth -d "Use LOAS auth"
complete -c agy -n "__fish_seen_subcommand_from acp" -l worker -d "Serve a single session for an ACP front process (internal)"

# =============================================================================
# install subcommand
# =============================================================================

complete -c agy -n "__fish_seen_subcommand_from install" -l dir -d "Custom directory target to configure PATH for" -rxa "(__fish_complete_directories)"
complete -c agy -n "__fish_seen_subcommand_from install" -l skip-aliases -d "Bypasses shell profile alias purging"
complete -c agy -n "__fish_seen_subcommand_from install" -l skip-path -d "Bypasses shell profile PATH appending"
complete -c agy -n "__fish_seen_subcommand_from install" -s h -l help -d "Show help"

# =============================================================================
# mcp subcommand
# =============================================================================

complete -c agy -n "__fish_seen_subcommand_from mcp; and not __fish_seen_subcommand_from add remove list enable disable" -xa add -d "Add or update an MCP server configuration"
complete -c agy -n "__fish_seen_subcommand_from mcp; and not __fish_seen_subcommand_from add remove list enable disable" -xa remove -d "Remove an MCP server configuration"
complete -c agy -n "__fish_seen_subcommand_from mcp; and not __fish_seen_subcommand_from add remove list enable disable" -xa list -d "List all configured MCP servers"
complete -c agy -n "__fish_seen_subcommand_from mcp; and not __fish_seen_subcommand_from add remove list enable disable" -xa enable -d "Enable an MCP server"
complete -c agy -n "__fish_seen_subcommand_from mcp; and not __fish_seen_subcommand_from add remove list enable disable" -xa disable -d "Disable an MCP server"
complete -c agy -n "__fish_seen_subcommand_from mcp" -s h -l help -d "Show help"

# mcp add flags
complete -c agy -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from add" -s H -l header -d "HTTP header Key: Value (repeatable)" -rx
complete -c agy -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from add" -s e -l env -d "Environment variable KEY=value (repeatable)" -rx
complete -c agy -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from add" -s t -l type -d "Server type: 'stdio' or 'http'" -rxa "stdio http"
complete -c agy -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from add" -s h -l help -d "Show help"
complete -c agy -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from add" -a "(__fish_agy_mcp_add_command)" -d Command

# mcp remove
complete -c agy -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from remove" -xa "(__fish_agy_mcp_servers)"
complete -c agy -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from remove" -s h -l help -d "Show help"

# mcp list
complete -c agy -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from list" -s h -l help -d "Show help"

# mcp enable
complete -c agy -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from enable" -xa "(__fish_agy_mcp_disabled_servers)"
complete -c agy -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from enable" -s h -l help -d "Show help"

# mcp disable
complete -c agy -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from disable" -xa "(__fish_agy_mcp_enabled_servers)"
complete -c agy -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from disable" -s h -l help -d "Show help"

# =============================================================================
# mic-serve subcommand
# =============================================================================

complete -c agy -n "__fish_seen_subcommand_from mic-serve" -l addr -d "Address to listen on; keep it on loopback (default 127.0.0.1:4713)" -rx
complete -c agy -n "__fish_seen_subcommand_from mic-serve" -s h -l help -d "Show help"

# =============================================================================
# plugin / plugins subcommand
# =============================================================================

complete -c agy -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from list import install uninstall enable disable validate link help" -xa list -d "List installed plugins"
complete -c agy -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from list import install uninstall enable disable validate link help" -xa import -d "Import plugins from gemini or claude"
complete -c agy -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from list import install uninstall enable disable validate link help" -xa install -d "Install a plugin (supports plugin[@marketplace])"
complete -c agy -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from list import install uninstall enable disable validate link help" -xa uninstall -d "Uninstall a plugin"
complete -c agy -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from list import install uninstall enable disable validate link help" -xa enable -d "Enable a plugin"
complete -c agy -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from list import install uninstall enable disable validate link help" -xa disable -d "Disable a plugin"
complete -c agy -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from list import install uninstall enable disable validate link help" -xa validate -d "Check a plugin's manifest and files"
complete -c agy -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from list import install uninstall enable disable validate link help" -xa link -d "Generate link to a marketplace"
complete -c agy -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from list import install uninstall enable disable validate link help" -xa help -d "Show help"
complete -c agy -n "__fish_seen_subcommand_from plugin plugins" -s h -l help -d "Show help"

# plugin list
complete -c agy -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from list" -l json -d "List installed plugins as JSON"

# plugin import
complete -c agy -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from import" -xa "gemini claude" -d "Import source"

# plugin install
complete -c agy -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from install" -a "(__fish_agy_plugin_install_target)"

# plugin uninstall
complete -c agy -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from uninstall" -xa "(__fish_agy_installed_plugins)"

# plugin enable
complete -c agy -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from enable" -xa "(__fish_agy_disabled_plugins)"

# plugin disable
complete -c agy -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from disable" -xa "(__fish_agy_enabled_plugins)"

# plugin validate
complete -c agy -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from validate" -l strict -d "Also fail on warnings"
complete -c agy -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from validate" -l json -d "Print the report as JSON"
complete -c agy -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from validate" -rF

# plugin link
complete -c agy -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from link" -a "(__fish_agy_plugin_link_arg1)" -d Marketplace
complete -c agy -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from link" -a "(__fish_agy_plugin_link_arg2)" -d "Target directory"

# =============================================================================
# remote-control subcommand
# =============================================================================

complete -c agy -n "__fish_seen_subcommand_from remote-control; and not __fish_seen_subcommand_from start status stop" -xa start -d "Register and start the remote-control daemon"
complete -c agy -n "__fish_seen_subcommand_from remote-control; and not __fish_seen_subcommand_from start status stop" -xa status -d "Show the daemon's status"
complete -c agy -n "__fish_seen_subcommand_from remote-control; and not __fish_seen_subcommand_from start status stop" -xa stop -d "Stop the daemon and unregister it"
complete -c agy -n "__fish_seen_subcommand_from remote-control" -s h -l help -d "Show help"

# remote-control start flags
complete -c agy -n "__fish_seen_subcommand_from remote-control; and __fish_seen_subcommand_from start" -l name -d "Set this machine's instance name shown in Remote Control" -rx
complete -c agy -n "__fish_seen_subcommand_from remote-control; and __fish_seen_subcommand_from start" -l session -d "Register the daemon login-scoped instead of starting at boot"
complete -c agy -n "__fish_seen_subcommand_from remote-control; and __fish_seen_subcommand_from start" -s h -l help -d "Show help"

# remote-control status & stop flags
complete -c agy -n "__fish_seen_subcommand_from remote-control; and __fish_seen_subcommand_from status stop" -s h -l help -d "Show help"

# =============================================================================
# help subcommand
# =============================================================================

complete -c agy -n "__fish_seen_subcommand_from help" -xa "acp agent changelog install mcp mic-serve models plugin remote-control update" -d Subcommand

# =============================================================================
# Simple subcommands (help only)
# =============================================================================

complete -c agy -n "__fish_seen_subcommand_from agent agents changelog models update" -s h -l help -d "Show help"
