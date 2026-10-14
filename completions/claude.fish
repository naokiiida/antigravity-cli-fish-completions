# Fish shell completions for Claude Code CLI (claude)
# https://github.com/naokiiida/claude-code-fish-completions
#
# Based on work by:
#   - InfiniteRoomLabs/fish-claude-completions (MIT)
#   - scaryrawr/claude-code.fish (MIT)

# Disable file completions by default
complete -c claude -f

# Propagate completions to common alias
complete -c cc -w claude

# =============================================================================
# Helper Functions
# =============================================================================

function __fish_claude_mcp_servers
    set -l servers

    # Source 1: Parse ~/.claude/settings.local.json
    set -l settings_file "$HOME/.claude/settings.local.json"
    if test -f "$settings_file"
        set -a servers (string match -rg '"mcpServers"\s*:\s*\{[^}]*"([^"]+)"' < "$settings_file" 2>/dev/null)
    end

    # Source 2: Parse .mcp.json in current directory
    if test -f .mcp.json
        set -a servers (string match -rg '"mcpServers"\s*:\s*\{[^}]*"([^"]+)"' < .mcp.json 2>/dev/null)
    end

    # Source 3: Fallback to claude mcp list (slower)
    if test (count $servers) -eq 0
        set -a servers (command claude mcp list 2>/dev/null | string match -rg '^\s+(\S+)' | string trim)
    end

    printf '%s\n' $servers | sort -u
end

function __fish_claude_sessions
    set -l slug (string replace -a '/' '-' $PWD)
    set -l sessions_dir "$HOME/.claude/projects/$slug"

    if not test -d "$sessions_dir"
        return
    end

    for file in (ls -t "$sessions_dir"/*.jsonl 2>/dev/null)
        set -l uuid (path basename -E $file)
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

function __fish_claude_agents
    set -l found 0

    # Source 1: User agents from ~/.claude/agents/*.md
    set -l agents_dir "$HOME/.claude/agents"
    if test -d "$agents_dir"
        for f in "$agents_dir"/*.md
            test -f "$f"; or continue
            set -l name (path basename -E $f)
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

    # Source 2: Fallback to claude agents CLI
    if test $found -eq 0
        command claude agents 2>/dev/null | string match -rg '^\s+(\S+)' | string trim
    end
end

function __claude_installed_plugins
    set -l json (claude plugin list --json 2>/dev/null | string join ' ')
    test -n "$json"; or return
    set -l json (string replace -ra '\}\s*,\s*\{' '}\n{' -- $json)
    for chunk in (string split \n -- $json)
        set -l id (string match -r '"id"\s*:\s*"([^"]*)"' -- $chunk)[2]
        if test -n "$id"
            echo $id
        end
    end
end

function __claude_enabled_plugins
    set -l json (claude plugin list --json 2>/dev/null | string join ' ')
    test -n "$json"; or return
    set -l json (string replace -ra '\}\s*,\s*\{' '}\n{' -- $json)
    for chunk in (string split \n -- $json)
        set -l id (string match -r '"id"\s*:\s*"([^"]*)"' -- $chunk)[2]
        set -l enabled (string match -r '"enabled"\s*:\s*(true|false)' -- $chunk)[2]
        if test -n "$id" -a "$enabled" = true
            echo $id
        end
    end
end

function __claude_disabled_plugins
    set -l json (claude plugin list --json 2>/dev/null | string join ' ')
    test -n "$json"; or return
    set -l json (string replace -ra '\}\s*,\s*\{' '}\n{' -- $json)
    for chunk in (string split \n -- $json)
        set -l id (string match -r '"id"\s*:\s*"([^"]*)"' -- $chunk)[2]
        set -l enabled (string match -r '"enabled"\s*:\s*(true|false)' -- $chunk)[2]
        if test -n "$id" -a "$enabled" = false
            echo $id
        end
    end
end

function __claude_available_plugins
    set -l json (claude plugin list --json --available 2>/dev/null | string join ' ')
    test -n "$json"; or return
    set -l available (string match -r '"available"\s*:\s*\[(.*)' -- $json)[2]
    test -n "$available"; or return
    set -l available (string replace -ra '\}\s*,\s*\{' '}\n{' -- $available)
    for chunk in (string split \n -- $available)
        set -l id (string match -r '"pluginId"\s*:\s*"([^"]*)"' -- $chunk)[2]
        set -l desc (string match -r '"description"\s*:\s*"([^"]*)"' -- $chunk)[2]
        if test -n "$id"
            printf '%s\t%s\n' "$id" "$desc"
        end
    end
end

function __claude_marketplace_names
    set -l json (claude plugin marketplace list --json 2>/dev/null | string join ' ')
    test -n "$json"; or return
    set -l json (string replace -ra '\}\s*,\s*\{' '}\n{' -- $json)
    for chunk in (string split \n -- $json)
        set -l name (string match -r '"name"\s*:\s*"([^"]*)"' -- $chunk)[2]
        set -l source (string match -r '"source"\s*:\s*"([^"]*)"' -- $chunk)[2]
        if test -n "$name"
            printf '%s\t%s\n' "$name" "$source"
        end
    end
end

# =============================================================================
# Subcommands (when no subcommand present)
# =============================================================================

complete -c claude -n __fish_use_subcommand -xa mcp -d "Configure and manage MCP servers"
complete -c claude -n __fish_use_subcommand -xa auth -d "Manage authentication"
complete -c claude -n __fish_use_subcommand -xa auto-mode -d "Inspect auto mode classifier configuration"
complete -c claude -n __fish_use_subcommand -xa plugin -d "Manage Claude Code plugins"
complete -c claude -n __fish_use_subcommand -xa plugins -d "Manage Claude Code plugins"
complete -c claude -n __fish_use_subcommand -xa agents -d "List configured agents"
complete -c claude -n __fish_use_subcommand -xa doctor -d "Check auto-updater health"
complete -c claude -n __fish_use_subcommand -xa update -d "Check for updates and install"
complete -c claude -n __fish_use_subcommand -xa upgrade -d "Check for updates and install"
complete -c claude -n __fish_use_subcommand -xa install -d "Install Claude Code native build"
complete -c claude -n __fish_use_subcommand -xa setup-token -d "Set up a long-lived auth token"
complete -c claude -n __fish_use_subcommand -xa remote-control -d "Connect local environment to claude.ai/code"

# =============================================================================
# Top-level flags
# =============================================================================

# Simple toggles
complete -c claude -s c -l continue -d "Continue the most recent conversation"
complete -c claude -s d -l debug -d "Enable debug mode (optional filter: api,hooks)"
complete -c claude -l verbose -d "Override verbose mode setting from config"
complete -c claude -s p -l print -d "Print response and exit (useful for pipes)"
complete -c claude -s v -l version -d "Output the version number"
complete -c claude -s h -l help -d "Display help for command"
complete -c claude -l bare -d "Minimal mode: skip hooks, LSP, plugins, CLAUDE.md auto-discovery"
complete -c claude -l brief -d "Enable SendUserMessage tool for agent-to-user communication"
complete -c claude -l ide -d "Auto-connect to IDE on startup"
complete -c claude -l chrome -d "Enable Claude in Chrome integration"
complete -c claude -l no-chrome -d "Disable Claude in Chrome integration"
complete -c claude -l fork-session -d "Create new session ID when resuming"
complete -c claude -l mcp-debug -d "[DEPRECATED] Enable MCP debug mode"
complete -c claude -l dangerously-skip-permissions -d "Bypass all permission checks"
complete -c claude -l allow-dangerously-skip-permissions -d "Enable permission bypass as an option"
complete -c claude -l disable-slash-commands -d "Disable all skills"
complete -c claude -l no-session-persistence -d "Disable session saving (--print only)"
complete -c claude -l include-partial-messages -d "Include partial messages (--print + stream-json)"
complete -c claude -l replay-user-messages -d "Re-emit user messages on stdout"
complete -c claude -l strict-mcp-config -d "Only use MCP servers from --mcp-config"

# Enumerated value flags
complete -c claude -l output-format -d "Output format (--print only)" -rxa "text json stream-json"
complete -c claude -l input-format -d "Input format (--print only)" -rxa "text stream-json"
complete -c claude -l effort -d "Effort level for the session" -rxa "low medium high max"
complete -c claude -l permission-mode -d "Permission mode for the session" -rxa "acceptEdits bypassPermissions default dontAsk plan auto"
complete -c claude -l model -d "Model for the current session" -rxa "sonnet opus haiku best sonnet1m opus1m opusplan"
complete -c claude -l fallback-model -d "Fallback model when default is overloaded" -rxa "sonnet opus haiku best sonnet1m opus1m opusplan"

# Dynamic value flags
complete -c claude -s r -l resume -d "Resume a conversation by session ID" -rxa "(__fish_claude_sessions)"
complete -c claude -l mcp-config -d "Load MCP servers from JSON file" -rF
complete -c claude -l add-dir -d "Additional directories for tool access" -rxa "(__fish_complete_directories)"
complete -c claude -l debug-file -d "Write debug logs to file" -rF
complete -c claude -l plugin-dir -d "Load plugins from directory" -rxa "(__fish_complete_directories)"
complete -c claude -l settings -d "Path to settings JSON file" -rF

# Freeform value flags
complete -c claude -l system-prompt -d "System prompt for the session" -rx
complete -c claude -l append-system-prompt -d "Append to default system prompt" -rx
complete -c claude -l allowedTools -l allowed-tools -d "Tool names to allow" -rxa "Bash Edit Read Write Glob Grep LS MultiEdit NotebookEdit NotebookRead WebFetch WebSearch Task TodoRead TodoWrite"
complete -c claude -l disallowedTools -l disallowed-tools -d "Tool names to deny" -rxa "Bash Edit Read Write Glob Grep LS MultiEdit NotebookEdit NotebookRead WebFetch WebSearch Task TodoRead TodoWrite"
complete -c claude -l json-schema -d "JSON Schema for structured output" -rx
complete -c claude -l max-budget-usd -d "Maximum dollar amount for API calls" -rx
complete -c claude -l session-id -d "Use a specific session UUID" -rx
complete -c claude -s n -l name -d "Display name for this session" -rx
complete -c claude -l agents -d "JSON object defining custom agents" -rx
complete -c claude -l betas -d "Beta headers for API requests" -rx
complete -c claude -l tools -d "List of available tools" -rxa "Bash Edit Read Write Glob Grep LS MultiEdit NotebookEdit NotebookRead WebFetch WebSearch Task TodoRead TodoWrite"
complete -c claude -l setting-sources -d "Comma-separated setting sources" -rx
complete -c claude -l file -d "File resources (file_id:relative_path)" -rx
complete -c claude -l agent -d "Agent for the current session" -rxa "(__fish_claude_agents)"
complete -c claude -s w -l worktree -d "Create a new git worktree for this session"
complete -c claude -l from-pr -d "Resume session linked to a PR"
complete -c claude -l tmux -d "Create a tmux session for the worktree"

# =============================================================================
# mcp subcommand
# =============================================================================

complete -c claude -n "__fish_seen_subcommand_from mcp; and not __fish_seen_subcommand_from list add add-json add-from-claude-desktop remove get serve reset-project-choices" -xa list -d "List configured MCP servers"
complete -c claude -n "__fish_seen_subcommand_from mcp; and not __fish_seen_subcommand_from list add add-json add-from-claude-desktop remove get serve reset-project-choices" -xa add -d "Add an MCP server"
complete -c claude -n "__fish_seen_subcommand_from mcp; and not __fish_seen_subcommand_from list add add-json add-from-claude-desktop remove get serve reset-project-choices" -xa add-json -d "Add MCP server with JSON string"
complete -c claude -n "__fish_seen_subcommand_from mcp; and not __fish_seen_subcommand_from list add add-json add-from-claude-desktop remove get serve reset-project-choices" -xa add-from-claude-desktop -d "Import MCP servers from Claude Desktop"
complete -c claude -n "__fish_seen_subcommand_from mcp; and not __fish_seen_subcommand_from list add add-json add-from-claude-desktop remove get serve reset-project-choices" -xa remove -d "Remove an MCP server"
complete -c claude -n "__fish_seen_subcommand_from mcp; and not __fish_seen_subcommand_from list add add-json add-from-claude-desktop remove get serve reset-project-choices" -xa get -d "Get details about an MCP server"
complete -c claude -n "__fish_seen_subcommand_from mcp; and not __fish_seen_subcommand_from list add add-json add-from-claude-desktop remove get serve reset-project-choices" -xa serve -d "Start the Claude Code MCP server"
complete -c claude -n "__fish_seen_subcommand_from mcp; and not __fish_seen_subcommand_from list add add-json add-from-claude-desktop remove get serve reset-project-choices" -xa reset-project-choices -d "Reset approved/rejected project MCP servers"
complete -c claude -n "__fish_seen_subcommand_from mcp" -s h -l help -d "Display help for command"

# mcp add flags
complete -c claude -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from add" -s t -l transport -d "Transport type" -rxa "stdio sse http"
complete -c claude -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from add" -s s -l scope -d "Configuration scope" -rxa "local user project"
complete -c claude -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from add" -s e -l env -d "Set environment variables" -rx
complete -c claude -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from add" -s H -l header -d "Set HTTP headers" -rx
complete -c claude -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from add" -l callback-port -d "Fixed port for OAuth callback" -rx
complete -c claude -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from add" -l client-id -d "OAuth client ID" -rx
complete -c claude -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from add" -l client-secret -d "Prompt for OAuth client secret"

# mcp add-json flags
complete -c claude -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from add-json" -s s -l scope -d "Configuration scope" -rxa "local user project"
complete -c claude -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from add-json" -l client-secret -d "Prompt for OAuth client secret"

# mcp add-from-claude-desktop flags
complete -c claude -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from add-from-claude-desktop" -s s -l scope -d "Configuration scope" -rxa "local user project"

# mcp remove: dynamic server names + scope
complete -c claude -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from remove" -xa "(__fish_claude_mcp_servers)"
complete -c claude -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from remove" -s s -l scope -d "Configuration scope" -rxa "local user project"

# mcp get: dynamic server names
complete -c claude -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from get" -xa "(__fish_claude_mcp_servers)"

# mcp serve flags
complete -c claude -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from serve" -s d -l debug -d "Enable debug mode"
complete -c claude -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from serve" -l verbose -d "Override verbose mode"

# mcp list flags
complete -c claude -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from list" -s h -l help -d "Display help for command"

# mcp reset-project-choices flags
complete -c claude -n "__fish_seen_subcommand_from mcp; and __fish_seen_subcommand_from reset-project-choices" -s h -l help -d "Display help for command"

# =============================================================================
# auth subcommand
# =============================================================================

complete -c claude -n "__fish_seen_subcommand_from auth; and not __fish_seen_subcommand_from login logout status" -xa login -d "Sign in to your Anthropic account"
complete -c claude -n "__fish_seen_subcommand_from auth; and not __fish_seen_subcommand_from login logout status" -xa logout -d "Log out from your Anthropic account"
complete -c claude -n "__fish_seen_subcommand_from auth; and not __fish_seen_subcommand_from login logout status" -xa status -d "Show authentication status"
complete -c claude -n "__fish_seen_subcommand_from auth" -s h -l help -d "Display help for command"

# auth login flags
complete -c claude -n "__fish_seen_subcommand_from auth; and __fish_seen_subcommand_from login" -l claudeai -d "Use Claude subscription (default)"
complete -c claude -n "__fish_seen_subcommand_from auth; and __fish_seen_subcommand_from login" -l console -d "Use Anthropic Console (API billing)"
complete -c claude -n "__fish_seen_subcommand_from auth; and __fish_seen_subcommand_from login" -l email -d "Pre-populate email address" -rx
complete -c claude -n "__fish_seen_subcommand_from auth; and __fish_seen_subcommand_from login" -l sso -d "Force SSO login flow"

# auth status flags
complete -c claude -n "__fish_seen_subcommand_from auth; and __fish_seen_subcommand_from status" -l json -d "Output as JSON (default)"
complete -c claude -n "__fish_seen_subcommand_from auth; and __fish_seen_subcommand_from status" -l text -d "Output as human-readable text"

# =============================================================================
# auto-mode subcommand
# =============================================================================

complete -c claude -n "__fish_seen_subcommand_from auto-mode; and not __fish_seen_subcommand_from config critique defaults" -xa config -d "Print effective auto mode config as JSON"
complete -c claude -n "__fish_seen_subcommand_from auto-mode; and not __fish_seen_subcommand_from config critique defaults" -xa critique -d "Get AI feedback on custom auto mode rules"
complete -c claude -n "__fish_seen_subcommand_from auto-mode; and not __fish_seen_subcommand_from config critique defaults" -xa defaults -d "Print default auto mode rules as JSON"
complete -c claude -n "__fish_seen_subcommand_from auto-mode" -s h -l help -d "Display help for command"

# auto-mode critique flags
complete -c claude -n "__fish_seen_subcommand_from auto-mode; and __fish_seen_subcommand_from critique" -l model -d "Override which model is used" -rxa "sonnet opus haiku sonnet1m opus1m"

# =============================================================================
# remote-control subcommand (hidden)
# =============================================================================

complete -c claude -n "__fish_seen_subcommand_from remote-control" -s h -l help -d "Show help"
complete -c claude -n "__fish_seen_subcommand_from remote-control" -s v -l verbose -d "Enable verbose output"
complete -c claude -n "__fish_seen_subcommand_from remote-control" -l name -d "Name for the session" -rx
complete -c claude -n "__fish_seen_subcommand_from remote-control" -l permission-mode -d "Permission mode for spawned sessions" -rxa "acceptEdits bypassPermissions default dontAsk plan"
complete -c claude -n "__fish_seen_subcommand_from remote-control" -l debug-file -d "Write debug logs to file" -rF
complete -c claude -n "__fish_seen_subcommand_from remote-control" -l spawn -d "Spawn mode" -rxa "same-dir worktree session"
complete -c claude -n "__fish_seen_subcommand_from remote-control" -l capacity -d "Max concurrent sessions" -rx
complete -c claude -n "__fish_seen_subcommand_from remote-control" -l create-session-in-dir -d "Pre-create session in current directory"
complete -c claude -n "__fish_seen_subcommand_from remote-control" -l no-create-session-in-dir -d "Don't pre-create session"
complete -c claude -n "__fish_seen_subcommand_from remote-control" -l sandbox -d "Enable sandboxing for filesystem and network isolation"
complete -c claude -n "__fish_seen_subcommand_from remote-control" -l no-sandbox -d "Disable sandboxing"

# =============================================================================
# plugin subcommand
# =============================================================================

complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from install i uninstall remove list enable disable update validate marketplace" -xa install -d "Install a plugin"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from install i uninstall remove list enable disable update validate marketplace" -xa i -d "Install a plugin (alias)"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from install i uninstall remove list enable disable update validate marketplace" -xa uninstall -d "Uninstall a plugin"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from install i uninstall remove list enable disable update validate marketplace" -xa remove -d "Uninstall a plugin"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from install i uninstall remove list enable disable update validate marketplace" -xa list -d "List installed plugins"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from install i uninstall remove list enable disable update validate marketplace" -xa enable -d "Enable a disabled plugin"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from install i uninstall remove list enable disable update validate marketplace" -xa disable -d "Disable an enabled plugin"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from install i uninstall remove list enable disable update validate marketplace" -xa update -d "Update a plugin"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from install i uninstall remove list enable disable update validate marketplace" -xa validate -d "Validate a plugin"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from install i uninstall remove list enable disable update validate marketplace" -xa marketplace -d "Manage plugin marketplaces"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins" -s h -l help -d "Display help for command"

# plugin install (alias: i)
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from install i" -s s -l scope -d "Installation scope" -rxa "local user project"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from install i" -xa "(__claude_available_plugins)"

# plugin uninstall/remove
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from uninstall remove; and not __fish_seen_subcommand_from marketplace" -s s -l scope -d "Uninstall from scope" -rxa "local user project"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from uninstall remove; and not __fish_seen_subcommand_from marketplace" -l keep-data -d "Keep plugin data after uninstall"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from uninstall remove; and not __fish_seen_subcommand_from marketplace" -xa "(__claude_installed_plugins)"

# plugin enable
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from enable" -s s -l scope -d "Configuration scope" -rxa "local user project"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from enable" -xa "(__claude_disabled_plugins)"

# plugin disable
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from disable" -s a -l all -d "Disable all plugins"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from disable" -s s -l scope -d "Configuration scope" -rxa "local user project"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from disable" -xa "(__claude_enabled_plugins)"

# plugin update
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from update; and not __fish_seen_subcommand_from marketplace" -s s -l scope -d "Configuration scope" -rxa "local user project managed"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from update; and not __fish_seen_subcommand_from marketplace" -xa "(__claude_installed_plugins)"

# plugin list
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from list" -l available -d "Show available plugins"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from list" -l json -d "Output as JSON"

# plugin validate: path completion
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from validate" -rF

# plugin marketplace sub-subcommands
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from marketplace; and not __fish_seen_subcommand_from add remove rm list update" -xa add -d "Add a marketplace"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from marketplace; and not __fish_seen_subcommand_from add remove rm list update" -xa remove -d "Remove a marketplace"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from marketplace; and not __fish_seen_subcommand_from add remove rm list update" -xa rm -d "Remove a marketplace"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from marketplace; and not __fish_seen_subcommand_from add remove rm list update" -xa list -d "List marketplaces"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from marketplace; and not __fish_seen_subcommand_from add remove rm list update" -xa update -d "Update marketplace(s)"

# plugin marketplace add flags
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from marketplace; and __fish_seen_subcommand_from add" -l scope -d "Configuration scope" -rxa "local user project"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from marketplace; and __fish_seen_subcommand_from add" -l sparse -d "Use sparse checkout"

# plugin marketplace list flags
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from marketplace; and __fish_seen_subcommand_from list" -l json -d "Output as JSON"

# plugin marketplace remove/update dynamic completions
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from marketplace; and __fish_seen_subcommand_from remove rm" -xa "(__claude_marketplace_names)"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and __fish_seen_subcommand_from marketplace; and __fish_seen_subcommand_from update" -xa "(__claude_marketplace_names)"

# =============================================================================
# install subcommand
# =============================================================================

complete -c claude -n "__fish_seen_subcommand_from install" -xa "stable latest" -d "Install target version"
complete -c claude -n "__fish_seen_subcommand_from install" -l force -d "Force installation"
complete -c claude -n "__fish_seen_subcommand_from install" -s h -l help -d "Display help for command"

# =============================================================================
# Simple subcommands (help only)
# =============================================================================

complete -c claude -n "__fish_seen_subcommand_from doctor" -s h -l help -d "Display help for command"
complete -c claude -n "__fish_seen_subcommand_from update upgrade" -s h -l help -d "Display help for command"
complete -c claude -n "__fish_seen_subcommand_from setup-token" -s h -l help -d "Display help for command"

# agents subcommand
complete -c claude -n "__fish_seen_subcommand_from agents" -l setting-sources -d "Setting sources to load" -rx
complete -c claude -n "__fish_seen_subcommand_from agents" -s h -l help -d "Display help for command"
