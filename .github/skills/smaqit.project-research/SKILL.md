---
name: smaqit.project-research
description: Builds and maintains a documentation topology map for the current project. Identifies the full tech stack from project manifests and session context, discovers section-level documentation URLs using agent knowledge and web fetch tools, verifies each URL is reachable, and writes a persistent map to `.smaqit/references/project-research.md`. If a task is active or specified, adds a task layer that annotates which sections are directly relevant to that task. Invoke explicitly with `project.research` or `project.research [task-id]`, or automatically from `smaqit.task-start` when the research map is absent.
metadata:
  version: "1.0.0"
---

# smaqit.project-research

## Purpose

Maintains a persistent, project-scoped documentation map. The map covers the entire tech stack the project is built on — not just what a single task touches. A task, when specified, adds a focused annotation layer on top of the baseline without replacing it.

This separation ensures:
- The map is always current and project-complete, regardless of which task is active
- Implementing agents always have access to documentation topology before touching code
- The map is built once and reused; it is only refreshed explicitly or when absent at task-start

## Invocation

```
project.research              # Full project map, no task layer
project.research [task-id]    # Full project map + task annotation layer
```

Also invoked automatically by `smaqit.task-start` when `.smaqit/references/project-research.md` is absent.

## Steps

### Step 1 — Project stack extraction (always runs)

Read the following sources to build a flat, deduplicated list of third-party tools and technologies:

1. **Project manifests** — scan the project root for any of: `package.json`, `requirements.txt`, `go.mod`, `pyproject.toml`, `*.csproj`, `pom.xml`, `Cargo.toml`, `Gemfile`, `composer.json`, `build.gradle`. Read whichever exist. Extract named dependencies plus the runtime and framework (e.g., Node.js, Python, .NET, Go).
2. **Copilot instructions** — read `.github/copilot-instructions.md` if present. Extract any tools, services, or platforms described as part of the project's infrastructure or stack.
3. **Session context** — extract tools, platforms, or services mentioned in the current conversation.

Exclude internal project names and the smaqit framework itself. Produce a deduplicated, flat tool list. This is the **project layer** — it is always complete regardless of whether a task is active.

### Step 2 — Task layer extraction (runs only if a task is specified or active)

If a task ID was provided, or if there is a currently active task in `.smaqit/tasks/PLANNING.md`:

- Read the task file (`.smaqit/tasks/NNN_*.md`)
- Extract any tools, services, platforms, or libraries named in the description, acceptance criteria, or notes that are not already in the project layer
- Add these to the tool list, tagged as task-layer additions
- Record which tools from the project layer are directly implicated by the task (for annotation in Step 4)

If no task is specified and no task is active, skip this step entirely.

### Step 3 — URL discovery

For each tool in the unified list, use your knowledge plus `fetch_webpage`, `github_repo`, and `github_text_search` to identify section-level documentation URLs:

**Project-layer tools:**
- Include 1–2 high-value sections per tool: quickstart, installation, or API overview
- These represent stable, baseline coverage — sections a developer would always want to know

**Task-layer tools (added in Step 2) or project-layer tools flagged as task-relevant:**
- Include up to 3–5 sections per tool, scoped to what the task needs (e.g., prefer `configuration` and `proxy-setup` over `changelog` for a networking task)
- Use `fetch_webpage` to inspect a doc site's structure when the correct section URL is uncertain
- Use `github_repo` or `github_text_search` for tools whose primary documentation lives in their GitHub repo

Produce a candidate list of `(tool, section-label, url, task-relevant)` entries.

### Step 4 — Liveness verification

Write the candidate list to a temporary file with one tab-separated line per entry: `TOOL\tSECTION\tURL`. Determine the skill install directory from the path of this SKILL.md file. Run:

```
<skill-install-dir>/scripts/verify-urls.sh <temp-file>
```

The script outputs one tab-separated line per live URL: `TOOL\tSECTION\tFINAL_URL\tSTATUS_CODE`. Discard any entry where the final status is 4xx or 5xx.

### Step 5 — Write research map

Create `.smaqit/references/` if it does not exist. Write to `.smaqit/references/project-research.md` (overwrite if exists — re-runs are idempotent):

```markdown
# Project Research Map
**Project:** [project name from README or directory name]
**Refreshed:** YYYY-MM-DD
**Active task:** NNN — [task title]  ← omit this line if no task was specified or active

| Tool | Section | URL | Status | Task-relevant |
|------|---------|-----|--------|---------------|
| vllm | Installation | https://docs.vllm.ai/en/latest/getting_started/installation.html | 200 | ✓ |
| vllm | Configuration | https://docs.vllm.ai/en/latest/serving/openai_compatible_server.html | 200 | ✓ |
| ollama | API reference | https://github.com/ollama/ollama/blob/main/docs/api.md | 200 | — |
| nginx | Reverse proxy | https://nginx.org/en/docs/http/ngx_http_proxy_module.html | 200 | — |
```

- `Task-relevant` is `✓` if the section was flagged as directly implicated by the active task; `—` otherwise
- If no task was specified or active, omit the `Task-relevant` column entirely
- Include every tool from Steps 1–2. For tools with no live URLs: `Status: unreachable`, no URL. For unknown tools: `Status: unknown`

Render the same table in-context as part of the response.

## Output

- `.smaqit/references/project-research.md` — persistent project-scoped map; overwritten on each invocation
- In-context table — rendered in the response for immediate use

## Scope

- Does not read documentation content — URL discovery and liveness verification only
- Does not maintain a static registry — mapping is derived fresh from agent knowledge and live web fetch
- Does not create or modify task files, update `PLANNING.md`, or change task status
- One map file per project — not per-task

## Completion

- [ ] Project manifests, copilot instructions, and session context were all consulted (Step 1)
- [ ] Task file was read if a task was specified or active (Step 2)
- [ ] Every tool has at least one candidate URL (Step 3)
- [ ] `verify-urls.sh` ran without error (Step 4)
- [ ] `.smaqit/references/project-research.md` exists, matches the output format, and was overwritten if it previously existed (Step 5)
- [ ] Map was rendered in-context

## Failure Handling

| Situation | Action |
|-----------|--------|
| No project manifests found | Continue using copilot instructions and session context only; note in map header |
| Task ID specified but file not found | Log a warning in map header; continue with project layer only |
| `curl` not available | Report and stop; do not write a partial map |
| `verify-urls.sh` not found at expected path | Report path resolution failure; surface the skill install location and stop |
| All URLs for a tool are unreachable | Include the tool with `Status: unreachable`; do not omit silently |
| Tool not recognised (no knowledge of its docs) | Mark `Status: unknown`; attempt `fetch_webpage` on a best-guess URL before giving up |
| `.smaqit/references/` does not exist | Create it silently |
| Map file already exists | Overwrite silently — re-runs are idempotent |
