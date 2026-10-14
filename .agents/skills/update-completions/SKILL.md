---
name: update-completions
description: >
  This skill should be used when the user wants to update completions,
  sync completions with the latest agy CLI (Google Antigravity CLI), fix completion drift,
  regenerate the fish completion script, check if completions are
  out of date, handle a new agy CLI version, or fix stale completions.
  It runs drift detection, reviews the changelog, fixes missing
  completions, updates the version file and changelog, and verifies the result.
allowed-arguments:
  - --force
---

# Update Completions for Antigravity CLI (`agy`)

Fix drift between the fish completion script and the current `agy` CLI.

## Step 1: Run Drift Check and Review Changelog

```bash
fish scripts/drift-check.fish
```

If no drift is detected and `--force` is NOT provided, report "No drift detected" and stop.

### Review Changelog

Check what changed in the current `agy` CLI:

```bash
agy changelog
```

Review the output for CLI-facing changes (new commands, renamed flags, removed options).

## Step 2: Fix MISSING Items

For each `MISSING` line in the drift report, run `agy <subcommand> --help` to inspect the exact flags, values, and descriptions. Then update `completions/agy.fish`.

### Fish Completion Patterns

```fish
# Simple toggle flag
complete -c agy -l flag-name -d "Description"

# Flag with short form
complete -c agy -s f -l flag-name -d "Description"

# Flag with enumerated values
complete -c agy -l flag-name -d "Description" -rxa "val1 val2 val3"

# Flag requiring a value (freeform)
complete -c agy -l flag-name -d "Description" -rx

# Flag with file completion
complete -c agy -l flag-name -d "Description" -rF

# Flag with directory completion
complete -c agy -l flag-name -d "Description" -rxa "(__fish_complete_directories)"

# Subcommand (top level)
complete -c agy -n __fish_use_subcommand -xa "subcmd" -d "Description"

# Nested subcommand
complete -c agy -n "__fish_seen_subcommand_from parent; and not __fish_seen_subcommand_from child1 child2" -xa child1 -d "Description"

# Subcommand-specific flag
complete -c agy -n "__fish_seen_subcommand_from subcmd" -l flag -d "Description"

# Dynamic completion using helper function
complete -c agy -n "CONDITION" -xa "(helper_function)"
```

### Rules
- Top-level subcommands use `__fish_use_subcommand` (fish built-in).
- Helper functions parse output using fish `string` builtins — no jq/python3.
- **REQUIRED (Fish 4.0+)**: Use `path basename -E` instead of `basename`, `path mtime -R` instead of `stat`/`date`. Never use the external `basename`/`stat`/`date` commands.
- Descriptions (`-d`) should match the CLI help text.
- When adding/removing subcommands, flags, or helper functions, also update the hardcoded regression guards in `scripts/verify-completions.fish`.

## Step 3: Update Version and Changelog

1. Write the new version to `agy-version`:
   ```bash
   agy --version > agy-version
   ```
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

## Step 4: Verify

```bash
fish scripts/verify-completions.fish
fish scripts/drift-check.fish
```

Both must pass with 0 exit codes.
