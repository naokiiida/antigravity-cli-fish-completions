# Improvement Proposals for Antigravity CLI Completions

Discussion items for expanding dynamic completions, caching, and CI workflows for `agy`.

---

## Proposals

### A. Background Cache for `agy models`

**Current**: `--model` uses a static list of known models with human-readable descriptions (`gemini-3.8-flash-high`, `claude-opus-5-5-high`, etc.).
Calling `agy models` directly at completion time takes ~5 seconds because it performs a network fetch with an interactive spinner, which causes unacceptable lag on `<TAB>`.

**Proposal**:
- Read from `~/.gemini/antigravity-cli/cache/models_cache.txt` if available and not older than 7 days.
- If cache is missing or stale, trigger an async background job (`fish -c "agy models > ~/.gemini/antigravity-cli/cache/models_cache.txt" &`) without blocking the tab prompt.
- Fall back to static model list when cache is empty.

### B. Dynamic Completion for `--project`

**Current**: `--project` is a freeform text flag.

**Proposal**:
- Parse `trustedWorkspaces` from `~/.gemini/antigravity-cli/settings.json`.
- Offer workspace directory names or folder basenames as completions.

### C. Plugin Marketplace Dynamic Names

**Current**: `agy plugin install` takes freeform target `<target>`.

**Proposal**:
- Discover available plugins in known marketplaces or configured directories (`~/.gemini/config/plugins/`).

---

## Status Summary

| Item | Impact | Effort | Status |
|------|--------|--------|--------|
| A. Background model cache | High (responsiveness + freshness) | Low | Planned |
| B. Trusted workspaces for `--project` | Medium (convenience) | Low | Planned |
| C. Marketplace plugin completion | Medium (discoverability) | Medium | Planned |
