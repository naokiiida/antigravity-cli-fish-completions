# antigravity-cli-fish-completions

Fish shell tab completions for the Google Antigravity CLI (`agy`).

## Requirements

- **Fish 4.0+** — Uses `path` builtin (`path basename -E`, `path mtime -R`)

## Key Files

- **`completions/agy.fish`** — Main completion script. Contains helper functions, subcommand routing, flag definitions, and alias propagation (`antigravity` -> `agy`).
- **`scripts/verify-completions.fish`** — Static verification (11 tests). Sources the completion file and checks registrations. No external CLI required.
- **`scripts/drift-check.fish`** — Dynamic drift detection. Compares completions against `agy --help` output. Requires `agy` in PATH. Run as subprocess (`fish scripts/drift-check.fish`).
- **`agy-version`** — Tracks which `agy` CLI version the completions are based on.
- **`.agents/skills/update-completions/SKILL.md`** — Antigravity skill for regenerating or updating completions.

## Architecture

The completion file has these sections (in order):
1. Header + `complete -c agy -f` + `complete -c antigravity -w agy`
2. Helper functions (`__fish_agy_*` for conversations, agents, MCP servers, and plugins)
3. Subcommand registrations via `__fish_use_subcommand`
4. Top-level flag definitions
5. Per-subcommand sections (`install`, `mcp`, `mic-serve`, `plugin`, `remote-control`, `help`)

### Dynamic Completions

Helper functions provide live, responsive completions:
- `__fish_agy_conversations`: Scans `~/.gemini/antigravity-cli/conversations/*.db`, formats UUIDs with relative elapsed time (e.g. `(just now)`, `(5m ago)`, `(2h ago)`).
- `__fish_agy_agents`: Retrieves agents from `command agy agents` and workspace agent definitions.
- `__fish_agy_mcp_servers`: Configured MCP servers from `~/.gemini/antigravity-cli/mcp/` and `agy mcp list`.
- `__fish_agy_mcp_enabled_servers` / `__fish_agy_mcp_disabled_servers`: Filtered servers for `disable` and `enable`.
- `__fish_agy_installed_plugins` / `__fish_agy_enabled_plugins` / `__fish_agy_disabled_plugins`: Parsed directly from `agy plugin list --json`.

No `jq` or `python` dependency — all JSON and string parsing uses pure fish `string` builtins.

## Development & Testing

```fish
# Test changes interactively
source completions/agy.fish
complete -C "agy "
complete -C "agy mcp "
complete -C "agy --"

# Run static verification
fish scripts/verify-completions.fish

# Run drift detection against installed agy CLI
fish scripts/drift-check.fish
```

## Tool Preferences

- Always prefer `rg` over `grep` and `fd` over `find`.
