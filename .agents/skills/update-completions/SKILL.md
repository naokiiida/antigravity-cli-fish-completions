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
# Root-level flag (REQUIRED: must use -n __fish_use_subcommand to prevent leaking into subcommands)
complete -c agy -n __fish_use_subcommand -l flag-name -d "Description"

# Root-level flag with short form
complete -c agy -n __fish_use_subcommand -s f -l flag-name -d "Description"

# Root-level flag with enumerated values
complete -c agy -n __fish_use_subcommand -l flag-name -d "Description" -rxa "val1 val2 val3"

# Root-level flag requiring a value (freeform)
complete -c agy -n __fish_use_subcommand -l flag-name -d "Description" -rx

# Root-level flag with file completion
complete -c agy -n __fish_use_subcommand -l flag-name -d "Description" -rF

# Root-level flag with directory completion
complete -c agy -n __fish_use_subcommand -l flag-name -d "Description" -rxa "(__fish_complete_directories)"

# Subcommand (top level)
complete -c agy -n __fish_use_subcommand -xa "subcmd" -d "Description"

# Nested subcommand
complete -c agy -n "__fish_seen_subcommand_from parent; and not __fish_seen_subcommand_from child1 child2" -xa child1 -d "Description"

# Subcommand-specific flag
complete -c agy -n "__fish_seen_subcommand_from subcmd" -l flag -d "Description"

# Dynamic completion using helper function
complete -c agy -n "CONDITION" -xa "(helper_function)"

# Positional argument with directory & dynamic catalog completion
complete -c agy -n "CONDITION" -a "(__fish_complete_directories)" -d "Directory"
complete -c agy -n "CONDITION" -a "(helper_function)"

# Command/executable completion for positional argument
complete -c agy -n "CONDITION" -a "(__fish_complete_command)" -d "Command"
```

### Rules
- **CRITICAL: Flag Scoping & Isolation**: Root-level flags MUST be scoped with `-n __fish_use_subcommand`. In Fish shell, flags registered without a condition match in *all* commandline contexts, which leaks root flags into subcommands where they are invalid. Only register unbounded flags if the CLI explicitly supports those flags across every subcommand.
- Top-level subcommands use `__fish_use_subcommand` (fish built-in).
- Helper functions parse output using fish `string` builtins — no jq/python3.
- **REQUIRED (Fish 4.0+)**: Use `path basename -E` instead of `basename`, `path mtime -R` instead of `stat`/`date`. Never use the external `basename`/`stat`/`date` commands.
- Descriptions (`-d`) should match the CLI help text.
- Positional argument completions must inspect `commandline -cop` token counts to avoid leaking into subsequent arguments or prior flags.
- When adding/removing subcommands, flags, or helper functions, also update the hardcoded regression guards in `scripts/verify-completions.fish`.

### Cache Directory Anticipation & Dynamic Sources

The `agy` CLI relies on local state and cache directories that may shift across releases or platforms:
- **Cache Path Resolution (`__fish_agy_cache_dir`)**: Probes candidates in priority order:
  1. Environment overrides: `$ANTIGRAVITY_CACHE_DIR`, `$ANTIGRAVITY_APP_DATA_DIR/cache`, `$GEMINI_CLI_HOME/cache`.
  2. CLI default path: `~/.gemini/antigravity-cli/cache`.
  3. Standards: `$XDG_CACHE_HOME/antigravity-cli`, `~/.cache/antigravity-cli`, `~/Library/Caches/antigravity-cli`.
- **Marketplace Discovery (`__fish_agy_marketplace_dirs`)**: Probes `$cache_dir/marketplaces` and standalone paths (`~/.gemini/antigravity-cli/marketplaces`, `~/.gemini/config/marketplaces`).
- **Anticipating CLI Cache Relocations**: When upgrading `agy`, run `fish scripts/drift-check.fish`. Test 5 specifically verifies that cache and marketplace paths resolve. If Google Antigravity renames or relocates cache folders, add the new path to `__fish_agy_cache_dir` candidate list.
- **Dynamic Completions Inventory**:
  - `__fish_agy_conversations`: Formatted with relative time from `.db` mtime.
  - `__fish_agy_agents`: CLI agents + custom agent `.md` frontmatter descriptions.
  - `__fish_agy_mcp_servers` / `__fish_agy_mcp_enabled_servers` / `__fish_agy_mcp_disabled_servers`: State-aware MCP server listing.
  - `__fish_agy_installed_plugins` / `__fish_agy_enabled_plugins` / `__fish_agy_disabled_plugins`: State-aware plugin listing from JSON.
  - `__fish_agy_marketplace_plugins`: Pure fish parser for `marketplace.json` plugin catalogs.
  - `__fish_agy_mcp_add_command`: Command completion for argument 2 of `mcp add`.

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
