# Isolate Task State to Main Worktree

**Status:** Not Started
**Created:** 2026-08-06

## Description

Task files and PLANNING.md currently duplicated across worktrees cause merge conflicts when multiple task branches modify PLANNING.md independently. The fix is to exclude `.smaqit/tasks/` from task worktree sparse checkouts so task state lives exclusively on main. Update the lifecycle resolver to find task files on main and map branches to worktrees via `git worktree list`. Add task-awareness checks: at start, surface concurrent in-progress tasks and uncommitted main changes; at complete, verify the task is properly finalized on main.

## Design Decisions

- **Exclude `.smaqit/tasks/` only, not all of `.smaqit/`:** Templates, references, definitions, and user-testing assets remain available in task worktrees. Only the conflict-prone task state is excluded.
- **Resolver uses existing `git worktree list` arrays** for branch→worktree mapping rather than maintaining a separate registry.
- **Child-scanning hardened: skip malformed files, don't abort.** Malformed `**Parent:**` values or non-`NNN` filenames produce a warning but don't block owner completion.
- **No merge driver, `.gitattributes`, or new scripts.** The problem is eliminated at the source by never duplicating task state.
- **Task-awareness checks are informational/non-blocking** — they surface state, never gate.

## Implementation Steps

1. Add `'!.smaqit/tasks/'` to sparse-checkout exclusion list in `5_create_worktrees.sh`
2. Rewrite `find_active_task` in resolver to search primary worktree only; map branch→worktree via existing `worktree_paths[]`/`worktree_branches[]` arrays
3. Update resolver child-scanning loop to read from `$primary_root/.smaqit/tasks/*.md`, skip malformed files (non-`NNN` prefix, invalid `**Parent:**`) instead of `exit 1`
4. Add task-awareness check to `task-start/SKILL.md` between steps 5 and 6: scan for concurrent in-progress tasks and uncommitted task-state changes on main (informational, non-blocking)
5. Update `task-start/SKILL.md` steps 6 & 8 to clarify "update on the primary checkout (main)"; bump version `0.9.0` → `0.10.0`
6. Add task-awareness verification to `task-complete/SKILL.md` after step 13: verify task file on main shows Completed, change is committed, PLANNING.md reflects the move
7. Update `task-complete/SKILL.md` steps 8–9 & 11 to reorder merge-before-write for PLANNING.md and task file; bump version `0.9.0` → `0.10.0`
8. Update `test-parent-task-lifecycle.sh` fixture if needed for main-only task file location
9. Run `make test`, `make sync`, `make smoke-test`

## Known Issues Triage

[Populated by smaqit.task-start via smaqit.utils.triage-issues. Do not edit manually.]

## Acceptance Criteria

- [ ] `.smaqit/tasks/` excluded from task worktree sparse checkout
- [ ] `task-start` updates task file status and PLANNING.md on main only
- [ ] `task-start` surfaces concurrent in-progress tasks and uncommitted task-state changes on main (informational, non-blocking)
- [ ] `task-complete` merges code first, then updates task file and PLANNING.md on main
- [ ] `task-complete` verifies task is finalized on main post-completion (status=Completed, committed, PLANNING.md updated)
- [ ] Resolver finds task files exclusively on main; maps branch→worktree from `git worktree list`
- [ ] Child-scanning loop skips malformed files instead of aborting
- [ ] Owner task merge never conflicts on PLANNING.md or task files
- [ ] `make test` and `make smoke-test` pass

## Findings

[Populated by smaqit.task-complete. Do not fill in manually before task is complete.]

**Implementation approach:**
- TBD

**Decisions made:**
- TBD

**Blockers encountered:**
- TBD

**Follow-up identified:**
- TBD

## Files to Create / Modify

| File | Action |
|------|--------|
| `skills/smaqit.utils.worktree/scripts/5_create_worktrees.sh` | Modify — add `'!.smaqit/tasks/'` to sparse-checkout |
| `skills/smaqit.utils.worktree/scripts/9_resolve_task_lifecycle.sh` | Modify — primary-only search, branch→worktree mapping, hardened child scan |
| `skills/smaqit.task-start/SKILL.md` | Modify — task-awareness check, main-only writes, version bump |
| `skills/smaqit.task-complete/SKILL.md` | Modify — task-awareness verification, reorder merge-before-write, version bump |
| `tests/skills/test-parent-task-lifecycle.sh` | Modify — fixture adjustments if needed |

## Notes

- Existing task worktrees with stale `.smaqit/tasks/` copies are harmless — the resolver reads from main regardless.
- `task-create` already writes to the primary checkout and needs no changes.
- The task-awareness principle is a lightweight layer: two informational checks, no new mechanisms.
