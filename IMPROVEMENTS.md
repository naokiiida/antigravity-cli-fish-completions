# Improvement Proposals

Discussion items for reducing AI agent reliance, making CI faster/cost-effective, and increasing resistance to Claude CLI changes.

---

## Bugs

### BUG-1: `string match` stderr spam in drift-check.fish (line 85)

**Symptom**: drift-check.fish outputs 60+ `string match: --(...): unknown option` errors to stderr on every run. The final result is still correct (NO DRIFT / DRIFT DETECTED) but stderr is very noisy.

**Root cause**: `__drift_parse_flags` (line 85) has:
```fish
string match -rga '--([a-zA-Z][-a-zA-Z0-9]*)' -- $line
```
The pattern `'--([a-zA-Z][-a-zA-Z0-9]*)'` starts with `--`, so fish tries to parse it as an option to `string match` before reaching the `--` end-of-options marker.

**Fix**: Move `--` before the pattern:
```fish
string match -rga -- '--([a-zA-Z][-a-zA-Z0-9]*)' $line
```

**Impact**: Silent failure on lines where `$line` itself starts with `--`. The flag parsing may be missing some flags but coincidentally still produces correct drift results because `complete -C` comparison catches the same gaps. This is fragile — a future CLI help format change could cause silent false negatives.

**Severity**: Medium. Functional now but unreliable.

---

## Proposals

## A. Auto-detect subcommand trees in drift-check.fish

**Current**: `subcmd_checks` (line 167) hardcodes which subcommands have sub-subcommands: `mcp auth auto-mode plugin`. Adding a new subcommand tree requires manual update.

**Proposal**: Auto-discover by probing each subcommand's `--help` output:
```fish
set -l subcmd_checks
for subcmd in $help_subcmds
    if claude $subcmd --help 2>&1 | string match -q "*Commands:*"
        set -a subcmd_checks $subcmd
    end
end
```

**Trade-off**: Adds ~10 CLI calls (~5-10s). Acceptable in CI, may be noticeable locally. Could add `--fast` flag to skip auto-detection and use hardcoded list.

**Also applies to**: `flag_checks` (lines 203-208) — subcommands with their own flags. Full auto-detection would check every subcommand for flags, which is expensive. Consider keeping this list manual with maintenance comments.

## B. CI cost reduction — merge two `claude -p` calls into one

**Current**: CI invokes `claude -p` twice when drift is detected:
1. Fix drift (line 80-89) — `--dangerously-skip-permissions`
2. Create PR (line 117-118) — `--allowedTools "Bash(git:*),Bash(gh:*)"`

**Proposal**: Merge into a single invocation that fixes drift, commits, and creates the PR:
```yaml
- name: Fix drift and create PR
  run: |
    claude -p "Fix drift per .claude/skills/update-completions.md, then commit and create a PR." \
      --dangerously-skip-permissions \
      --allowedTools "Read,Edit,Bash(fish:*),Bash(claude:*),Bash(git:*),Bash(gh:*)"
```

**Impact**: ~50% reduction in AI token cost per CI run.

## C. Structured drift output for better CI prompts

**Current**: Drift report is human-readable text. CI passes the entire report as-is to `claude -p`.

**Proposal**: Add machine-readable summary at the end of drift-check output:
```
---DRIFT-SUMMARY---
MISSING:subcmd:remote-control:--new-flag
MISSING:toplevel:--new-option
MISSING:subcmd-tree:new-command
```

**Impact**: CI can generate more targeted prompts, reducing token usage and improving fix accuracy.

## D. Deterministic auto-fix script

**Current**: All drift fixes go through AI agent.

**Proposal**: Create `scripts/auto-fix-drift.fish` that handles mechanical cases:
- New simple flag → generate `complete -c claude -l flag-name -d "Description"` from `--help`
- New subcommand → generate `complete -c claude -n __fish_use_subcommand -xa subcmd -d "Description"`

AI agent handles only complex cases (new subcommand trees, restructured flags, helper functions).

**Impact**: Most drift fixes become deterministic. AI cost drops to near-zero for typical CLI updates.

**Effort**: Medium-high. Requires parsing `--help` output format reliably.

## E. CLAUDE.md → `.claude/` consolidation (long-term)

**Current**: `CLAUDE.md` contains architecture docs loaded on every conversation (~68 lines).

**Goal**: Migrate content into `.claude/skills/` so it loads only when relevant. When complete, CLAUDE.md becomes minimal or unnecessary.

**Steps**:
1. Current: Architecture info duplicated in skill (done)
2. Next: Remove architecture from CLAUDE.md once skill-only loading is confirmed working
3. Future: Move remaining CLAUDE.md content (requirements, dev commands) into appropriate `.claude/` files

## F. verify-completions.fish hardcoded values

**Current**: Hardcoded lists of expected subcommands, flags, and helper functions serve as regression guards.

**Assessment**: This is intentional by design. These values should be updated as part of the same commit that changes `completions/claude.fish`. The `/update-completions` skill documents this requirement.

**No change needed** — just ensure the update workflow always includes verify script updates.

## G. CI workflow uses `python3` for JSON parsing (line 21)

**Current**: `check-version` job parses npm registry JSON with `python3 -c "import sys,json; ..."`.

**Issue**: Inconsistent with project principle of "no external dependencies for JSON parsing." The completion script uses fish `string` builtins, but CI uses python3.

**Proposal**: Replace with `jq` (available on ubuntu-latest runners) or `string` builtins in fish:
```yaml
# Option 1: jq (simpler)
LATEST=$(curl -s https://registry.npmjs.org/@anthropic-ai/claude-code/latest | jq -r '.version')

# Option 2: fish (consistent with project)
LATEST=$(fish -c "curl -s https://registry.npmjs.org/@anthropic-ai/claude-code/latest | string match -rg '\"version\":\"([^\"]+)\"'")
```

**Severity**: Low. Works fine, just a consistency nit.

## H. CI `--dangerously-skip-permissions` is overly broad (line 89)

**Current**: The fix-drift step uses `--dangerously-skip-permissions` with no tool restrictions. The AI agent has full system access.

**Proposal**: Use `--allowedTools` to restrict to only what's needed:
```yaml
claude -p "..." \
  --dangerously-skip-permissions \
  --allowedTools "Read,Edit,Bash(fish:*),Bash(claude:*)"
```

**Impact**: Reduces blast radius if AI agent misbehaves. Especially important for a daily automated CI job.

---

## Priority

| Item | Impact | Effort | Priority |
|------|--------|--------|----------|
| BUG-1. string match fix | Medium (correctness) | Trivial | 0 |
| B. Merge CI calls | High (cost -50%) | Low | 1 |
| H. Restrict CI permissions | Medium (security) | Trivial | 2 |
| A. Auto-detect subcmds | Medium (resilience) | Low | 3 |
| C. Structured output | Medium (accuracy) | Low | 4 |
| G. CI python3 → jq | Low (consistency) | Trivial | 5 |
| E. CLAUDE.md consolidation | Low (context savings) | Low | 6 |
| D. Deterministic auto-fix | High (cost -90%) | Medium-high | 7 |

---

## Skill Review: `update-completions.md` (commit 10da76b)

Reviewed after migration from `.claude/commands/` to `.claude/skills/`.

### I. Skill description lacks trigger phrases

**Current**:
```yaml
description: Fix completion drift against current Claude CLI. Run drift check, fix missing completions, update version/changelog, and verify.
```

**Issue**: Procedural ("Run drift check, fix...") rather than trigger-oriented. Users saying "update the completions" or "sync with latest CLI" may not reliably trigger the skill.

**Fix**: Rewrite to include natural-language trigger phrases:
```yaml
description: >
  This skill should be used when the user wants to update completions,
  sync completions with the latest Claude CLI, fix completion drift,
  regenerate the fish completion script, or check if completions are
  out of date. It runs drift detection, fixes missing completions,
  updates the version file and changelog, and verifies the result.
```

**Severity**: Major. Affects discoverability.

### J. Architecture Reference duplicates CLAUDE.md

**Current**: Lines 79-103 of the skill contain a near-verbatim copy of the Architecture section from CLAUDE.md. Since CLAUDE.md is always loaded into context, this wastes tokens on every invocation.

**Fix**:
1. Remove the duplicated Architecture Reference block (lines 79-103)
2. Keep the verification script reminder (line 107) — it's unique and actionable
3. Relocate that reminder into the "Rules" subsection of Step 2 as a new bullet:
   ```
   - When adding/removing subcommands, flags, or helper functions, also update the hardcoded regression guards in `scripts/verify-completions.fish`
   ```

**Severity**: Major. Context token waste.

### K. Imperative voice inconsistency

**Current**: Line 8 uses "You are fixing drift..." (second person) while the rest of the skill uses imperative voice.

**Fix**: Change to "Fix drift between the fish completion script and the current Claude CLI."

**Severity**: Minor. Style consistency.

---

### Updated Priority Table

| Item | Impact | Effort | Priority | Status |
|------|--------|--------|----------|--------|
| BUG-1. string match fix | Medium (correctness) | Trivial | 0 | **DONE** |
| I. Skill trigger description | Medium (discoverability) | Trivial | 3 | **DONE** |
| J. Remove duplicated architecture | Medium (token waste) | Low | 4 | **DONE** |
| K. Imperative voice fix | Low (style) | Trivial | 8 | **DONE** |
| B. Merge CI calls | High (cost -50%) | Low | 1 | Open |
| H. Restrict CI permissions | Medium (security) | Trivial | 2 | Open |
| A. Auto-detect subcmds | Medium (resilience) | Low | 5 | Open |
| C. Structured output | Medium (accuracy) | Low | 6 | Open |
| G. CI python3 → jq | Low (consistency) | Trivial | 7 | Open |
| E. CLAUDE.md consolidation | Low (context savings) | Low | 9 | Open |
| D. Deterministic auto-fix | High (cost -90%) | Medium-high | 10 | Open |
| U. CHANGELOG integration | Medium (accuracy) | Low | — | **DONE** |

---

## U. CHANGELOG integration for drift context

**Current**: CI and skill rely solely on drift-check output (structural diff). When fixing drift, the AI has no context on *why* things changed.

**Implemented**: Fetch upstream CHANGELOG entries between tracked and latest version using `curl | sed`. Pass to Claude alongside drift report in both CI and skill workflows. No new dependencies — uses only `curl` and `sed`.

**Command**:
```bash
curl -s https://raw.githubusercontent.com/anthropics/claude-code/refs/heads/main/CHANGELOG.md \
  | sed -n '/^## '"$(cat claude-version)"'/q;p'
```

**Impact**: Better fix accuracy — Claude knows if a flag was renamed vs. removed, or if a new subcommand tree was introduced.

---

## Competitive Analysis (5 reference repositories)

Compared against 5 third-party Claude Code completion projects (2 fish, 1 bash, 1 zsh, 1 multi-shell). Our implementation is a strict superset in CLI-level coverage. Key findings below.

### Implemented from reference repos

| Item | Source | What |
|------|--------|------|
| L. `cc` alias support | hmmf022-cc-completion | `complete -c cc -w claude` propagates all completions to the common `cc` alias |
| M. Tool name completions | hmmf022-cc-completion | Static list for `--tools`, `--allowedTools`, `--disallowedTools` (Bash, Edit, Read, Write, etc.) |
| N. `--sandbox`/`--no-sandbox` flags | wbingli-zsh-claudecode-completion | Added to `remote-control` subcommand (hidden flags not in `--help`) |
| O. Agent description extraction | InfiniteRoomLabs-fish-claude-completions | Parse YAML frontmatter `description:` from agent `.md` files using pure fish `string` builtins (no Python) |

### Not implemented (future consideration)

| Item | Source | What | Effort | Notes |
|------|--------|------|--------|-------|
| P. Slash command completions | cldotdev-claude-bash-completion | 81 built-in `/` commands + custom command/skill discovery from 4 dirs | Medium | Mainly useful inside REPL, questionable value at shell level |
| Q. Slash command wrapper function | cldotdev-claude-bash-completion | Merge `/command args` into single argument `"/command args"` | Low | Nice UX for `claude /format text` usage |
| R. fzf/fifc agent preview | InfiniteRoomLabs-fish-claude-completions | fzf preview pane showing agent .md content during tab completion | Low | Optional add-on, requires fifc plugin |
| S. Top-level flag gating | InfiniteRoomLabs-fish-claude-completions | Scope top-level flags to `__fish_use_subcommand` to prevent them appearing in subcommand contexts | Medium | More correct but requires adding `-n` to ~30 flag lines |
| T. Interactive `expect` testing | wbingli-zsh-claudecode-completion | Spawn interactive shell to test actual tab completion behavior | Medium | Catches runtime errors static tests miss |

### Rejected

| Item | Source | Reason |
|------|--------|--------|
| `delegate` permission mode | scaryrawr-claude-code.fish | Not a valid value per `claude --help`. They have it wrong. |

### Also implemented after verification

| Item | Source | What |
|------|--------|------|
| `best`/`opusplan` model values | hmmf022-cc-completion | Verified valid via `claude --model best/opusplan --print`. Added to `--model` and `--fallback-model`. |
