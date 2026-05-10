# Skill Definition: smaqit.utils.triage-issues

## Name

`smaqit.utils.triage-issues`

## Description

Pre-implementation gate that searches upstream GitHub repositories for open bugs and regressions relevant to a task. Resolves tool names to `owner/repo` pairs from GitHub URLs in the project research map, with `gh search repos` as fallback. Classifies results as Blocking (halts `smaqit.task-start` and requires user direction), Advisory (surfaced but non-blocking), Historical (closed issues with workarounds), or Clear.

Invoked automatically as step 2a of `smaqit.task-start` (after the research map is verified, before mode determination). May also be invoked standalone: `task.triage [id]`.

## Invocation Triggers

- Automatically by `smaqit.task-start` as step 2a (after research map verified)
- User explicitly invokes `task.triage [id]`

## Input

- Task file (`.smaqit/tasks/NNN_*.md`) — description, acceptance criteria, notes
- Research map at `.smaqit/references/project-research.md` — persistent project-level documentation URL map; if present, provides both GitHub repo URLs for resolution and documentation context for categorization
- `gh search repos <tool-name> --limit 1 --json fullName` — fallback repo resolution for tools not matched to a GitHub URL in the research map

## Steps

1. **Read task file** — load the full task file to extract tools, platforms, and keywords.

2. **Check `triage: skip`** — if the task Notes section contains `triage: skip`, log a note ("Triage skipped — explicitly marked in task Notes") and exit cleanly. Used to prevent circular triage on tasks that exist to track a known issue.

3. **Extract tool/component names** — from the task file's description, acceptance criteria, and notes. Tools are anything that is a third-party dependency: a named product, library, platform, or service. Internal project names (daisy-tribe infrastructure, smaqit framework itself) are excluded.

4. **Check for third-party tools** — if none are identified, log a note ("No third-party tools identified — triage not applicable") and exit cleanly.

5. **Resolve repos** — read `.smaqit/references/project-research.md` if it exists and parse `owner/repo` from any `https://github.com/owner/repo` URLs associated with each extracted tool. For tools with no matching GitHub URL, run `gh search repos "<tool-name>" --limit 1 --json fullName` and use the top result. If both methods fail for a tool, log it as unresolvable (do not error; continue with resolved tools). If `project-research.md` is absent, continue and resolve all tools via the `gh search repos` fallback.

6. **Read research map** — load `.smaqit/references/project-research.md`, reusing the contents from step 5 if already loaded. The `Tool | Section | URL | Status` table is used in step 8 to assess whether matched issues describe documented expected behavior (known limitation) vs. a regression.

7. **Check `gh` availability** — run `which gh`. If absent, log a warning ("gh CLI not available — triage skipped") and exit cleanly.

8. **Search GitHub issues** — for each resolved `owner/repo`, run:
   ```bash
   gh issue list --repo owner/repo --state open \
     --search "query" \
     --json number,title,labels,url,createdAt
   ```
   Query combines: platform identifier (e.g., `DGX Spark`, `WSL2`, `Ubuntu 24.04`) and feature/integration keyword (e.g., `Discord`, `vLLM`, `inference`) extracted from the task. Use label filters `bug,regression,platform` where possible.
   
   Run a second search with `--state closed` to capture historical issues with workarounds.
   
   Cache results within the session: do not repeat the same `owner/repo + query` combination.

9. **Categorize results** — for each matched issue:
   - **Blocking** — open, labeled `bug` or `regression`, matches both platform AND feature keyword from the task
   - **Advisory** — open, not labeled bug/regression, OR matches only platform OR feature (not both)
   - **Historical** — closed, any match; extract any workaround note from the issue title if present
   - **None** — no matching issues found

10. **Write triage output** to the task file under `## Known Issues Triage`:
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
    - tool-name — not resolved from research map or `gh search repos`
    ```

11. **Gate decision**:
    - **Blocking** → STOP. Present findings. Do NOT set task status to In Progress. Ask user: proceed anyway, reframe task scope, or mark task as Blocked with reference to the upstream issue.
    - **Advisory only** → Present findings, then continue. No user approval required.
    - **Historical / Clear** → Continue silently. Triage block still written.

## Output

- `## Known Issues Triage` block written to the task file
- In-context summary of triage result when blocking or advisory issues are found
- Gate: halts `smaqit.task-start` if blocking issues are found

## Scope

- Resolves tool `owner/repo` pairs from GitHub URLs in `.smaqit/references/project-research.md`; falls back to `gh search repos` for tools not found there. Does not search repos outside of tools identified from the task.
- Does not modify task status — status update remains in `smaqit.task-start` step 4
- Does not modify PLANNING.md
- Session-scoped caching only — results are not persisted across sessions

## Completion Criteria

- [ ] `skills/smaqit.utils.triage-issues/SKILL.md` exists with correct frontmatter: `name`, `description`, `compatibility`, `metadata.version: "1.2.0"`
- [ ] Skill respects `triage: skip` — exits cleanly with log note
- [ ] Skill exits cleanly when no third-party tools are identified
- [ ] Skill exits cleanly (with warning) when `gh` CLI is not available
- [ ] Skill resolves tool names from GitHub URLs in `project-research.md`, with `gh search repos` fallback when needed
- [ ] Skill reads research map from `.smaqit/references/project-research.md`
- [ ] Skill searches GitHub issues with `gh issue list` using platform + feature query combination
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
| `gh` CLI not available | Log warning; exit cleanly (do not block task-start) |
| `project-research.md` absent | Continue without research map context; resolve all tools via `gh search repos` fallback |
| `gh search repos` returns no results for a tool | Record as unresolvable in triage output; continue |
| `gh issue list` returns non-zero exit | Log error for that repo; continue with remaining repos |
| Task file not found | Report error; stop |
| Research map unavailable for categorization | Continue without research map context; note absence in triage output header |

## Spec Notes

- **Naming convention:** `smaqit.utils.*` — consistent with `smaqit.utils.read-pdf`
- **`compatibility` field:** Must declare `gh` CLI requirement
- **`allowed-tools`:** `Bash run_in_terminal read_file` — uses terminal (gh CLI) and file reading
- **No bundled script:** Unlike `smaqit.utils.read-pdf`, this skill issues `gh` commands directly via terminal — no helper script required
- **Rate limiting:** GitHub Search API: 30 req/min. Cache results within session to avoid redundant `owner/repo + query` searches
