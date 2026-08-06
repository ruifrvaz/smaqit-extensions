# Isolate Task State to Main Worktree

**Status:** In Progress
**Created:** 2026-08-06
**Mode:** Assisted
**Started:** 2026-08-06

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
**Triaged:** 2026-08-06
**Tools searched:** Git
**Result:** Clear

### Blocking Issues
None.

### Advisory Issues
None.

### Historical (Closed)
None.

### Unresolvable Tools
None.

Note: `git/git`'s GitHub mirror carries only mailing-list-driven development PRs (labels like `next`/`seen`/`new user`), not a conventional bug tracker — no `bug`/`regression`-labeled issues exist there at all. Searches for `sparse-checkout` and `worktree` returned only internal Git codebase PRs, none describing a defect or limitation in `sparse-checkout --no-cone` exclusion or `worktree list --porcelain` parsing, the two Git mechanisms this task depends on.

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
| `skills/smaqit.utils.worktree/scripts/9_resolve_task_lifecycle.sh` | Modify — primary-only search, branch→worktree mapping via recomputed `task_branch_name()`, hardened child scan |
| `skills/smaqit.utils.worktree/SKILL.md` | Modify — sparse-layout note and Gotcha #11 now list `.smaqit/tasks/`; version bump `1.1.0` → `1.2.0` |
| `skills/smaqit.task-start/SKILL.md` | Modify — task-awareness check (5a), primary-only writes + commit, corrected owner/child worktree language; version bump `0.9.0` → `0.10.0` |
| `skills/smaqit.task-complete/SKILL.md` | Modify — child writes to primary + commits and stops; owner reordered to merge-then-write-then-commit; new task-awareness verification step; version bump `0.9.0` → `0.10.0` |
| `skills/smaqit.task-create/SKILL.md` | Modify (discovered during implementation, not in original plan) — child task file/PLANNING.md write target moved from the parent's worktree to primary, which is where it actually breaks once `.smaqit/tasks/` is excluded; version bump `0.6.0` → `0.7.0` |
| `skills/smaqit.task-list/SKILL.md` | Modify (discovered during implementation, not in original plan) — PLANNING.md read target moved from "current worktree" (no fallback, hard break) to primary; version bump `0.3.0` → `0.4.0` |
| `tests/skills/test-parent-task-lifecycle.sh` | Modify — all task-state mutations redirected to primary; dropped now-invalid parent-worktree commit; added `.smaqit/tasks` absence assertion; replaced the delete-before-complete workaround with real coverage of the skip-not-abort behavior (invalid Parent + non-NNN filename), using a new `bad_prefix_task.md` fixture file |

## Notes

- Existing task worktrees with stale `.smaqit/tasks/` copies are harmless — the resolver reads from main regardless.
- The task-awareness principle is a lightweight layer: two informational checks, no new mechanisms.
- **Scope correction during implementation:** the assumption that "`task-create` already writes to the primary checkout and needs no changes" was wrong for child tasks — `task-create/SKILL.md` explicitly wrote child task files into the parent's worktree. Confirmed with the user before fixing (see session transcript); `task-list/SKILL.md`'s explicit "current worktree" read (no fallback) was found and fixed in the same pass, same root cause. Other PLANNING.md readers (`session-start`, `session-finish`, `task-refresh`, `project-diagnose`) already document graceful "skip silently"/"treat as missing" fallbacks and were left untouched — they degrade rather than break.
- The branch→worktree mapping in `find_active_task()` now recomputes the branch name from the task file's own title via the existing `task_branch_name()` helper (same slug logic used when the branch was first created), rather than storing a new metadata field. Editing an in-progress task's title after its branch exists would break resolution — a pre-existing property of branch naming in this codebase, not a new risk, but worth remembering.
- `git status --short -- .smaqit/tasks/` on primary should normally be clean between task-start/task-complete invocations, since both now commit their own task-state writes immediately; the task-awareness check treats leftover uncommitted changes there as a signal of an interrupted prior run.
