---
name: smaqit.project-recap
description: Generates a live project dashboard from the current codebase state and writes it to `.smaqit/project-recap.md`. Invoke with `project.recap` to generate the dashboard, or `project.recap --refresh` to force re-scan even if the output file already exists.
compatibility: Script-based scanning requires `uv` (https://github.com/astral-sh/uv). If `uv` is unavailable, the agent reads frontmatter files sequentially as a fallback.
metadata:
  version: "0.1.0"
---

# smaqit.project-recap

## Purpose

Generates a dashboard-style snapshot of the project's current state from its live codebase and configuration. The output answers: **"What is this project right now?"** — its architecture, components, dependencies, and active process state.

This is NOT `smaqit.session-recap` (which summarizes what happened in a session). Data sources are live files only: source files, manifests, and frontmatter. Task files, `PLANNING.md`, and session history are explicitly excluded.

## Steps

### Step 1 — Read project manifests

Read the following files (whichever exist):

- `README.md` — project name, description, entry points
- `go.mod` — module name, Go version, top-level `require` lines
- `package.json` — name, version, top-level `dependencies` and `devDependencies`
- `pyproject.toml` or `requirements.txt` — top-level dependencies
- `Cargo.toml` — package name, version, dependencies
- `Makefile` — tool references and build targets
- `.github/copilot-instructions.md` — stack hints, infrastructure context

Extract:
- **Project name** (prefer README heading or manifest `name` field)
- **Version** (from manifest `version` field, or `CHANGELOG.md` `[Unreleased]` heading, or latest release tag)
- **Primary language and runtime**
- **Entry points** (e.g., `installer/main.go`, `install.sh`)
- **Top-level external dependencies** (frameworks, runtimes, tools — no transitive/indirect)

### Step 2 — Scan component frontmatter

Determine the workspace root (directory containing `README.md`). Run:

```
uv run scripts/scan-metadata.py "<workspace-root>"
```

The script path resolves relative to the directory containing this SKILL.md file (the skill install directory).

Capture stdout (newline-delimited JSON). Each line is one component entry with fields: `type`, `name`, `version`, `description`, `path`.

**Fallback (if `uv` is unavailable):** Read each `agents/*.agent.md` and `skills/*/SKILL.md` file sequentially. Extract the YAML frontmatter block (between `---` delimiters) to obtain `name`, `description`, and `metadata.version` for each file. Construct equivalent component entries manually.

**Gotcha:** `skills/` and `agents/` directories may not exist in all projects. If neither is found, skip this step and omit the Active Skills/Agents section rather than erroring.

### Step 3 — Derive architecture

From manifests, entry points, and directory structure identified in Steps 1–2, construct the top-level architectural flow:
- What are the primary inputs (source directories, config files)?
- What transformation steps exist (build steps, sync operations)?
- What are the distribution outputs (binaries, installed files, synced directories)?

### Step 4 — Build output sections

Read `references/OUTPUT_FORMAT.md` from the skill install directory for section-by-section format templates and Mermaid examples before generating the dashboard.

Build all 7 sections in order:

1. **Project Header** — name, version, language/runtime, entry points
2. **Architecture Overview** — Mermaid `flowchart LR` diagram of top-level flow
3. **Component Map** — Mermaid diagram or table of major components/packages
4. **Dependency Graph** — Mermaid `flowchart LR` of top-level external dependencies
5. **Directory Structure** — curated ASCII tree (2–3 levels, annotated purpose)
6. **Active Skills and Agents** — table derived from Step 2 frontmatter scan
7. **Key Configuration Files** — table of significant config/manifest files found

**Mermaid gotcha:** Keep diagrams to ≤15 nodes. If there are more components, group them by category rather than listing individually. Prefer `flowchart LR` — it renders reliably across GitHub, VS Code, and Copilot clients.

### Step 5 — Assemble and write dashboard

Compose all sections under the standard output header:

```markdown
# Project Recap

> Generated: YYYY-MM-DD HH:MM | Source: live project scan | Run: `project.recap`

---
```

Write the assembled dashboard to `.smaqit/project-recap.md` (create if absent; overwrite if `--refresh` was specified or if no prior `project.recap` invocation exists for this session). Create `.smaqit/` if it does not exist.

### Step 6 — Render in chat

Output the full dashboard inline as the primary response. Include a one-line note showing the output file path.

## Output

- `.smaqit/project-recap.md` — persistent project dashboard; overwritten on each invocation
- In-context dashboard — rendered in the response for immediate review

## Scope

**In scope:**
- Live codebase state: source files, manifests, frontmatter
- All 7 dashboard sections, even if some are sparse (prefer "None detected" over omitting a section)

**Out of scope:**
- Task files, `PLANNING.md`, session history — these are explicitly excluded
- LOC counts, language breakdown, or transitive dependency graphs
- Per-component documentation or method-level tracing

## Completion

- [ ] Step 1: Manifests read; project name, version, language, entry points, and dependencies extracted
- [ ] Step 2: `scan-metadata.py` ran (or fallback applied); component list built
- [ ] Step 3: Architectural flow derived from manifests and directory structure
- [ ] Step 4: `references/OUTPUT_FORMAT.md` read; all 7 sections composed using correct templates
- [ ] Step 5: Dashboard written to `.smaqit/project-recap.md`
- [ ] Step 6: Dashboard rendered in chat

## Failure Handling

| Situation | Action |
|-----------|--------|
| `uv` not available | Apply sequential fallback (read frontmatter files one by one); note fallback in dashboard header |
| `skills/` or `agents/` not found | Skip Active Skills/Agents section; note "Not applicable" in that section |
| No manifests found | Build dashboard from directory structure and session context only; note in header |
| Mermaid diagram exceeds 15 nodes | Group nodes by category; reduce to representative top-level labels |
| `.smaqit/` does not exist | Create it silently before writing output |
| Output file exists and `--refresh` not set | Overwrite silently — `project.recap` is always idempotent |
| Section has no data | Include the section heading with "None detected" rather than omitting it |
