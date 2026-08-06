# Task State Isolation Delivery

**Date:** 2026-08-06
**Session focus:** Implementing, refining, completing, and release-verifying Task 022 (isolate task state to main worktree); two unrelated bonus fixes surfaced and resolved along the way
**Tasks completed:** 022 — Isolate Task State to Main Worktree
**Tasks referenced:** 017, 002, 007, 010 (remaining open tasks, untouched this session)

## Actions Taken

- Diagnosed why "new session" didn't auto-trigger `smaqit.session-start`: its description lacked the quoted trigger phrases every sibling skill uses. Fixed across canonical source and all mirrors, ran `smaqit.session-start` properly to load full project context.
- Planned Task 022 via `smaqit.task-plan`: discovery surfaced a blocking gap the task file didn't resolve — how the resolver would map an in-progress task to its owning branch/worktree once no worktree keeps its own copy of the task file to find. Resolved via user decision: recompute the branch name from the task's own title (reusing the existing `task_branch_name()` helper) rather than storing a new metadata field.
- Started Task 022 (`task-start`), created branch/worktree/workspace, ran issue triage (Clear — no relevant upstream Git issues).
- Implemented the core design: excluded `.smaqit/tasks/` from task-worktree sparse checkout; rewrote the resolver's `find_active_task()` to search primary only; hardened the child-scan loop to warn-and-skip malformed files instead of aborting; moved `task-start`/`task-complete` writes to primary with new non-blocking task-awareness checks; reordered owner completion to merge-before-write.
- Mid-implementation, discovered `task-create` and `task-list` shared the same "task state lives in the current/parent worktree" assumption and would have broken silently — confirmed scope expansion with the user before fixing both.
- Rewrote `test-parent-task-lifecycle.sh` for primary-only task state, adding real coverage for the skip-not-abort behavior that previously had none. Installed `ripgrep` locally (missing from this dev environment) to actually run and verify the suite rather than guess.
- Committed the initial implementation to the task branch and stopped for Assisted-mode review, per workflow.
- Answered follow-up questions on worktree/branch mechanics (how an agent addresses primary from within a task worktree; confirmed children have never had their own Git resources, before or after this task).
- **Bonus fix 1:** user flagged that committing implementation before their approval defeats Assisted-mode review. Refined `task-start`/`task-complete` so implementation commits are deferred to `task-complete` (right before the merge for an owner, right before the child's own status commit for a child) — the only point in the lifecycle implementation now gets committed.
- **Bonus fix 2:** user flagged a redundant double-approval between `task-plan` and `task-create`. Assessed and confirmed the redundancy was entirely inside `task-plan` Mode A (plan approval, then a near-identical re-confirmation of derived fields). Merged both into a single approval gate; unrelated to Task 022, fixed directly on primary.
- Committed both pending refinements on user approval. While invoking `task-complete` for 022, discovered `.claude/skills/` had drifted from canonical across **7 skills** (one full version behind each, plus a completely missing resolver script) — `make sync` never covers `.claude/`, so this went undetected across multiple prior tasks. Fixed all 7 as a separate commit before proceeding, to avoid completing Task 022 with stale instructions.
- Completed Task 022 properly with corrected instructions: findings written, all 9 acceptance criteria verified and checked off, merged cleanly into `main`, worktree removed, branch deleted, workspace rebuilt. Re-synced `.claude/`/`.github/`/`.agents/` mirrors again post-merge (same gap would have reopened otherwise) and re-ran `make test`/`make smoke-test` (pass).
- Clarified for the user that the `.claude/` drift never affected the actual release/installer output — the Go binary always embeds content compiled fresh from canonical `skills/`/`agents/` at build time, confirmed by `make smoke-test`'s "matches generated staging artifacts" checks passing throughout the drift period.
- After release v1.12.0 was published, ran a full end-to-end verification: installed the real GitHub release (not a local build) into a fresh `~/projects/temp` project, confirmed version parity across all three platforms, verified specific content markers from every change this session made, and ran a functional test (created a task, branched, built a worktree) proving `.smaqit/tasks/` is genuinely absent from the linked worktree while `.smaqit/templates/` remains, and the resolver correctly resolves to primary's copy.

## Problems Solved

- Root design problem (from prior session 017): `PLANNING.md`/task-file duplication across worktrees caused merge conflicts. Eliminated at the source by excluding `.smaqit/tasks/` from worktree checkout entirely.
- Branch↔worktree ownership mapping had no mechanism once file-presence lookup was removed — solved by recomputing the branch name from the task's title.
- `task-create` and `task-list` would have silently broken on the very next child-task creation or `task-list` invocation from inside a worktree — caught and fixed before merge.
- Premature implementation commits made Assisted-mode review harder — fixed by deferring commits to `task-complete`.
- Redundant approval round-trip in `task-plan` Mode A — collapsed to one gate.
- `.claude/skills/` silently serving stale instructions (7 skills, one missing a script entirely) — could have caused an incorrect task completion; caught, fixed, and verified not to have affected any shipped release.

## Decisions Made

- **Branch ownership resolved by recomputing from the task's title**, not a stored field — no schema change, no migration, reuses existing code.
- **Merge-before-write applies only to the owner completion path** — children never merge, so their writes always go straight to primary.
- **Implementation commits deferred to `task-complete`** — the only point in the lifecycle a task branch ever gets a commit.
- **Task-plan Mode A asks for approval exactly once** — the plan and derived task-create fields are shown together.
- **`.claude/skills/` drift fixed by direct resync, not by changing `make sync`'s scope** — flagged as a follow-up worth a structural fix (CI check or Makefile extension), not resolved definitively this session.

## Files Modified

- `skills/smaqit.utils.worktree/scripts/5_create_worktrees.sh` — sparse-checkout exclusion for `.smaqit/tasks/`
- `skills/smaqit.utils.worktree/scripts/9_resolve_task_lifecycle.sh` — primary-only resolution, recomputed branch mapping, hardened child-scan
- `skills/smaqit.utils.worktree/SKILL.md` — documentation for the new exclusion
- `skills/smaqit.task-start/SKILL.md` — task-awareness check, primary-only writes, deferred-commit policy (0.9.0 → 0.10.1)
- `skills/smaqit.task-complete/SKILL.md` — merge-before-write reorder, task-awareness verification, commit-then-merge (0.9.0 → 0.10.1)
- `skills/smaqit.task-create/SKILL.md` — child writes moved to primary (0.6.0 → 0.7.0)
- `skills/smaqit.task-list/SKILL.md` — reads moved to primary (0.3.0 → 0.4.0)
- `skills/smaqit.task-plan/SKILL.md` — collapsed double-approval in Mode A (1.1.0 → 1.2.0)
- `tests/skills/test-parent-task-lifecycle.sh` — rewritten fixture, new skip-not-abort coverage
- `.smaqit/tasks/022_isolate_task_state_to_main_worktree.md` — findings, acceptance criteria, completion
- `.smaqit/tasks/PLANNING.md` — task 022 moved to Completed
- `.claude/skills/` (7 skills) — resynced from stale to canonical, twice (once for pre-existing drift, once post-merge)
- `smaqit-extensions.code-workspace` — worktree registration and cleanup

## Next Steps

1. Task 017 (Repair Skill Contract and Scope Inconsistencies) is the next most impactful open item from dogfooding.
2. Decide on a structural guard so `.claude/skills/` can't silently drift from canonical again (CI check, or extend `make sync` to cover it).
3. Remaining open tasks 002, 007, 010 are untouched and unprioritized.

## Session Metrics

- Tasks completed: 1 (022)
- Skills modified: 6 for Task 022 (task-start, task-complete, task-create, task-list, utils.worktree ×2 files) + 1 unrelated (task-plan)
- Bonus fixes: 2 (deferred-commit policy, task-plan double-approval)
- Incidental bugs found and fixed: 1 (`.claude/skills/` drift across 7 skills)
- Commits on `main`: 9
- Release verified: v1.12.0, full end-to-end install + functional test, all checks passed
