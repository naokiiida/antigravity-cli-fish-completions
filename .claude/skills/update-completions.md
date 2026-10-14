---
name: update-completions
description: >
  This skill should be used when the user wants to update completions,
  sync completions with the latest Claude CLI, fix completion drift,
  regenerate the fish completion script, check if completions are
  out of date, handle a new Claude CLI version, or fix stale completions.
  It runs drift detection, reviews the upstream changelog, fixes missing
  completions, updates the version file and changelog, and verifies the result.
allowed-arguments:
  - --force
---

Fix drift between the fish completion script and the current Claude CLI.

## Step 1: Run Drift Check and Review Upstream CHANGELOG

```bash
fish scripts/drift-check.fish
```

If no drift is detected and `--force` is NOT in $ARGUMENTS, report "No drift detected" and stop.

### Review Upstream CHANGELOG

Fetch the upstream Claude Code CHANGELOG for context on what changed:

```bash
VERSION=$(cat claude-version)
curl -s https://raw.githubusercontent.com/anthropics/claude-code/refs/heads/main/CHANGELOG.md \
  | sed -n "/^## $VERSION/q;p"
```

Review the output for CLI-facing changes (new commands, renamed flags, removed options). Use this context alongside the drift report when fixing items in Step 2.

## Step 2: Fix MISSING Items

For each `MISSING` line in the drift report, run `claude <subcommand> --help` to get the exact flags, values, and descriptions. Then update `completions/claude.fish`.

### Hidden Commands

Some commands work but are not listed in `claude --help`. Always check these separately:

| Command | Description |
|---------|-------------|
| `remote-control` | Connect local environment to claude.ai/code |

Run `claude remote-control --help` to verify current flags.

### Fish Completion Patterns

```fish
# Simple toggle flag
complete -c claude -l flag-name -d "Description"

# Flag with short form
complete -c claude -s f -l flag-name -d "Description"

# Flag with enumerated values
complete -c claude -l flag-name -d "Description" -rxa "val1 val2 val3"

# Flag requiring a value (freeform)
complete -c claude -l flag-name -d "Description" -rx

# Flag with file completion
complete -c claude -l flag-name -d "Description" -rF

# Flag with directory completion
complete -c claude -l flag-name -d "Description" -rxa "(__fish_complete_directories)"

# Subcommand (top level)
complete -c claude -n __fish_use_subcommand -xa "subcmd" -d "Description"

# Nested subcommand
complete -c claude -n "__fish_seen_subcommand_from parent; and not __fish_seen_subcommand_from child1 child2" -xa child1 -d "Description"

# Subcommand-specific flag
complete -c claude -n "__fish_seen_subcommand_from subcmd" -l flag -d "Description"

# Dynamic completion using helper function
complete -c claude -n "CONDITION" -xa "(helper_function)"
```

### Rules
- Top-level flags and subcommands use `__fish_use_subcommand` (fish built-in)
- Helper functions parse JSON using fish `string` builtins — no jq/python3
- **REQUIRED (Fish 4.0+)**: Use `path basename -E` instead of `basename`, `path mtime -R` instead of `stat`/`date`. Never use the external `basename`/`stat`/`date` commands.
- Descriptions (`-d`) should match the CLI help text

### File Structure (preserve this order)
1. Header + `complete -c claude -f`
2. Helper functions (`__fish_claude_*` and `__claude_*`)
3. Subcommand registrations
4. Top-level flags
5. Per-subcommand sections

## Step 3: Update Version and Changelog

1. Write the new version to `claude-version`: `claude --version`
2. Update `CHANGELOG.md`:

```markdown
## [VERSION] - YYYY-MM-DD

### Added
- New `--flag` option: description

### Changed
- Updated `--flag` values

### Removed
- Removed `--old-flag`
```

Only include categories that have changes.

## Step 4: Verify

If subcommands, flags, or helper functions were added/removed, first update the hardcoded regression guards in `scripts/verify-completions.fish`.

```bash
fish scripts/verify-completions.fish
fish scripts/drift-check.fish
```

Both must pass.
