---
name: smaqit.project-recap
description: Generates a live project dashboard from the current codebase state and writes it to `.smaqit/project-recap.md`. Invoke with `project.recap` to generate the dashboard, or `project.recap --refresh` to force re-scan even if the output file already exists.
compatibility: Script-based scanning requires `uv` (https://github.com/astral-sh/uv). If `uv` is unavailable, the agent reads frontmatter files sequentially as a fallback.
metadata:
  version: "0.3.0"
---

# smaqit.project-recap

## Gotchas

- This skill generates a snapshot of the **live project state** (source files, manifests, frontmatter). It is NOT `smaqit.session-recap`, which summarises what happened in a session. Task files, `PLANNING.md`, and session history are explicitly excluded.

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

### Step 2.5 — Situation Report (git pulse)

Run the following commands from the workspace root to gather recent activity signals:

```
git log --oneline --no-merges -20
git log --oneline --no-merges --since="4 weeks ago" --format="%s"
git diff --stat HEAD~5 HEAD
```

From the output, infer and write narrative prose only:
- **Current state** — 2–4 sentences describing what the project looks like right now (active codebase areas, mature/stable capabilities, recent focus)
- **Direction** — 2–4 sentences describing where the project is heading (patterns from commit messages and changed files)

Do NOT list commits. Do NOT produce a changelog. Synthesize high-signal orientation prose only.

### Step 4 — Derive architecture

From manifests, entry points, and directory structure identified in Steps 1–2.5, construct the top-level architectural flow:
- What are the primary inputs (source directories, config files)?
- What transformation steps exist (build steps, sync operations)?
- What are the distribution outputs (binaries, installed files, synced directories)?

### Step 5 — Build output sections

Read `references/OUTPUT_FORMAT.md` from the skill install directory for section-by-section format templates and Mermaid examples before generating the dashboard.

Build all 8 core sections in order:

0. **Situation Report** — prose-only current state and direction inferred from Step 2.5 git pulse
1. **Project Header** — name, version, language/runtime, entry points
2. **Architecture Overview** — Mermaid `flowchart LR` diagram of top-level flow
3. **Component Map** — Mermaid diagram or table of major components/packages
4. **Dependency Graph** — Mermaid `flowchart LR` of top-level external dependencies
5. **Directory Structure** — curated ASCII tree (2–3 levels, annotated purpose)
6. **Active Skills and Agents** — table derived from Step 2 frontmatter scan
7. **Key Configuration Files** — table of significant config/manifest files found

**Mermaid gotcha:** Keep diagrams to ≤15 nodes. If there are more components, group them by category rather than listing individually. Prefer `flowchart LR` — it renders reliably across GitHub, VS Code, and Copilot clients.

### Step 6 — Assemble and write dashboard

Compose all sections under the standard output header:

```markdown
# Project Recap

> Generated: YYYY-MM-DD HH:MM | Source: live project scan | Run: `project.recap`

---
```

Write the assembled dashboard to `.smaqit/project-recap.md` (create if absent; overwrite if `--refresh` was specified or if no prior `project.recap` invocation exists for this session). Create `.smaqit/` if it does not exist.

### Step 7 — Render in chat

Output the full dashboard inline as the primary response. Include a one-line note showing the output file path.

### Step 8 — Run session.assess for next steps

After the dashboard is written, invoke `smaqit.session-assess` to perform a critical assessment of the full recap output.

Use the assessment findings to populate **Section 8 — Next Steps** in the dashboard with 3–5 concrete, prioritized improvement suggestions. Each suggestion must include a one-line rationale.

## Output

- `.smaqit/project-recap.md` — persistent project dashboard; overwritten on each invocation
- In-context dashboard — rendered in the response for immediate review

## Scope

**In scope:**
- Live codebase state: source files, manifests, frontmatter
- All 8 core dashboard sections, even if some are sparse (prefer "None detected" over omitting a section)
- Section 8 (Next Steps) when `smaqit.session-assess` is available

**Out of scope:**
- Task files, `PLANNING.md`, session history — these are explicitly excluded
- LOC counts, language breakdown, or transitive dependency graphs
- Per-component documentation or method-level tracing

## Completion

- [ ] Step 1: Manifests read; project name, version, language, entry points, and dependencies extracted
- [ ] Step 2: `scan-metadata.py` ran (or fallback applied); component list built
- [ ] Step 2.5: Git pulse ran; current state and direction narrative written
- [ ] Step 4: Architectural flow derived from manifests and directory structure
- [ ] Step 5: `references/OUTPUT_FORMAT.md` read; all 8 core sections composed using correct templates
- [ ] Step 6: Dashboard written to `.smaqit/project-recap.md`
- [ ] Step 7: Dashboard rendered in chat
- [ ] Step 8: session.assess invoked; Next Steps section populated

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
| `.git` not found or no commits | Skip git pulse; write "No git history available" in Situation Report |
| `session.assess` not available | Skip Step 8; omit Section 8 from dashboard; note in header |
