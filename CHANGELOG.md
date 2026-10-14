# Changelog

All notable changes to antigravity-cli-fish-completions are documented here.

## [Unreleased]

### Added
- Positional command/executable completion for argument 2 of `agy mcp add <name> <commandOrUrl>`.
- Positional completion for `agy plugin install` (local directories and cached marketplace plugins).
- Positional completion for `agy plugin link` (available marketplace names and target directories).
- Multi-path cache directory discovery (`__fish_agy_cache_dir`) supporting environment overrides (`ANTIGRAVITY_CACHE_DIR`, `ANTIGRAVITY_APP_DATA_DIR`, `GEMINI_CLI_HOME`), CLI defaults, and XDG/OS standards.
- Preset duration suggestions for `--print-timeout` (`30s 1m 5m 10m 1h`).
- Cache and marketplace path health check (Test 5) in `scripts/drift-check.fish`.
- Positional completion and timeout preset regression checks in `scripts/verify-completions.fish` (expanded to 12 tests).
- Updated skill guide in `.agents/skills/update-completions/SKILL.md` detailing dynamic data sources, cache probing, and token count patterns.

## [1.3.5] - 2026-10-14

### Added
- Initial release of Fish completions for Google Antigravity CLI (`agy`) v1.3.5.
- Support for `agy` and alias `antigravity` (`complete -c antigravity -w agy`).
- Full coverage of all top-level flags:
  - `-c/--continue`, `--conversation`, `--dangerously-skip-permissions`, `--disable-slash-commands`
  - `--effort` (`low medium high xhigh max`)
  - `-i/--prompt-interactive`, `--input-format`, `--output-format` (`text json stream-json`)
  - `--json-schema`, `--log-file`, `--mode` (`accept-edits auto plan`)
  - `--model` (with descriptive completions for Gemini 3.8 and Claude models)
  - `--new-project`, `-p/--print`, `--print-timeout`, `--project`, `--prompt`
  - `--remote-control`, `--sandbox`, `--version`, `-h/--help`
  - `--add-dir` (directory completion), `--agent` (agent completion)
- Subcommand tree completions:
  - `mcp`: `add`, `remove`, `list`, `enable`, `disable` with dynamic server suggestions
  - `plugin` / `plugins`: `list`, `import`, `install`, `uninstall`, `enable`, `disable`, `validate`, `link` with dynamic plugin suggestions
  - `remote-control`: `start`, `status`, `stop` with `--name` and `--session`
  - `install`: `--dir`, `--skip-aliases`, `--skip-path`
  - `mic-serve`: `--addr`
  - `help`: dynamic completion of available subcommands
- Dynamic completion helpers:
  - `__fish_agy_conversations`: conversation IDs from `~/.gemini/antigravity-cli/conversations/*.db` with relative timestamps
  - `__fish_agy_agents`: available agents from `agy agents` and local workspaces
  - `__fish_agy_mcp_servers`, `__fish_agy_mcp_enabled_servers`, `__fish_agy_mcp_disabled_servers`: configured MCP servers
  - `__fish_agy_installed_plugins`, `__fish_agy_enabled_plugins`, `__fish_agy_disabled_plugins`: installed plugins from `agy plugin list --json`
- Verification suite (`scripts/verify-completions.fish`) with 10 static offline tests.
- Drift detection tool (`scripts/drift-check.fish`) comparing completions against `agy --help`.
- Update skill in `.agents/skills/update-completions/SKILL.md`.
