# antigravity-cli-fish-completions

Fish shell tab completions for the [Google Antigravity](https://antigravity.google) CLI (`agy`).

## Features

- **Full CLI Coverage**: All top-level flags, subcommands, and nested subcommands matching `agy` v1.3.5+.
- **Alias Support**: Automatically supports both `agy` and the `antigravity` alias (`complete -c antigravity -w agy`).
- **Dynamic Completions**:
  - Recent conversations with human-readable relative time (e.g. `(just now)`, `(5m ago)`, `(2h ago)`).
  - MCP servers with status-aware filtering (enabled vs disabled) and executable/command completion for `mcp add`.
  - Installed, enabled, and disabled plugins directly from `agy plugin list --json`.
  - Dynamic marketplace plugin catalog discovery (`marketplace.json`) for `agy plugin install` and `agy plugin link`.
  - Configured agents from CLI and workspace definitions.
  - Available models with descriptions (`gemini-3.8-flash-*`, `claude-*`, etc.).
- **Zero Dependencies**: Pure Fish builtins using Fish 4+ `path` and `string` — no `jq`, no `python3`, no subshell overhead.
- **Drift Detection**: Automated drift check and test verification suite to ensure completions stay 100% in sync with CLI releases.

## Requirements

- [Fish shell](https://fishshell.com/) **4.0+** (uses `path` builtin)

## Install

### Fisher

```fish
fisher install naokiiida/antigravity-cli-fish-completions
```

For local development or from a local clone:

```fish
fisher install .
```

### Manual

```fish
curl -o ~/.config/fish/completions/agy.fish \
  https://raw.githubusercontent.com/naokiiida/antigravity-cli-fish-completions/main/completions/agy.fish
```

### From source

```fish
git clone https://github.com/naokiiida/antigravity-cli-fish-completions.git
ln -s (pwd)/antigravity-cli-fish-completions/completions/agy.fish ~/.config/fish/completions/agy.fish
```

## Update

### Fisher

To update completions when installed from GitHub:

```fish
fisher update naokiiida/antigravity-cli-fish-completions
# or update all plugins:
fisher update
```

When developing locally or installed from a local clone:

```fish
# Inside the cloned repository directory:
fisher update .
```

## What's completed

| Area | Coverage |
|------|----------|
| Top-level flags | All options (`--continue`, `--conversation`, `--effort`, `--mode`, `--model`, `--output-format`, `--sandbox`, etc.) |
| `mcp` | `add`, `remove`, `list`, `enable`, `disable` + status-aware dynamic server name completion |
| `plugin` / `plugins` | Full command tree (`list`, `import`, `install`, `uninstall`, `enable`, `disable`, `validate`, `link`) + dynamic plugin completion |
| `remote-control` | `start`, `status`, `stop` with all flags (`--name`, `--session`) |
| `install` | Shell and PATH configuration flags (`--dir`, `--skip-aliases`, `--skip-path`) |
| `mic-serve` | Remote microphone serving (`--addr`) |
| `models`, `agent`/`agents` | Model and agent listing commands + flag completion |
| `help`, `changelog`, `update` | Subcommand completions |
| Dynamic suggestions | Conversations (with relative timestamps), MCP servers, plugins, models, agents |

## Verification & Drift Detection

```fish
# Static checks (offline verification — runs in CI)
fish scripts/verify-completions.fish

# Drift detection (compares completions against installed agy --help)
fish scripts/drift-check.fish

# Check upstream GitHub releases & changelog (uses gh CLI API or curl fallback)
fish scripts/check-upstream-release.fish -c

# Run all checks via Justfile
just all
```

### Automated Monitoring

- **GitHub Actions**: `.github/workflows/daily-check.yml` runs daily at 00:00 UTC to detect new upstream releases and verify completions.
- **Antigravity CLI Agent**: Scheduled daily cron can be configured via `/schedule` to monitor upstream releases and local drift automatically.

## License

MIT
