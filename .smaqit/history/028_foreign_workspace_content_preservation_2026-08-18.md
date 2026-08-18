# Foreign Workspace Content Preservation

**Date:** 2026-08-18
**Session focus:** Diagnosing and fixing a user-reported bug where `.code-workspace` regeneration silently discarded content it doesn't own (a manually-added sibling repo folder, a custom setting), then shipping and live-testing the fix. Also closed out tasks 031 and 033 from the prior session (merged concurrently mid-session while this one was in progress).
**Tasks completed:** 034 — Preserve Foreign Content When Regenerating the `.code-workspace` File
**Tasks referenced:** 031, 033 (both merged and cleaned up mid-session by a concurrent session, observed and reconciled here); 002, 007, 010, 028 (untouched, still Not Started)

## Actions Taken

- Started with `smaqit.session-start`. Found tasks 031 and 033 both `PR Open` from the prior session (v2.0.2 and v2.0.1 respectively); 033's PR had already merged, memory was stale.
- User reported a bug: an unrelated sibling repo folder (`local-llm`) manually added to the shared `.code-workspace` file disappeared after a `task-start`/`task-complete` cycle, and questioned whether the file should even be checked into task worktrees.
- Ran `smaqit.session-assess`. Root-caused the report directly: `7_build_workspace.sh` (invoked by both `task-start` and `task-complete` cleanup) fully rebuilds the workspace file from scratch via `jq -n` on every run, with no read-back step — any `folders` entry outside `main`/current worktrees, and any `settings` key beyond the hardcoded `files.exclude` block, is silently dropped. Reproduced live: while investigating, a concurrent session's `task-complete` cleanup for tasks 031/033 dropped both worktree folder entries in one commit (`7dd05b5`). Separately found the workspace file itself was not excluded from task-worktree sparse checkouts, despite the skill's own convention (Gotcha #16) that Step 7 must always run from the primary checkout.
- Ran `smaqit.task-plan` (Mode A) with two parallel Explore agents — one surveying existing worktree test patterns and Makefile wiring, one reading the target scripts/SKILL.md verbatim for precise patch context. Both returned before drafting the plan; no blocking gaps, so went straight to Phase 4 design.
- User approved the plan; created, started, and implemented task 034 (Assisted mode). Rewrote `7_build_workspace.sh` to read the existing file first, partition `folders` into a managed set (rebuilt from `git worktree list`) and a foreign set (preserved verbatim), and deep-merge `settings`. Added `'!/*.code-workspace'` to `5_create_worktrees.sh`'s sparse-checkout exclusions.
- Extended `tests/skills/test-worktree-layout.sh` in place — no new Makefile target. Manually verified in two isolated checks (reverting only `7_build_workspace.sh`, then only `5_create_worktrees.sh`, restoring from `main`) that each half of the new test coverage independently fails against the pre-fix scripts and passes against the fix.
- `make test` and `make smoke-test` both passed. User approved completion; ran `task-complete` Phase 1 (PR #130, v2.0.3 — `release-analysis` correctly excluded the pre-existing task 031/033 bookkeeping commits already on `main` from the changelog delta, since they were non-user-facing chores already present before the branch was cut).
- User merged the PR. Ran Phase 2: verified the merge via `gh pr view`, pulled `main`, marked the task Completed, removed the worktree, deleted the local branch.
- User asked to test the shipped fix. Ran `smaqit-extensions update` (v2.0.2 → v2.0.3) — itself a live re-test of task 033's fix, confirmed no project-scoped mirrors were written. Confirmed the globally-installed skill now matches the released source byte-for-byte. Then reproduced the original bug scenario for real against this repo's own `.code-workspace`: injected a foreign folder and setting, ran a genuine worktree-create → worktree-remove cycle through the updated global skill, and confirmed both survived intact through both rebuilds. Cleaned up all test artifacts.
- Two 403 permission-denied pushes occurred during the session (task-start's metadata push, task-complete's completion commit) — both handled per the repo's standing PAT-switch instruction: hard-stopped, asked the user to restore their PAT, retried once confirmed.

## Problems Solved

- **Destructive `.code-workspace` regeneration.** `7_build_workspace.sh` previously discarded any content it didn't itself manage on every `task-start`/`task-complete` run. It now reads-then-merges: foreign `folders` entries and `settings` keys survive every regeneration, while the `main` + worktree portion still fully reflects current Git state.
- **Workspace file unnecessarily checked into task worktrees.** Added to the sparse-checkout exclusion list alongside `.smaqit/tasks/`, matching the existing "primary-checkout-only" convention the skill already documents for Step 7.
- **Stale task-state memory.** Task 033's memory entry still said `PR Open` after the PR had actually merged; observed and reconciled by running task-complete's Phase 2 for both 031 and 033 (though a concurrent session completed the actual Git lifecycle work mid-investigation).

## Decisions Made

- **Kept the workspace file git-tracked on `main`** — Gotcha #8's documented rationale (any session pulling `main` sees the current set of active task worktrees) is a genuine, real shared-state need, distinct from the destructive-overwrite bug. Fixed the overwrite, not the tracking model.
- **Foreign folders appended after the managed set** on every regeneration, accepting minor reordering as a trade-off against the complexity of positional preservation.
- **Extended the existing `test-worktree-layout` target** rather than adding a new test file or Makefile target, since it already exercises both affected scripts.
- **Verified test coverage catches the bug, not just agrees with the fix** — an explicit, deliberate check beyond the task's own acceptance criteria wording, run twice (once per script) to confirm each half of the fix is independently covered.
- **`release-analysis`'s Task-mode boundary correctly excluded prior-session bookkeeping commits** already on `main` from this task's changelog delta — confirmed working as designed (task 031's own fix, shipped last session).

## Files Modified

- `skills/smaqit.utils.worktree/scripts/7_build_workspace.sh` — read-then-merge instead of full overwrite
- `skills/smaqit.utils.worktree/scripts/5_create_worktrees.sh` — added `.code-workspace` sparse-checkout exclusion
- `skills/smaqit.utils.worktree/SKILL.md` — Step 7, Gotcha #8, Gotcha #11 updated; version `1.4.0` → `1.5.0`
- `tests/skills/test-worktree-layout.sh` — foreign-content-survives and sparse-exclusion regression coverage
- `.smaqit/tasks/034_preserve_foreign_workspace_content.md` — created, implemented, completed
- `.smaqit/tasks/PLANNING.md` — task 034 lifecycle
- `.smaqit/references/project-research.md` — task 034 block (no third-party tools; empty table)
- `CHANGELOG.md` — `[2.0.3]` added
- `smaqit-extensions.code-workspace` — regenerated across worktree create/remove cycles, including live-test artifacts (cleaned up)

## Next Steps

- Tasks 002, 007, 010, 028 remain Not Started, untouched this session.
- Task 002 ("Fix Changelog Extraction for Cumulative Releases") was already flagged by task 031's own findings as possibly overlapping — still worth re-reading before starting it.
- No new follow-up filed from this session; task 034's own Notes already covered the one known residual gap (already-created worktrees predating the fix keep a stale workspace-file copy until they next cycle through completion).

## Session Metrics

- **Duration:** Full session, single continuous thread
- **Tasks completed:** 1 (034); 2 more (031, 033) observed merged and reconciled mid-session from a concurrent session's work
- **Releases shipped:** 1 — v2.0.3 (PATCH)
- **Regression tests added:** 2 assertions in existing suite, each independently verified to fail with its corresponding half of the fix reverted
- **Live end-to-end verification:** global install updated and confirmed byte-identical to released source; original bug scenario reproduced and confirmed fixed against the real repo, not just test fixtures
- **403 PAT interruptions handled:** 2, both per standing instruction (hard-stop, no diagnosis, retry on confirmation)
