---
status: PR Open
created: "2026-09-15"
mode: Assisted
started: "2026-09-15"
pr: 139
---

# E2E Live Verification of Task 039's Release Mechanism

## Description

Task 039 (v2.1.1) redesigned `task-complete`'s changelog mechanism: a task's `## [X.Y.Z]` section is now written directly on the task branch and plain-pushed, version claims come from open `Prepare release vX.Y.Z` PR titles, and `task-start` creates a task's owner branch from freshly fetched `origin/main` instead of local `main`. Task 039's own PR already exercised most of this live — branch-born writes, plain push, PR-title claims, and Phase 2's merge/cleanup all worked correctly. Two things were never exercised: `task-start`'s new origin/main-branching fix (task 039's own branch was created with the *old* logic, before the fix existed), and the on-branch fold of an implementer's own `[Unreleased]` bullet (task 039 shipped with an empty `[Unreleased]`, so `release-prepare-files`' Task-Release Mode fold was only ever tested via `test-release-analysis-claimed-versions.sh`'s isolated shell reference implementation, never through a real live skill invocation).

Local `main` currently sits 5 commits ahead of `origin/main` (task 039's own bookkeeping trail — `chore: start task 039`, `chore: re-plan task 039...`, `chore: task 039 — PR #138 opened`, a merge commit, `chore: complete task 039`). This is the exact natural setup needed to directly test the bookkeeping-leak bug task 039 fixed: a fresh task's branch and PR must not carry any of these 5 local-only commits. This task runs a real, minimal, synthetic-content task through the full `task-start` → `task-complete` Phase 1 → PR review → Phase 2 lifecycle using the now-globally-installed v2.1.1 skills, to close both coverage gaps and confirm no regressions.

## Issue Triage Context

**Mode:** Skip
**Technologies:** None
**Platforms/Environments:** None
**Features/Integrations:** None
**Versions/Constraints:** None

## Design Decisions

- **Purely synthetic, permanent no-op content:** a one-line, self-labeled comment addition, zero behavioral change, safe to leave in place forever — isolates this verification from any real backlog outcome, per explicit choice.
- **Real merge through Phase 2:** the PR is merged for real, exercising the full cycle including Phase 2's `gh pr view` confirmation, `origin/main`-into-local-`main` merge, and worktree/branch cleanup — accepted cost: a genuine tiny release is cut.
- **Assisted mode, with a manual pause before Phase 2:** implementation and Phase 1 run first; the PR is handed back for direct diff inspection before Phase 2 proceeds.
- **Must run before local `main` is pushed to `origin/main`** (e.g., by `session-finish`) — the 5-commits-ahead state is the precondition that makes the bookkeeping-leak regression check meaningful. If that state no longer holds when this task starts, note it explicitly in Findings rather than silently skipping the check.
- **No separate test-report artifact:** this task's own mandatory `## Findings` section (required by `task-complete`'s Requirements) is the record, matching the precedent set by task 038's own live-verification trials.
- **The synthetic comment marker is left in place afterward,** not reverted in a follow-up task — it is harmless and self-documents what it is.

## Implementation Steps

1. Run `task.create` (this task) then `task.start 040` in Assisted mode. Immediately record the new branch's merge-base against `origin/main` (`git merge-base <branch> origin/main`) and confirm it equals `origin/main`'s tip at that moment, not local `main`'s tip — this is the direct proof of `task-start`'s Step 3 fix.
2. In the task worktree, add one synthetic no-op comment line to `Makefile` (near the top, after the `.PHONY` line) labeled as this task's verification artifact — no behavioral change.
3. As part of "implementing" step 2, manually add one bullet under `## [Unreleased]` in the branch's `CHANGELOG.md` describing the trivial change, simulating normal implementer behavior — this is what exercises the live fold, not the isolated reference test.
4. Run `task.complete 040` (Phase 1). Before reporting to the user, verify: (a) PR title is exactly `Prepare release vX.Y.Z`; (b) `release-analysis` did not falsely treat either of the two unrelated pre-existing open PRs (#65 `copilot/implement-task-007`, #61 `copilot/implement-task-010`) as a version claim; (c) `git log origin/main..<branch>` on the pushed branch contains only this task's own commits — none of local `main`'s 5 pre-existing bookkeeping commits; (d) the branch's own history shows no rewritten SHAs (no rebase occurred) and the push was a plain, non-forced push; (e) the new `## [X.Y.Z]` section correctly contains the folded `[Unreleased]` bullet from step 3.
5. Stop and hand the PR to the user for inspection (Assisted mode). Do not proceed to Phase 2 without an explicit follow-up request.
6. On the user's go-ahead, run `task.complete 040` (Phase 2): confirm `gh pr view` reports `MERGED`, merge `origin/main` into local `main`, remove the worktree, delete the local branch.
7. Verify `post-merge-release.yml` created the tag and GitHub Release correctly (`gh release view vX.Y.Z`), and confirm task 040's own file and `PLANNING.md` land on `Completed` with no leftover artifacts.

## Known Issues Triage

**Triaged:** 2026-09-15
**Result:** Skipped — explicitly marked `Mode: Skip` in task Notes.

## Acceptance Criteria

- [x] `task-start` creates the branch from freshly-fetched `origin/main`, verified to exclude all of local `main`'s pre-existing unpushed commits
- [x] `task-complete` Phase 1 opens a PR titled `Prepare release vX.Y.Z` with no false version-claim collision against the two unrelated open PRs
- [x] Phase 1 writes the `## [X.Y.Z]` `CHANGELOG.md` section on the branch only, correctly folding in an implementer-authored `[Unreleased]` bullet
- [x] Phase 1 uses a plain push with no rebase and no force-push
- [ ] Phase 2 confirms the merge via `gh pr view`, cleanly merges `origin/main` into local `main`, and removes the worktree/branch
- [ ] The resulting tag and GitHub Release are created correctly by `post-merge-release.yml`
- [x] Any discrepancy found is documented in Findings before declaring success

## Findings

[Populated by smaqit.task-complete. Do not fill in manually before task is complete.]

**Implementation approach:**
- Ran the real, freshly-installed v2.1.1 `task-start`/`task-complete` skills against this repo itself, at the exact moment local `main` sat 5 commits ahead of `origin/main` (task 039's own bookkeeping), to make the bookkeeping-leak regression check meaningful rather than coincidental.
- Added one permanent, harmless Makefile comment as the "feature," and manually wrote an `[Unreleased]` `CHANGELOG.md` bullet describing it during implementation — the one behavior task 039's own dogfood run never exercised (its `[Unreleased]` was empty).
- Verified each Phase 1 claim with direct evidence rather than trusting the skill's own report: `git merge-base` against `origin/main`, `git log origin/main..<branch>`, `gh pr view --json title`, `gh pr list --json` for the claimed-version check, and `git reflog` on the branch to confirm no rebase/reset occurred.

**Decisions made:**
- ACs 5-6 (Phase 2 merge/cleanup, tag/release creation) are intentionally left unchecked at Phase 1 — they describe outcomes that can only exist after Phase 2 runs, which this task's own phase-gated design defers to a later, separate explicit request. This is the same "PR Open ≠ Completed" split every owner task uses; nothing is actually unfinished for Phase 1's own scope.

**Blockers encountered:**
- None.

**Follow-up identified:**
- None — no discrepancy was found in Phase 1's execution. Phase 2 verification is the task's own remaining, explicitly deferred step.

## Files to Create / Modify

| File | Action |
|------|--------|
| `Makefile` | Modify — one-line synthetic no-op comment |
| `CHANGELOG.md` | Modify — implementer `[Unreleased]` bullet, then folded into `## [X.Y.Z]` by `task-complete` |

## Notes

This task is itself the live E2E verification artifact for task 039 — its own successful completion (or any discrepancy surfaced in Findings) is the deliverable, not a separate report file.
