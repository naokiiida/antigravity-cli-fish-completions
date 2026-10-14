# Changelog

All notable changes to claude-code-fish-completions are documented here.

## [2.1.81] - 2026-03-23

### Changed
- Modernize helper functions to use Fish 4+ `path` builtin
  - Replace `basename` with `path basename -E` (no external process)
  - Replace `stat -f/-c` + `date +%s` + `math` with `path mtime -R` (cross-platform, single call)
- Expand verification script from 5 to 10 tests
- Minimum Fish version: 4.0+ (was: 3.0+)

### Added
- `scripts/drift-check.fish` — drift detection script that compares completions against `claude --help` output
  - Verifies all subcommands, flags, and sub-subcommand trees
  - Detects hidden commands (INFO) vs unexpected extras (WARN)
  - Checks flag aliases (camelCase ↔ kebab-case)
  - No `eval` — calls `claude` directly with parsed subcommand arguments
  - Per-test pass/fail tracking for accurate per-section "OK" output
- CI workflow: trigger on npm release instead of blind daily regeneration
  - Checks `@anthropic-ai/claude-code` npm registry for new versions (once daily)
  - Only runs Claude AI when drift-check detects actual mismatches
  - Passes drift report to Claude for targeted fixes instead of full regeneration

## [2.1.81] - 2026-03-22 (review)

### Fixed
- `plugin i` alias missing from subcommand guard and lacking scope/dynamic completions
- `--model` and `--fallback-model` missing `sonnet1m` and `opus1m` alias values
- `mcp list` and `mcp reset-project-choices` missing `-h/--help` flag
- `CLAUDE.md` referencing removed `__fish_claude_no_subcommand` function
- `update-completions.md` pattern examples using wrong function name
- `update-completions.md` hidden commands table missing `remote-control` flags
- `verify-completions.fish` missing `plugin i` alias test

## [2.1.81] - 2026-03-22

### Added
- Initial release based on Claude Code CLI v2.1.81
- Full coverage of all top-level flags (40+)
- `mcp` subcommand tree with dynamic server name completion
- `auth` subcommand with `login`, `logout`, `status` and all flags (`--claudeai`, `--console`, `--email`, `--sso`, `--json`, `--text`)
- `auto-mode` subcommand with `config`, `critique`, `defaults`
- `remote-control` hidden command with all flags (`--spawn`, `--capacity`, `--[no-]create-session-in-dir`)
- `plugin` subcommand tree including `marketplace` sub-subcommands
- Dynamic completions for installed/enabled/disabled/available plugins
- Dynamic completions for marketplace names
- Dynamic completions for MCP server names (from config files + CLI fallback)
- Dynamic completions for session IDs with relative timestamps
- Dynamic completions for agent names
- `--bare` flag for minimal mode
- `--brief` flag for agent communication
- `-n/--name` flag for session naming
- `-w/--worktree` flag for git worktree sessions
- `--tmux` flag for tmux session creation
- `--effort max` value
- `--permission-mode auto` value
- Verification script (`scripts/verify-completions.fish`)
- GitHub Actions daily auto-update workflow
- Claude Code slash command for regeneration (`/update-completions`)
