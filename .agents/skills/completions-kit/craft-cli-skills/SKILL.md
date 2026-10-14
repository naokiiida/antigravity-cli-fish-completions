---
name: craft-cli-skills
description: >
  Designs, scaffolds, and refines high-leverage agent skills tailored for any target CLI tool.
  Extracts core workflows, identifies structured output and non-interactive execution modes,
  authors natural language frontmatter triggers, and embeds safety guardrails.
---

# craft-cli-skills

A meta-skill for creating and improving agent skills for a specific target CLI.

## Workflow

### 1. Discover Target CLI Capabilities
Introspect the target CLI using `crawl-cli.py`:
```bash
python3 generate-fish-completions/scripts/crawl-cli.py <cli> -o /tmp/<cli>.spec.json
```
Examine the spec to identify:
- **Core User Journeys**: Initialization, authentication, resource creation, deployment, querying, debugging, tear-down.
- **Machine-Friendly Flags**: Flags enabling non-interactive execution (`-y`, `--yes`, `--force`, `--non-interactive`, `--no-prompt`) and structured machine outputs (`--json`, `--output-format json`, `-o json`, `--quiet`).
- **Destructive Commands**: Actions that mutate state, drop databases, or delete cloud resources.

### 2. Scaffold Skill Directory
Create the standard skill structure:
```
<skill-name>/
├── SKILL.md                 # Primary instruction guide
├── scripts/                 # Standalone helper scripts
├── references/              # Cheatsheets, API schemas, flags glossary
└── templates/               # Config file templates (e.g. config.yaml, Dockerfile)
```

### 3. Author Frontmatter & Natural Language Triggers
Ensure the YAML frontmatter in `SKILL.md` contains broad, semantic, problem-oriented trigger phrases:
```yaml
---
name: <cli>-guide
description: >
  Complete guide for operating, configuring, and automating <CLI>.
  Activate this skill when the user asks to manage, deploy, configure, debug,
  or script tasks using <cli>, or encounters errors during <cli> execution.
---
```

### 4. Structure the Skill Guide
Follow the established high-leverage skill structure:
1. **Overview & Golden Invariants**: Rules the agent must never violate when invoking this CLI (e.g. "Always use `--json` when parsing output; never rely on terminal colors").
2. **Workflows by Intent**: Group operations by user goal rather than alphabetical command listings (e.g. "Creating a Workspace", "Deploying to Production", "Inspecting Logs").
3. **Safety & Destructive Guardrails**: Explicit warnings before running destructive operations.
4. **Common Errors & Troubleshooting**: Catalog error messages, exit codes, and precise fixes.

### 5. Validate the Skill
Test invoking the target CLI via the newly authored skill scripts and ensure non-interactive execution succeeds cleanly.
