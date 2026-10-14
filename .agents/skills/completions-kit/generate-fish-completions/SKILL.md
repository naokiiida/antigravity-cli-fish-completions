---
name: generate-fish-completions
description: >
  Generates deterministic, zero-leak, pure-Fish 4.0+ shell completions for any CLI.
  Crawls --help and introspects binary strings, produces a canonical JSON AST, and compiles
  Fish completions with guaranteed root flag isolation and token-counting positional handlers.
---

# generate-fish-completions

Generate production-grade Fish shell completions for any command-line tool from scratch.

## End-to-End Workflow

```bash
# From completions-kit directory
just pipeline <cli> <dest-dir>
```
Or run the step-by-step pipeline manually:

### Phase 1: Dual-Channel CLI Crawling & Spec Generation
Run the universal crawler to interrogate the target CLI:
```bash
python3 generate-fish-completions/scripts/crawl-cli.py <cli> -o <dest-dir>/<cli>.spec.json
```
This automatically:
- Tests framework introspection (`__complete` for Cobra, Click `_*_COMPLETE`).
- Recursively traverses `--help` and `-h` trees.
- Performs static binary inspection (`strings`) to find candidate flags and environment variables.
- Probes binary flag candidates against the CLI parser to discover hidden/debug flags.
- Normalizes subcommands, flags, repeatable flags, and enum choices.

### Phase 2: Dynamic Source Modeling (Optional)
If the CLI accesses local state (e.g. SQLite databases, config directories, JSON lists, or sockets), design pure-Fish helper functions:
- **Relative timestamps**: Use `path mtime -R "$file"` (Fish 4.0+ builtin).
- **Basenames without forks**: Use `path basename -E "$file"` (Fish 4.0+ builtin).
- **Zero-dependency JSON**: Use pure Fish string replacements (`string replace -ra '\}\s*,\s*\{' '}\n{'`) instead of `jq`.
- **Command completion**: Use `__fish_complete_command` for executables.
- **Directory / File paths**: Use `__fish_complete_directories` or `-rF`.

### Phase 3: Compile Pure-Fish Completions
Compile the JSON spec into a complete Fish completion file:
```bash
python3 generate-fish-completions/scripts/generate-fish.py <dest-dir>/<cli>.spec.json -o <dest-dir>/completions/<cli>.fish
```
The compiler automatically enforces all critical invariants:
- **Root flag isolation**: All top-level flags receive `-n __fish_use_subcommand`, preventing flag leakage into subcommands.
- **Mutual exclusion**: Nested subcommands receive `__fish_seen_subcommand_from <parent>; and not __fish_seen_subcommand_from <siblings>`.
- **Parentheses safety**: No unquoted parentheses in completion variables.

### Phase 4: Scaffold & Run Verification Harness
Scaffold the automated test suite:
```bash
python3 generate-fish-completions/scripts/generate-fish.py <dest-dir>/<cli>.spec.json --scaffold-tests <dest-dir>
```
Run the generated test suite:
```bash
fish <dest-dir>/scripts/verify-completions.fish
fish <dest-dir>/scripts/drift-check.fish
```
Verify interactively:
```fish
source <dest-dir>/completions/<cli>.fish
complete -C "<cli> "
complete -C "<cli> --"
complete -C "<cli> <subcmd> --"
```
Ensure zero root flags leak into `<subcmd> --`.
