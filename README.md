# claude-code-fish-completions

Fish shell tab completions for [Claude Code](https://claude.ai/code) CLI.

## Features

- Full coverage of all commands, subcommands, and flags
- Dynamic completions for plugins, MCP servers, agents, and sessions
- Hidden command support (`remote-control`)
- Auto-updated daily via GitHub Actions + Claude Code
- No external dependencies (no `jq`, no `python3` — pure fish `string` builtins)

## Requirements

- [Fish shell](https://fishshell.com/) **4.0+** (uses `path` builtin)

## Install

### Fisher

```fish
fisher install naokiiida/claude-code-fish-completions
```

### Manual

```fish
curl -o ~/.config/fish/completions/claude.fish \
  https://raw.githubusercontent.com/naokiiida/claude-code-fish-completions/main/completions/claude.fish
```

### From source

```fish
git clone https://github.com/naokiiida/claude-code-fish-completions.git
ln -s (pwd)/claude-code-fish-completions/completions/claude.fish ~/.config/fish/completions/claude.fish
```

## What's completed

| Area | Coverage |
|------|----------|
| Top-level flags | All 40+ flags with descriptions and value suggestions |
| `mcp` | All subcommands + dynamic server name completion |
| `auth` | `login`, `logout`, `status` with all flags |
| `auto-mode` | `config`, `critique`, `defaults` |
| `plugin` | Full tree including `marketplace` sub-subcommands |
| `remote-control` | Hidden command with all flags |
| `install` | Target versions + `--force` |
| Dynamic | Plugins, MCP servers, agents, sessions, models |

## Verification

```fish
# Static checks (no claude CLI needed — runs in CI)
fish scripts/verify-completions.fish

# Drift detection (compares completions against claude --help)
fish scripts/drift-check.fish
```

## Acknowledgments

Built on the work of:
- [InfiniteRoomLabs/fish-claude-completions](https://github.com/InfiniteRoomLabs/fish-claude-completions)
- [scaryrawr/claude-code.fish](https://github.com/scaryrawr/claude-code.fish)
- [wbingli/zsh-claudecode-completion](https://github.com/wbingli/zsh-claudecode-completion) (automation approach)

## License

MIT
