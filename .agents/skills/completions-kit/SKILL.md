---
name: completions-kit
description: >
  Deterministic toolkit for generating, updating, and researching shell completions and
  crafting CLI agent skills. Uses dual-channel CLI introspection (recursive help crawling +
  binary inspection) to produce zero-leak, pure-Fish 4.0+ completions with automated
  bidirectional drift testing.
---

# completions-kit

A deterministic toolkit and suite of agent skills for generating, maintaining, and researching shell completions, and for crafting CLI agent skills for any command-line tool.

## Key Capabilities

1. **`generate-fish-completions`**: Greenfield completion generation for any CLI without completions. Employs a dual-channel crawler (help tree parsing + static binary string inspection and active probing), produces a canonical `carapace-spec`-compatible JSON AST, and compiles pure-Fish 4.0+ completions with guaranteed root flag isolation (`-n __fish_use_subcommand`) and token-counting positional handlers.
2. **`research-community-completions`**: Upfront freshness and version scoring of prior community work across native Fish completions (`$__fish_data_dir/completions`), the Fisher ecosystem (`jorgebucaran/fisher`), Carapace (`carapace-bin`), and GitHub. Detects hallucinations/phantom commands while adopting high-value presets and dynamic actions.
3. **`update-completions`**: Hardened maintenance workflow with bidirectional drift detection (checking both missing flags and leaked/extra flags), changelog diffing, and test regression guards.
4. **`craft-cli-skills`**: Meta-skill for authoring and refining domain-specific agent skills tailored for any target CLI tool.

## Core Architectural Invariants

- **Root Flag Isolation**: Root-level flags MUST be scoped with `-n __fish_use_subcommand` to prevent leaking into subcommands.
- **Positional Token Counting**: Argument position handlers must inspect `commandline -cop`, safely skipping flag switches and flag parameter values.
- **Pure-Fish 4.0+ Builtins**: Zero external runtime subprocesses (`path basename -E`, `path mtime -R`, `string match -r`, `string replace`).
- **Parentheses Escaping**: Helper functions use tab-separated `printf '%s\t%s\n'` rather than unquoted variables to avoid command substitution errors.
- **Bidirectional Verification**: Testing must assert both completeness (all `--help` flags exist) and purity (no extra/leaked flags exist in subcommands).
