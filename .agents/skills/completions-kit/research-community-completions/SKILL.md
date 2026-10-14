---
name: research-community-completions
description: >
  Audits prior community completions across Native Fish ($__fish_data_dir/completions),
  the Fisher ecosystem, Carapace (carapace-bin), and GitHub. Applies upfront freshness
  and version scoring to detect hallucinations and adopt genuine innovations.
---

# research-community-completions

Audit existing third-party shell completions before writing or updating completions for a target CLI.

## Workflow

### 1. Run the Community Auditor
```bash
python3 scripts/audit-community.py <cli>
```

### 2. Upfront Freshness & Version Scoring
Score the source before inspecting flags:
- 🟢 **Fresh (Within 3–6 months / Matching CLI version)**: High confidence. Compare against CLI `--help` to discover useful presets and parameter patterns.
- 🟡 **Medium (6–12 months)**: Moderate risk. Good for dynamic helper patterns, but flags may have drifted.
- 🔴 **Stale (>1 year or older major version)**: High hallucination hazard. Treat as untrusted; flags and commands must be verified individually.

### 3. Cross-Check Against Live CLI
Never copy completions blindly. In prior audits (e.g. Carapace `agy_completer`), community completers had:
- Phantom subcommands (e.g. `agy run` did not exist).
- Phantom flags (e.g. `agy --cwd`, `agy agent --output-format` did not exist).
- Incorrect argument types (e.g. `--new-project` treated as string argument instead of boolean flag).

### 4. Extract High-Value Dynamic Ideas
Focus on adopting:
- **Duration presets**: e.g. `--timeout` suggesting `30s`, `1m`, `5m`, `1h`.
- **Command completions**: e.g. completing executables via `__fish_complete_command` for positional args.
- **Directory / File completion**: e.g. `__fish_complete_directories` or `-rF`.
- **Catalog discovery**: e.g. querying local plugin/marketplace JSON catalogs.
