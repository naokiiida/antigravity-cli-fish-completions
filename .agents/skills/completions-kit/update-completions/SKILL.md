---
name: update-completions
description: >
  Updates and maintains existing Fish shell completions for any CLI.
  Runs bidirectional drift detection (missing flags & leaked flags), reviews upstream changelogs,
  patches completion definitions, updates version tracking, and verifies regression tests.
allowed-arguments:
  - --force
---

# update-completions

Maintain and synchronize Fish shell completions when a target CLI releases a new version or when drift is detected.

## Step 1: Run Bidirectional Drift Detection

```bash
fish scripts/drift-check.fish
```

The bidirectional drift check verifies:
1. **Completeness / Recall**: Are all subcommands and flags in `<cli> --help` present in the completion script?
2. **Purity / Isolation**: Are there any extra or leaked flags (e.g. root flags appearing under subcommands)?

If no drift is detected and `--force` is NOT provided, report "No drift detected" and stop.

## Step 2: Review Upstream Changelog

Check what changed in the new release:
```bash
<cli> changelog # or git log / release notes
```
Look for:
- New subcommands or renamed flags.
- Deprecated or removed flags.
- Changed argument types or added enum choices.

## Step 3: Patch Completion Definitions

Update `completions/<cli>.fish`:

### Critical Scoping Rules
- **Root-level flags**: MUST use `-n __fish_use_subcommand`. Never declare root flags without a condition, or they will leak into subcommands.
  ```fish
  complete -c <cli> -n __fish_use_subcommand -l new-flag -d "Description"
  complete -c <cli> -n __fish_use_subcommand -l effort -d "Effort" -rxa "low medium high max"
  ```
- **Subcommand flags**: Use `__fish_seen_subcommand_from <parent>; and __fish_seen_subcommand_from <child>`.
  ```fish
  complete -c <cli> -n "__fish_seen_subcommand_from parent; and __fish_seen_subcommand_from child" -l flag -d "Description"
  ```
- **Parentheses safety**: In descriptions with parentheses, use helper functions and tab-separated `printf '%s\t%s\n'` to avoid Fish command substitution errors.
- **Pure-Fish 4.0+ builtins**: Never use external `stat`, `date`, `basename`, or `jq`. Use `path basename -E`, `path mtime -R`, and `string match`.

## Step 4: Update Version Tracking & Changelog

1. Update the version file:
   ```bash
   <cli> --version > <cli>-version
   ```
2. Document changes in `CHANGELOG.md` under the new version header.

## Step 5: Verify Suite

Run both static verification and dynamic drift checks:
```bash
fish scripts/verify-completions.fish
fish scripts/drift-check.fish
```
Both must pass with exit code 0.
