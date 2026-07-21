---
name: smaqit.utils.triage-issues
description: Pre-implementation gate that searches upstream GitHub repositories for open bugs and regressions relevant to a task. Resolves tool names to owner/repo pairs from GitHub URLs in the project research map, falling back to the GitHub REST API via curl. Classifies results as Blocking (halts smaqit.task-start and requires user direction), Advisory (surfaced but non-blocking), Historical (closed issues with workarounds), or Clear. Invoked automatically as step 2a of smaqit.task-start; also invokable standalone as `task.triage [id]`.
metadata:
  version: "1.4.0"
---

# Triage Issues

## Steps

### Step 1: Read task file

Read `.smaqit/tasks/NNN_*.md` for the specified task ID. Load the full file — description, acceptance criteria, and notes are all needed.

### Step 2: Check `triage: skip`

If the task's Notes section contains `triage: skip`, log a note:

> Triage skipped — explicitly marked in task Notes.

Exit cleanly. This flag prevents circular triage on tasks that exist to track a known issue.

### Step 3: Extract tool/component names

From the task description, acceptance criteria, and notes, extract the names of all third-party dependencies: named products, libraries, platforms, or services. Exclude:
- Internal project names (e.g., daisy-tribe infrastructure, smaqit framework files)
- Generic terms (e.g., "bash script", "config file", "API endpoint")

If no third-party tools are identified, log:

> No third-party tools identified — triage not applicable.

Exit cleanly.

### Step 4: Resolve repos

Read `.smaqit/references/project-research.md` if it exists. For each extracted tool, first look for any `https://github.com/owner/repo` URL already present in the research map for that tool and parse `owner/repo` from it.

- GitHub URL found in the research map for a tool → add parsed `owner/repo` to the resolved list
- No GitHub URL found for a tool → query the GitHub REST API:

  ```bash
  curl -s "https://api.github.com/search/repositories?q=<tool-name>&per_page=1" \
    -H "Accept: application/vnd.github+json"
  ```

  Use the top result's `full_name` field as `owner/repo`.

- No GitHub URL and the REST API returns no results for a tool → record it as unresolvable (do not error; do not stop)

If `.smaqit/references/project-research.md` is absent, continue without research-map repo resolution and resolve all tools via the GitHub REST API fallback above.

### Step 5: Read research map

Read `.smaqit/references/project-research.md`. Reuse the contents loaded in step 4 if already available. The `Tool | Section | URL` table provides verified documentation URLs. Use this in step 7 to assess whether a matched GitHub issue describes documented expected behavior (known limitation) vs. a regression (unexpected breakage). If the file is absent, continue without it and note absence in the triage output header.

### Step 6: Search GitHub issues

For each resolved `owner/repo`, construct a query combining:
- **Platform identifier** extracted from the task (e.g., `DGX Spark`, `WSL2`, `Ubuntu 24.04`) — omit if none present
- **Feature/integration keyword** extracted from the task (e.g., `Discord`, `vLLM`, `inference`)

Run open issues search:

```bash
curl -s "https://api.github.com/search/issues?q=repo:<owner/repo>+<platform>+<feature>+state:open&per_page=20" \
  -H "Accept: application/vnd.github+json"
```

Run closed issues search (for workarounds):

```bash
curl -s "https://api.github.com/search/issues?q=repo:<owner/repo>+<platform>+<feature>+state:closed&per_page=20" \
  -H "Accept: application/vnd.github+json"
```

Parse `number`, `title`, `labels[].name`, `html_url`, and `created_at` from the JSON response items.

**Caching:** Do not repeat the same `owner/repo + query` combination within a session. If results are already available in context, reuse them.

If `curl` returns a non-2xx HTTP status or an API error body for a repo, log the error for that repo and continue with the remaining repos.

### Step 7: Categorize results

For each matched issue, classify using these rules:

| Category | Criteria |
|----------|----------|
| **Blocking** | Open issue, labeled `bug` or `regression`, matches **both** platform AND feature keyword |
| **Advisory** | Open issue, not labeled bug/regression, OR matches only platform OR feature (not both) |
| **Historical** | Closed issue, any match |
| **Clear** | No matching issues found across all repos |

Cross-reference matched issues against the research map: if the issue describes behavior that is explicitly documented as a known limitation in the official docs, downgrade from Blocking to Advisory.

### Step 8: Write triage output to task file

Determine the skill install directory from the path of this SKILL.md file. Load `<skill-install-dir>/references/TRIAGE_BLOCK.md` to confirm the required output format, field definitions, result values, and section rules.

Append the `## Known Issues Triage` block to the task file (replace if already present). The output must match the format defined in TRIAGE_BLOCK.md.

### Step 9: Gate decision

Based on the overall result:

**Blocking issues found:**

STOP. Do not set task status to In Progress. Present the blocking issues to the user and ask:

> The following blocking issues were found. How would you like to proceed?
> 1. **Proceed anyway** — acknowledge the issue and continue
> 2. **Reframe task scope** — adjust the task to avoid the blocked component
> 3. **Mark as Blocked** — record the upstream issue reference and park the task

Wait for user direction before continuing.

**Advisory issues only:**

Present findings, then continue. No user approval required.

**Historical or Clear:**

Continue silently. Triage block is written but no in-context message is needed.

## Output

- `## Known Issues Triage` block written to the task file
- In-context summary when blocking or advisory issues are found
- Gate: halts `smaqit.task-start` step 2a if blocking issues are found; user decides how to proceed

## Scope

- Resolves tool `owner/repo` pairs from GitHub URLs in `.smaqit/references/project-research.md`; falls back to GitHub REST API search for tools not found there. Does not search repos outside of tools identified from the task.
- Does not set task status — that remains in `smaqit.task-start` step 4
- Does not modify `PLANNING.md`
- Session-scoped result caching only — not persisted across sessions

## Completion Criteria

- [ ] `triage: skip` flag respected — exits cleanly with log note
- [ ] Exits cleanly when no third-party tools identified
- [ ] Tool names resolved from GitHub URLs in `project-research.md`, falling back to GitHub REST API (`/search/repositories`) for unmatched tools
- [ ] Research map read from `.smaqit/references/project-research.md`
- [ ] GitHub issues searched via GitHub REST API (`/search/issues`) using platform + feature query combination
- [ ] Triage output written to task file under `## Known Issues Triage` in the specified format
- [ ] **Blocking issues halt execution** — task status NOT set to In Progress; user prompted for direction
- [ ] Advisory issues surfaced but do not halt execution
- [ ] Historical closed issues recorded without halting

## Failure Handling

| Situation | Action |
|-----------|--------|
| `triage: skip` in task Notes | Exit cleanly with log note; do not search |
| No third-party tools identified | Exit cleanly with log note; do not search |
| `project-research.md` absent | Continue without research map context; resolve all tools via GitHub REST API search |
| REST API repo search returns no results for a tool | Record tool as unresolvable in triage output; continue |
| REST API issue search returns non-2xx or error body | Log error for that repo; continue with remaining repos |
| Task file not found | Report error; stop |
| Research map unavailable for categorization | Continue without research context; note absence in triage output header |
