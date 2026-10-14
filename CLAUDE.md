# claude-code-fish-completions

Fish shell tab completions for the Claude Code CLI.

## Requirements

- **Fish 4.0+** — Uses `path` builtin (`path basename -E`, `path mtime -R`)

## Key Files

- **`completions/claude.fish`** — Main completion script. Contains all helper functions, subcommand routing, and flag definitions.
- **`scripts/verify-completions.fish`** — Static verification (10 tests). Sources the completion file and checks registrations. No `claude` CLI required.
- **`scripts/drift-check.fish`** — Dynamic drift detection. Compares completions against `claude --help` output to find mismatches. Requires `claude` CLI. Run as subprocess (`fish scripts/drift-check.fish`), not via `source`.
- **`claude-version`** — Tracks which Claude CLI version the completions are based on.
- **`.claude/skills/update-completions.md`** — Skill for Claude Code to regenerate completions.
- **Upstream CHANGELOG** — `https://raw.githubusercontent.com/anthropics/claude-code/refs/heads/main/CHANGELOG.md` — Used by CI and `/update-completions` skill to understand what changed between versions.

## Architecture

The completion file has these sections (in order):
1. Header + `complete -c claude -f`
2. Helper functions (`__fish_claude_*` for sessions/agents/mcp, `__claude_*` for plugins)
3. Subcommand registrations
4. Top-level flag definitions
5. Per-subcommand sections (mcp, auth, auto-mode, remote-control, plugin, install, simple subcommands, agents)

### Subcommand Detection

Uses `__fish_use_subcommand` (fish built-in) for top-level subcommand detection and `__fish_seen_subcommand_from` for nested subcommands. No custom detection function is needed — fish handles this natively.

### Dynamic Completions

Helper functions call `claude` CLI with `--json` at tab time for live suggestions:
- `__claude_installed_plugins` / `__claude_enabled_plugins` / `__claude_disabled_plugins`
- `__claude_available_plugins` / `__claude_marketplace_names`
- `__fish_claude_mcp_servers` (parses config files, falls back to CLI)
- `__fish_claude_sessions` (reads session files from disk)
- `__fish_claude_agents` (reads agent .md files)

No `jq` dependency — all JSON parsing uses fish `string` builtins.

## Development

```fish
# Test changes
source completions/claude.fish
complete -C "claude "
complete -C "claude mcp "
complete -C "claude --"

# Run static verification (no claude CLI needed)
fish scripts/verify-completions.fish

# Run drift detection (requires claude CLI)
fish scripts/drift-check.fish
```

## Skills

### `/update-completions`
Updates completions to match latest Claude CLI. Runs drift check, fixes missing items, updates version/changelog, and verifies. Use `--force` to skip version check.

## Git Notes

The `.claude/` folder may be in global `.gitignore`. Use `-f` when adding:
```bash
git add -f .claude/
```
