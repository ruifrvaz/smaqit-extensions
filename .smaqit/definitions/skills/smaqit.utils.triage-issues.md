# Skill Definition: smaqit.utils.triage-issues

## Name

`smaqit.utils.triage-issues`

## Description

Pre-implementation gate that searches upstream GitHub repositories for open bugs and regressions relevant to a task. Resolves tool names to `owner/repo` pairs from GitHub URLs in the project research map, falling back to the GitHub REST API via `curl`. Classifies results as Blocking (halts `smaqit.task-start` and requires user direction), Advisory (surfaced but non-blocking), Historical (closed issues with workarounds), or Clear.

Invoked automatically as step 2a of `smaqit.task-start` (after the research map is verified, before mode determination). May also be invoked standalone: `task.triage [id]`.

## Invocation Triggers

- Automatically by `smaqit.task-start` as step 2a (after research map verified)
- User explicitly invokes `task.triage [id]`

## Input

- Task file (`.smaqit/tasks/NNN_*.md`) — description, acceptance criteria, notes
- Research map at `.smaqit/references/project-research.md` — persistent project-level documentation URL map; if present, provides both GitHub repo URLs for resolution and documentation context for categorization
- GitHub REST API (`https://api.github.com/search/repositories`, `https://api.github.com/search/issues`) via `curl` — fallback repo resolution and issue search for tools not matched to a GitHub URL in the research map

## Steps

1. **Read task file** — load the full task file to extract tools, platforms, and keywords.

2. **Check `triage: skip`** — if the task Notes section contains `triage: skip`, log a note ("Triage skipped — explicitly marked in task Notes") and exit cleanly. Used to prevent circular triage on tasks that exist to track a known issue.

3. **Extract tool/component names** — from the task file's description, acceptance criteria, and notes. Tools are anything that is a third-party dependency: a named product, library, platform, or service. Internal project names (daisy-tribe infrastructure, smaqit framework itself) are excluded.

4. **Check for third-party tools** — if none are identified, log a note ("No third-party tools identified — triage not applicable") and exit cleanly.

5. **Resolve repos** — read `.smaqit/references/project-research.md` if it exists and parse `owner/repo` from any `https://github.com/owner/repo` URLs associated with each extracted tool. For tools with no matching GitHub URL, query the GitHub REST API:

   ```bash
   curl -s "https://api.github.com/search/repositories?q=<tool-name>&per_page=1" \
     -H "Accept: application/vnd.github+json"
   ```

   Use the top result's `full_name` field as `owner/repo`. If the REST API returns no results for a tool, log it as unresolvable (do not error; continue with resolved tools). If `project-research.md` is absent, continue and resolve all tools via the REST API fallback.

6. **Read research map** — load `.smaqit/references/project-research.md`, reusing the contents from step 5 if already loaded. The `Tool | Section | URL | Status` table is used in step 8 to assess whether matched issues describe documented expected behavior (known limitation) vs. a regression.

7. **Search GitHub issues** — for each resolved `owner/repo`, run:

   ```bash
   curl -s "https://api.github.com/search/issues?q=repo:<owner/repo>+<platform>+<feature>+state:open&per_page=20" \
     -H "Accept: application/vnd.github+json"
   ```

   Run a second search with `state:closed` to capture historical issues with workarounds.

   Parse `number`, `title`, `labels[].name`, `html_url`, and `created_at` from the JSON response items.

   If `curl` returns a non-2xx HTTP status or an API error body for a repo, log the error for that repo and continue with the remaining repos.

   Cache results within the session: do not repeat the same `owner/repo + query` combination.

8. **Categorize results** — for each matched issue:
   - **Blocking** — open, labeled `bug` or `regression`, matches both platform AND feature keyword from the task
   - **Advisory** — open, not labeled bug/regression, OR matches only platform OR feature (not both)
   - **Historical** — closed, any match; extract any workaround note from the issue title if present
   - **None** — no matching issues found

9. **Write triage output** to the task file under `## Known Issues Triage`:
    ```markdown
    ## Known Issues Triage
    **Triaged:** YYYY-MM-DD
    **Tools searched:** [list]
    **Result:** Blocking | Advisory | Historical | Clear

    ### Blocking Issues
    - [#NNN title](url) — `owner/repo` — opened YYYY-MM-DD — labels

    ### Advisory Issues
    - ...

    ### Historical (Closed)
    - ...

    ### Unresolvable Tools
    - tool-name — not resolved from research map or GitHub REST API
    ```

10. **Gate decision**:
    - **Blocking** → STOP. Present findings. Do NOT set task status to In Progress. Ask user: proceed anyway, reframe task scope, or mark task as Blocked with reference to the upstream issue.
    - **Advisory only** → Present findings, then continue. No user approval required.
    - **Historical / Clear** → Continue silently. Triage block still written.

## Output

- `## Known Issues Triage` block written to the task file
- In-context summary of triage result when blocking or advisory issues are found
- Gate: halts `smaqit.task-start` if blocking issues are found

## Scope

- Resolves tool `owner/repo` pairs from GitHub URLs in `.smaqit/references/project-research.md`; falls back to GitHub REST API search for tools not found there. Does not search repos outside of tools identified from the task.
- Does not modify task status — status update remains in `smaqit.task-start` step 4
- Does not modify PLANNING.md
- Session-scoped caching only — results are not persisted across sessions

## Completion Criteria

- [ ] `skills/smaqit.utils.triage-issues/SKILL.md` exists with correct frontmatter: `name`, `description`, `metadata.version: "1.4.0"`
- [ ] Skill respects `triage: skip` — exits cleanly with log note
- [ ] Skill exits cleanly when no third-party tools are identified
- [ ] Skill resolves tool names from GitHub URLs in `project-research.md`, falling back to GitHub REST API (`/search/repositories`) for unmatched tools
- [ ] Skill reads research map from `.smaqit/references/project-research.md`
- [ ] Skill searches GitHub issues via GitHub REST API (`/search/issues`) using platform + feature query combination
- [ ] Triage output written to task file under `## Known Issues Triage` in specified format
- [ ] **Blocking issues halt execution** — task status NOT set to In Progress; user prompted for direction
- [ ] Advisory issues surfaced but do not halt execution
- [ ] Historical closed issues recorded without halting
- [ ] `make sync` run; `.github/skills/smaqit.utils.triage-issues/` populated and matches source

## Failure Handling

| Situation | Action |
|-----------|--------|
| `triage: skip` in task Notes | Exit cleanly with log note; do not search |
| No third-party tools identified | Exit cleanly with log note; do not search |
| `project-research.md` absent | Continue without research map context; resolve all tools via GitHub REST API search |
| REST API repo search returns no results for a tool | Record tool as unresolvable in triage output; continue |
| REST API issue search returns non-2xx or error body | Log error for that repo; continue with remaining repos |
| Task file not found | Report error; stop |
| Research map unavailable for categorization | Continue without research map context; note absence in triage output header |

## Spec Notes

- **Naming convention:** `smaqit.utils.*` — consistent with `smaqit.utils.read-pdf`
- **No `compatibility` field:** No external CLI dependency — `curl` is universally available on Linux/macOS/CI
- **`allowed-tools`:** `Bash run_in_terminal read_file` — uses `curl` for GitHub REST API calls and file reading
- **No bundled script:** This skill issues `curl` commands directly via terminal — no helper script required
- **Rate limiting:** GitHub REST API unauthenticated limit: 60 req/hr. Cache `owner/repo + query` results within session to stay within limits
