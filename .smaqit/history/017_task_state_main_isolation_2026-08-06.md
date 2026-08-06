# Task State Main Isolation

**Date:** 2026-08-06
**Session focus:** Assessing and planning the fix for multi-worktree PLANNING.md contention; creating Task 022
**Tasks completed:** None
**Tasks created:** 022 — Isolate Task State to Main Worktree

## Actions Taken

- Started session with `smaqit.session-start`, loading full project context: README, Makefile, PLANNING.md, compendium, and all 16 history entries.
- Presented 4 open tasks with priority assessment: 017 (skill contract repair), 002 (changelog extraction), 007 (MCP server PoC), 010 (marketplace plugin).
- User reported that `task-start` and `task-complete` trip over shared `PLANNING.md` modifications across worktrees, with the agent complaining about Git merge conflicts, cross-worktree scanning of stale task files blocking completion, and unrelated worktree/main edits blocking otherwise clean task branches.
- Conducted thorough assessment: read all 3 skill files (`task-start`, `task-complete`, `worktree`), the resolver script (`9_resolve_task_lifecycle.sh`), the sparse-checkout script (`5_create_worktrees.sh`), and workflow rules (`RULES.md`). Verified empirically that no merge driver exists and only one worktree (main) is active.
- Identified root cause: `PLANNING.md` is duplicated mutable state — both main and task worktrees independently modify it, and the merge step in `task-complete` cannot auto-resolve divergent edits to the same structured table rows.
- Proposed Option A (generated PLANNING.md) initially; user counter-proposed a simpler approach: keep task files and PLANNING.md exclusively on main, never in task worktrees.
- Reassessed the counter-proposal by tracing every code path through the resolver and skill steps. Confirmed it eliminates merge conflicts at the source with fewer changes: 4 files instead of a new script + merge driver + gitattributes.
- User added a bonus requirement: task-awareness checks at start (surface concurrent in-progress tasks and uncommitted main changes) and at complete (verify task finalized on main).
- User corrected the sparse-checkout scope: exclude `!.smaqit/tasks/` only, not `!.smaqit/` — templates, references, and user-testing assets should remain available in task worktrees.
- Planned and created Task 022 with full acceptance criteria, implementation steps, design decisions, and file manifest.

## Problems Solved

- Root cause identified: `PLANNING.md` duplication across worktrees creates merge conflicts because task-start and task-complete both modify it in the task worktree, and the merge step can't auto-resolve divergent table edits.
- Solution designed: exclude `.smaqit/tasks/` from sparse checkout, have task-start/task-complete always operate on main's copy, update resolver to find task files exclusively on main and map branches to worktrees via `git worktree list`.
- Scope correctly constrained: `.smaqit/tasks/` only (not all of `.smaqit/`) to preserve template/reference/definition access in worktrees.

## Decisions Made

- **Main as single source of truth for task state.** Task files and PLANNING.md live only on main. Task worktrees are for code changes only.
- **Exclude `.smaqit/tasks/` only from sparse checkout.** Templates, references, definitions, and user-testing remain in worktrees.
- **Resolver maps branch→worktree from existing `git worktree list` arrays.** No new registry or mechanism.
- **Child-scanning hardened: skip malformed files, don't abort.** Non-`NNN` prefixes or invalid `**Parent:**` produce warnings, not blockers.
- **No merge driver, `.gitattributes`, or new scripts.** Problem eliminated at source by never duplicating task state.
- **Task-awareness checks are informational only.** Start surfaces concurrent work; complete verifies finalization. Neither gates the workflow.

## Files Modified

- `.smaqit/tasks/022_isolate_task_state_to_main_worktree.md` — created new task file with full plan
- `.smaqit/tasks/PLANNING.md` — added Task 022 to Active Tasks table

## Next Steps

1. Start Task 022 to implement the fix: 4 source files + 1 test file, ~25 lines of script changes, 2 skill documentation updates.
2. After completing 022, consider the other open tasks — 017 (skill contract repair) is the most impactful remaining issue from dogfooding.

## Session Metrics

- Tasks created: 1 (022)
- Files read for assessment: 8 (3 skills, 3 scripts, RULES.md, PLANNING.md)
- Design iterations: 2 (generated-PLANNING approach → main-as-source-of-truth approach)
- Scope corrections: 1 (`.smaqit/` → `.smaqit/tasks/`)
