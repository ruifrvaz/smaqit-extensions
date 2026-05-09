# Task Backlog Design and Review

**Date:** 2026-05-09
**Session focus:** Planning and specifying 7 new tasks (005–011), with scripts gap analysis, spec compliance review, and final consistency audit
**Tasks completed:** None (all new tasks are Not Started)
**Tasks referenced:** 003, 004 (moved to Completed retroactively), 005, 006, 007, 008, 009, 010, 011

---

## Actions Taken

- Loaded session context: README, CHANGELOG, PLANNING.md, recent history
- Identified PLANNING.md stale state: Tasks 003 and 004 were marked "Not Started" but had shipped in v0.9.4 and v0.9.5 — moved to Completed
- Ran 7 parallel subagent assessments for proposed new tasks
- Collected all design decisions from user (one pass per task)
- Created 7 task files: 005–011 (all Not Started)
- Updated PLANNING.md with all 7 new tasks and the retroactive completions
- Performed scripts gap analysis: confirmed no missed scripts for 005, 008, 011; Task 006 had a genuine gap → added `scan-metadata.py` spec
- Fetched and reviewed agentskills.io specification (specification, best-practices, using-scripts pages)
- Applied spec corrections to Tasks 005, 006, 008, 011 (progressive disclosure, gotchas, assets/ vs references/)
- Performed final consistency review across all 7 task files → found and fixed 6 issues
- Committed and pushed: commit `b680d69`, 9 files, 1143 insertions

## Problems Solved

- **PLANNING.md staleness:** Tasks 003 (read-pdf) and 004 (project-glossary) were still listed as Not Started months after shipping. Fixed retroactively.
- **assets/ vs references/ confusion:** Task 011 originally placed `TASK_TEMPLATE.md` in `references/` — incorrect per spec (static resource templates belong in `assets/`). Required three separate correction passes to catch all instances in the file.
- **Missing files tables entries:** Tasks 005, 006, 007, 008 all had files mentioned in Notes or Implementation Steps that were absent from the Files to Create/Modify tables. Fixed in final review.
- **scripts gap in Task 006:** `scan-metadata.py` was not proposed initially. Scripts gap analysis identified it as warranted (batch deterministic logic = signal to script). Added full PEP 723 script spec.
- **AC contradiction in Task 008:** AC said "URL patterns documented explicitly in SKILL.md" while Notes said to move them to `references/DOC_PLATFORMS.md`. Corrected AC to align with Notes.
- **Implicit Task 008 → 005 dependency undocumented:** The session-finish step ordering in Task 008 referenced "after compendium update" (Task 005 content) with no note about the dependency. Added explicit dependency note.
- **Linux guard missing from Task 009 steps:** Notes mentioned Linux-only constraint; implementation steps didn't include the `runtime.GOOS` guard. Added to Step 4.

## Decisions Made

| Task | Key Decision |
|------|-------------|
| 005 (compendium) | Auto-approve entries; session-finish scans and writes; session-start loads full compendium; semantic deduplication; storage at `.smaqit/compendium.md`; table format |
| 006 (project-recap) | Scan live project only (no task files, no PLANNING.md); top-level deps only; writes to `.smaqit/project-recap.md`; 7 dashboard sections; `scan-metadata.py` script for frontmatter batch extraction |
| 007 (MCP server) | Single tool `get-task-list` (PoC only); Node.js/TypeScript; local Copilot Desktop only; bundled in Go installer |
| 008 (project-research) | Refresh at session-finish + manual `--refresh`; 7-day staleness threshold; multi-platform via agent knowledge + best-guess URL patterns; no private sources |
| 009 (update command) | Linux only v1; `/proc/self/exe` + `filepath.EvalSymlinks()`; atomic rename with cross-filesystem fallback; auto-init if `.smaqit/` present |
| 010 (marketplace) | Custom registry only (not awesome-copilot); GitHub Copilot only; side-by-side with install.sh; `plugin.json` version auto-synced via release-prepare-files |
| 011 (findings section) | Mandatory (task-complete blocks if empty); four fixed categories always present; `TASK_TEMPLATE.md` in `assets/` (not `references/`); triage block written to task file by task-start |

## Files Modified

| File | Change |
|------|--------|
| `.smaqit/tasks/PLANNING.md` | Tasks 003+004 → Completed; Tasks 005–011 added as Active |
| `.smaqit/tasks/005_create_smaqit_compendium_skill.md` | Created |
| `.smaqit/tasks/006_create_project_recap_skill.md` | Created |
| `.smaqit/tasks/007_create_smaqit_mcp_server.md` | Created |
| `.smaqit/tasks/008_refine_project_research_skill.md` | Created |
| `.smaqit/tasks/009_add_smaqit_update_command.md` | Created |
| `.smaqit/tasks/010_publish_marketplace_plugin.md` | Created |
| `.smaqit/tasks/011_add_task_findings_section.md` | Created |
| `.smaqit/history/006_session_start_enhancement_release_2026-03-26.md` | Added (was untracked) |

## Next Steps

- Start Task 011 first (task workflow foundation — Findings section + TASK_TEMPLATE.md) — recommended first because it establishes the task structure all future tasks follow
- Then Task 005 (compendium) — session-finish integration
- Then Task 008 (project-research refinement) — also session-finish integration; implement after Task 005 to get step ordering correct
- Then Task 006 (project-recap + scan-metadata.py script)
- Then Task 009 (update command — Go binary change)
- Then Task 010 (marketplace — research-heavy)
- Then Task 007 (MCP server — most complex, requires external reference reading first)
- Task 002 (changelog extraction fix) still open from Feb 2026; not addressed this session

## Session Metrics

- **Duration:** ~1 session
- **Tasks completed:** 0
- **Task files created:** 7 (005–011)
- **Files modified:** 9 (committed)
- **Insertions:** 1143 lines
- **Issues found and fixed in final review:** 6
- **Spec pages reviewed:** 3 (specification, best-practices, using-scripts)
- **Commit:** `b680d69` on `main`
