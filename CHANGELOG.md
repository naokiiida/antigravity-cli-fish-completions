# Changelog

All notable changes to antigravity-cli-fish-completions are documented here.

## [Unreleased]

## [1.4.10] - 2026-10-30

### Added
- Verified compatibility with Google Antigravity CLI (`agy`) v1.4.10.
- Added `--settings` flag completion in `completions/agy.fish` for session-scoped configuration (JSON object or file path).
- Expanded static verification in `scripts/verify-completions.fish` to validate `--settings` presence and verify subcommand flag isolation.
- Expanded dynamic drift check coverage in `scripts/drift-check.fish` for `plugins` alias subcommand tree, `agents` flags, and `plugins validate` flags.

### Changed
- Bumped tracked CLI version in `agy-version` from 1.4.9 to 1.4.10.

## [1.4.9] - 2026-10-29

### Added
- Verified compatibility with Google Antigravity CLI (`agy`) v1.4.9.
- Expanded flag drift checks in `scripts/drift-check.fish` to include `update` subcommand flags.
- Expanded static verification in `scripts/verify-completions.fish` for `agents` alias flag completions (`-h`, `--help`) and `plugins` alias subcommand parity (`agy plugins` matching `agy plugin`).

### Changed
- Bumped tracked CLI version in `agy-version` from 1.4.8 to 1.4.9.

## [1.4.8] - 2026-10-28

### Added
- Verified compatibility with Google Antigravity CLI (`agy`) v1.4.8.
- Expanded flag drift checks in `scripts/drift-check.fish` for `mcp` subcommands (`disable`, `enable`, `list`, `remove`) and `remote-control` subcommands (`status`, `stop`).
- Expanded static verification in `scripts/verify-completions.fish` for flags (`-h`, `--help`) across `update`, `mcp` subcommands (`disable`, `enable`, `list`, `remove`), and `remote-control` subcommands (`status`, `stop`).

### Changed
- Bumped tracked CLI version in `agy-version` from 1.4.7 to 1.4.8.

## [1.4.7] - 2026-10-25

### Added
- Verified compatibility with Google Antigravity CLI (`agy`) v1.4.7.
- Expanded flag drift checks in `scripts/drift-check.fish` for `agent`, `changelog`, and `models`.
- Expanded static verification in `scripts/verify-completions.fish` for `agent`, `changelog`, and `models` flags (`-h`, `--help`) and `agy help` positional subcommand completions.

### Changed
- Bumped tracked CLI version in `agy-version` from 1.4.6 to 1.4.7.

## [1.4.6] - 2026-10-24

### Added
- Verified compatibility with Google Antigravity CLI (`agy`) v1.4.6.
- Expanded static test coverage in `scripts/verify-completions.fish` for `-h`/`--help` flags and `-h` short flags across `plugin validate`, `install`, `mcp add`, `mic-serve`, and `remote-control start`.

### Changed
- Aligned `agy plugin validate` `--strict` and `--json` descriptions in `completions/agy.fish` with official 1.4.6 `--help` output.
- Bumped tracked CLI version in `agy-version` from 1.4.5 to 1.4.6.

## [1.4.5] - 2026-10-23

### Added
- Verified compatibility with Google Antigravity CLI (`agy`) v1.4.5.
- Added short flag drift checks (`-c`, `-i`, `-p`) and subcommand short flag drift checks (`-H`, `-e`, `-t` on `mcp add`) in `scripts/drift-check.fish`.
- Added alias wrapper verification (`complete -c antigravity -w agy`, Test 14) in `scripts/verify-completions.fish`.
- Expanded test coverage in `scripts/verify-completions.fish` for top-level short flags (`-c`, `-i`, `-p`), `mcp add` short flags (`-H`, `-e`, `-t`), `plugin list` `--json` flag, and full model suite (13 models).

### Changed
- Bumped tracked CLI version in `agy-version` from 1.4.4 to 1.4.5.

## [1.4.4] - 2026-10-22

### Added
- Verified compatibility with Google Antigravity CLI (`agy`) v1.4.4.
- Added dynamic model options drift check (Test 6) in `scripts/drift-check.fish` validating `agy models` against `__fish_agy_known_models`.
- Added model completion test coverage (Test 13) in `scripts/verify-completions.fish`.
- Expanded flag and value verification across `install`, `mcp add`, `mic-serve`, and `remote-control start` in `scripts/verify-completions.fish`.

### Changed
- Bumped tracked CLI version in `agy-version` from 1.4.3 to 1.4.4.

## [1.4.3] - 2026-10-20

### Added
- Added `gemini-4-argon-high`, `gemini-4-argon-medium`, and `gemini-4-argon-low` to `--model` completion suggestions.
- Added `--strict` (`-d "Fail on warnings"`) and `--json` (`-d "Output validation report as JSON"`) flags to `agy plugin validate`.
- Added flag assertions for `agy plugin validate` in `scripts/verify-completions.fish`.
- Added `"plugin validate"` to `flag_checks` in `scripts/drift-check.fish`.
- Enhanced `__drift_parse_flags` in `scripts/drift-check.fish` to extract flags from inline usage lines (`[--flag]`).
- Positional command/executable completion for argument 2 of `agy mcp add <name> <commandOrUrl>`.
- Positional completion for `agy plugin install` (local directories and cached marketplace plugins).
- Positional completion for `agy plugin link` (available marketplace names and target directories).
- Multi-path cache directory discovery (`__fish_agy_cache_dir`) supporting environment overrides (`ANTIGRAVITY_CACHE_DIR`, `ANTIGRAVITY_APP_DATA_DIR`, `GEMINI_CLI_HOME`), CLI defaults, and XDG/OS standards.
- Preset duration suggestions for `--print-timeout` (`30s 1m 5m 10m 1h`).
- Cache and marketplace path health check (Test 5) in `scripts/drift-check.fish`.
- Positional completion and timeout preset regression checks in `scripts/verify-completions.fish` (expanded to 12 tests).
- Automated daily workflow for upstream release & drift checks (`.github/workflows/daily-check.yml`).
- Upstream release and changelog monitoring script (`scripts/check-upstream-release.fish`).
- Justfile task runner (`just all`, `just verify`, `just drift`, `just check-upstream`).
- Updated skill guide in `.agents/skills/update-completions/SKILL.md` detailing dynamic data sources, cache probing, and token count patterns.

### Changed
- Updated description for `agy plugin validate` to match upstream CLI: `"Check a plugin's manifest and files"`.
- Synced completions-kit upstream tooling with `gh` CLI API and automatic curl fallback.

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
