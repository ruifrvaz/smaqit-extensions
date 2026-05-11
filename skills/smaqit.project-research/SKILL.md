---
name: smaqit.project-research
description: Builds and maintains a documentation topology map for the current project, identifying the full tech stack and discovering section-level documentation URLs across multiple platforms (GitHub, official docs, ReadTheDocs, pkg.go.dev, npm, PyPI, and more). Writes a persistent map to `.smaqit/references/project-research.md`; adds task-specific annotation when a task is active. Invoke when the user asks to research project dependencies, build or refresh the documentation map, or find documentation for project tools and libraries.
metadata:
  version: "1.3.0"
---

# smaqit.project-research

## Context

Also invoked automatically by:
- `smaqit.task-start` — when `.smaqit/references/project-research.md` is absent
- `smaqit.session-finish` — when the map is older than the staleness threshold (default: 7 days) or when project manifests have changed

## Steps

### Step 0 — Staleness check (always runs first)

Before building or reusing the existing map, determine whether a rebuild is needed:

1. If the `--refresh` flag was passed → **force rebuild**: skip to Step 1 immediately.
2. Check whether `.smaqit/references/project-research.md` exists:
   - **Does not exist** → proceed to Step 1 (build from scratch).
   - **Exists** → read the `**Refreshed:**` date from the map header.
3. Compute the age of the map in days (current date minus `Refreshed:` date).
4. Check whether any project manifest file (`package.json`, `requirements.txt`, `go.mod`, `pyproject.toml`, `*.csproj`, `pom.xml`, `Cargo.toml`, `Gemfile`, `composer.json`, `build.gradle`) has a modification timestamp **newer** than the map's `Refreshed:` date.
5. **Map is stale** if either condition is true:
   - Age ≥ staleness threshold (default **7 days**; override by running `project.research --refresh`)
   - Any manifest file is newer than the map's `Refreshed:` date
6. **Map is current** → report "Research map is current (last updated: YYYY-MM-DD)" and stop. Do not proceed to Step 1.
7. **Map is stale** → proceed to Step 1 (full rebuild).

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

For each tool in the unified list, apply the **platform-aware discovery cascade** below in order. Stop at the first strategy that yields a reachable URL. If all strategies fail, mark the tool as `Unknown` and continue — never omit a tool silently.

**Discovery cascade (apply in this order):**

1. **GitHub** (first): use `github_repo` to find the tool's repository. Use `github_text_search` to locate any associated GitHub Pages docs. Prefer the `docs/` subdirectory or the repository's website URL if set.
2. **Agent knowledge** (second): if you already know the canonical docs URL for this tool (e.g., `docs.docker.com`, `docs.python.org`, `go.dev/doc`, `react.dev`), use it directly without fetching.
3. **Best-guess URL patterns** (third): attempt the following patterns in order, using `fetch_webpage` to check reachability:
   - `https://docs.{tool-name}.io`
   - `https://{tool-name}.readthedocs.io`
   - `https://pkg.go.dev/{module-path}` (for Go modules — use the full module path from `go.mod`)
   - `https://www.npmjs.com/package/{package-name}` (for npm packages — use the exact name from `package.json`)
   - `https://pypi.org/project/{package-name}` (for Python packages — use the exact name from `requirements.txt` or `pyproject.toml`)
4. **GitHub wiki** (last resort): `https://github.com/{owner}/{repo}/wiki`
5. **Unknown**: if no strategy produced a reachable URL, set the tool's URL to `Unknown` in the research map.

Read `references/DOC_PLATFORMS.md` (in the same directory as this SKILL.md) for the full platform-aware URL discovery pattern catalogue, including additional ecosystem-specific patterns and examples.

**Section depth per layer:**

**Project-layer tools:**
- Include 1–2 high-value sections per tool: quickstart, installation, or API overview
- These represent stable, baseline coverage — sections a developer would always want to know

**Task-layer tools (added in Step 2) or project-layer tools flagged as task-relevant:**
- Include up to 3–5 sections per tool, scoped to what the task needs (e.g., prefer `configuration` and `proxy-setup` over `changelog` for a networking task)
- Use `fetch_webpage` to inspect a doc site's structure when the correct section URL is uncertain

Produce a candidate list of `(tool, section-label, url, layer)` entries, where `layer` is `project` or `task`.

### Step 4 — Liveness verification

Write the candidate list to a temporary file with one tab-separated line per entry: `TOOL\tSECTION\tURL\tLAYER`. Determine the skill install directory from the path of this SKILL.md file. Run:

```
<skill-install-dir>/scripts/verify-urls.sh <temp-file>
```

The script outputs one tab-separated line per live URL: `TOOL\tSECTION\tFINAL_URL\tSTATUS_CODE`. Discard any entry where the final status is 4xx or 5xx.

### Step 5 — Write research map

Determine the skill install directory from the path of this SKILL.md file. Load `<skill-install-dir>/references/RESEARCH_MAP.md` to confirm the required output format, column definitions, conditional rules, and rendering rules.

Create `.smaqit/references/` if it does not exist. Write to `.smaqit/references/project-research.md` (overwrite if exists — re-runs are idempotent). The output must match the format defined in RESEARCH_MAP.md:

- **Project table** — all `project`-layer entries; always present
- **Task block** — a second table headed `## Task NNN — [title]` containing only `task`-layer entries; omit entirely if no task is active

Render the same output in-context as part of the response.

## Output

- `.smaqit/references/project-research.md` — persistent project-scoped map; overwritten on each invocation
- In-context table — rendered in the response for immediate use

## Scope

- Does not read documentation content — URL discovery and liveness verification only
- Does not maintain a static registry — mapping is derived fresh from agent knowledge and live web fetch
- Does not create or modify task files, update `PLANNING.md`, or change task status
- One map file per project — not per-task

## Completion

- [ ] Staleness check was performed; map was rebuilt only if stale or absent (Step 0)
- [ ] Project manifests, copilot instructions, and session context were all consulted (Step 1)
- [ ] Task file was read if a task was specified or active (Step 2)
- [ ] Every tool has at least one candidate URL or is marked Unknown (Step 3)
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
| Tool not recognised (no knowledge of its docs) | Mark `URL: Unknown`; attempt all platform cascade strategies before giving up |
| All cascade strategies fail for a tool | Mark `URL: Unknown`; continue with remaining tools — do not block execution |
| `.smaqit/references/` does not exist | Create it silently |
| Map file already exists | Overwrite silently — re-runs are idempotent |
| Research refresh invoked from session-finish and skill unavailable | Skip silently; session-finish completes normally — research refresh is best-effort |
