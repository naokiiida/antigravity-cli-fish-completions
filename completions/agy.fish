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
                    if test $line_num -eq 1 -a "$line" = "---"
                        set in_frontmatter 1
                        continue
                    end
                    if test $in_frontmatter -eq 1
                        if test "$line" = "---"
                            break
                        end
                        set -l match (string match -rg '^description:\s*(.+)' -- "$line")
                        if test -n "$match"
                            set desc $match
                        end
                    end
                end < "$f"

                if test -n "$desc"
                    printf '%s\t%s\n' "$name" "$desc"
                else
                    echo "$name"
                end
            end
        end
    end

    # Source 2: agy agents CLI output
    set -l cli_agents (command agy agents 2>/dev/null | string match -rv '^Available agents:|^\\s*$' | string trim)
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
    set -l list_output (command agy mcp list 2>/dev/null)
    if test -n "$list_output"
        set -a servers (printf '%s\n' $list_output | string match -rg '^(\S+)\s+(?:stdio|http)\s+(?:enabled|disabled)')
    end

    printf '%s\n' $servers | sort -u
end

function __fish_agy_mcp_enabled_servers
    set -l list_output (command agy mcp list 2>/dev/null)
    test -n "$list_output"; or return
    printf '%s\n' $list_output | string match -rg '^(\S+)\s+(?:stdio|http)\s+enabled'
end

function __fish_agy_mcp_disabled_servers
    set -l list_output (command agy mcp list 2>/dev/null)
    test -n "$list_output"; or return
    printf '%s\n' $list_output | string match -rg '^(\S+)\s+(?:stdio|http)\s+disabled'
end

function __fish_agy_installed_plugins
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

# =============================================================================
# Subcommands (when no subcommand present)
# Canonical subcommands only (aliases like `agents` and `plugins` are hidden)
# =============================================================================

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
complete -c agy -s c -l continue -d "Continue the most recent conversation"
complete -c agy -l dangerously-skip-permissions -d "Auto-approve all tool permission requests without prompting"
complete -c agy -l disable-slash-commands -d "Disable slash command and skill expansion in print mode"
complete -c agy -l new-project -d "Create a new project for this session"
complete -c agy -s p -l print -d "Run a single prompt non-interactively and print the response"
complete -c agy -l prompt -d "Alias for --print"
complete -c agy -l remote-control -d "Create a remote connection for the CLI session on start up"
complete -c agy -l sandbox -d "Run in a sandbox with terminal restrictions enabled"
complete -c agy -l version -d "Output the version number"
complete -c agy -s h -l help -d "Show help"

# Enumerated value flags
complete -c agy -l effort -d "Reasoning effort for the current CLI session" -rxa "low medium high xhigh max"
complete -c agy -l mode -d "Set the agent execution mode for this session" -rxa "accept-edits auto plan"
complete -c agy -l input-format -d "Input format for print mode" -rxa "text stream-json"
complete -c agy -l output-format -d "Output format for print mode" -rxa "text json stream-json"

# Model completion (known available models + descriptions)
function __fish_agy_known_models
    printf '%s\t%s\n' \
        "gemini-3.8-flash-high" "Gemini 3.8 Flash (High)" \
        "gemini-3.8-flash-medium" "Gemini 3.8 Flash (Medium)" \
        "gemini-3.8-flash-low" "Gemini 3.8 Flash (Low)" \
        "claude-opus-5-5-high" "Claude Opus 5.5 (High)" \
        "claude-opus-5-5-medium" "Claude Opus 5.5 (Medium)" \
        "claude-opus-5-5-low" "Claude Opus 5.5 (Low)" \
        "claude-sonnet-5-5-high" "Claude Sonnet 5.5 (High)" \
        "claude-sonnet-5-5-medium" "Claude Sonnet 5.5 (Medium)" \
        "claude-sonnet-5-5-low" "Claude Sonnet 5.5 (Low)" \
        "gpt-oss-120b-medium" "GPT-OSS 120B (Medium)"
end
complete -c agy -l model -d "Model for the current CLI session" -rxa "(__fish_agy_known_models)"

# Dynamic value flags
complete -c agy -l conversation -d "Resume a previous conversation by ID" -rxa "(__fish_agy_conversations)"
complete -c agy -l agent -d "Agent for the current CLI session" -rxa "(__fish_agy_agents)"
complete -c agy -l add-dir -d "Add a directory to the workspace (repeatable)" -rxa "(__fish_complete_directories)"

# File and string value flags
complete -c agy -s i -l prompt-interactive -d "Run an initial prompt interactively and continue the session" -rx
complete -c agy -l print-timeout -d "Optional time limit for print mode (e.g. 30s, 5m)" -rx
complete -c agy -l project -d "Project ID or project name for the current CLI session" -rx
complete -c agy -l json-schema -d "Optional JSON schema string or path to schema file" -rF
complete -c agy -l log-file -d "Override CLI log file path" -rF

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
complete -c agy -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from list import install uninstall enable disable validate link help" -xa validate -d "Validate a plugin"
complete -c agy -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from list import install uninstall enable disable validate link help" -xa link -d "Generate link to a marketplace"
complete -c agy -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from list import install uninstall enable disable validate link help" -xa help -d "Show help"
complete -c agy -n "__fish_seen_subcommand_from plugin plugins" -s h -l help -d "Show help"

# plugin list
complete -c agy -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from list" -l json -d "List installed plugins as JSON"

# plugin import
complete -c agy -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from import" -xa "gemini claude" -d "Import source"

# plugin uninstall
complete -c agy -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from uninstall" -xa "(__fish_agy_installed_plugins)"

# plugin enable
complete -c agy -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from enable" -xa "(__fish_agy_disabled_plugins)"

# plugin disable
complete -c agy -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from disable" -xa "(__fish_agy_enabled_plugins)"

# plugin validate
complete -c agy -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from validate" -rF

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

complete -c agy -n "__fish_seen_subcommand_from help" -xa "agent changelog install mcp mic-serve models plugin remote-control update" -d "Subcommand"

# =============================================================================
# Simple subcommands (help only)
# =============================================================================

complete -c agy -n "__fish_seen_subcommand_from agent agents changelog models update" -s h -l help -d "Show help"
