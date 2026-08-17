# Update Scope Fix and Live Test

**Date:** 2026-08-17
**Session focus:** Completed task 033 — fixing `smaqit-extensions update`'s post-self-update reinit, which was silently writing full project-scoped agent/skill mirrors into any project instead of the scope-only scaffolding `init` already correctly performs. Also documented a new hard-stop instruction for PAT-switch 403 errors, and live-tested the shipped fix against the real global install, uncovering a one-time transitional caveat inherent to self-replacing binaries.
**Tasks completed:** 033 — Fix `update` Writing Project-Scoped Agent/Skill Mirrors Despite Documenting Itself as Global-Only
**Tasks referenced:** 031 (Fix Release-Analysis Boundary Detection for PR-Gated Releases) — completed by a parallel session during this one; its boundary-detection bug was independently hit live while computing task 033's own release version

## Actions Taken

- Started with `smaqit.session-start`; confirmed task 033's diagnosis (`update`'s reinit calling `install --scope project` instead of the scope-aware `init` path) was already correct from the prior session, then ran `smaqit.task-start 033`.
- Implemented the fix: both of `update`'s reinit routes (`checkAndReInitWithBinary`, post-download; `checkAndReInit`, same-version path) now call `scaffoldProject`/`init` — the exact function `init` itself uses — instead of the internal/testing `install --scope project` alias.
- Fixed the existing test that had asserted the buggy invocation as expected behavior (`TestCheckAndReInitWithBinaryRunsFreshProcess`), and added `TestScaffoldProjectCreatesOnlyProjectTrackingPaths`. Verified the regression test fails against the pre-fix code with the exact reported buggy invocation. `make test` and `make smoke-test` passed; manual scratch-repo verification confirmed only the four documented paths are created.
- Ran `smaqit.task-complete 033` Phase 1: computed the release version via `release-analysis` Task mode, and hit task 031's own known bug live — the automated boundary search found `v1.17.1` instead of the true last release `v2.0.0`, because v2.0.0's release marker existed only as a PR title, never a commit message. Manually overrode the boundary to `v2.0.0` (PR #127's merge commit), same workaround pattern used in the 2026-08-15 session. Approved `v2.0.1`.
- Hit a `git push` 403 opening the PR. Per direct user instruction, added a new CLAUDE.md rule: on a PAT-looking 403, hard-stop and ask the user to fix/restore the PAT rather than diagnosing credential helpers, token scopes, or trying alternate remotes — the user later clarified (recorded in memory) the exact mechanism is a `vault-gh-token.sh` script that switches the active `gh` token between projects. Retried after user confirmation; push succeeded.
- Opened PR #128 ("Prepare release v2.0.1"), pushed the pending CHANGELOG entry to `main`, rebased and promoted it on the branch. Task 033 entered `PR Open`.
- On "pr merged, release available", ran Phase 2: confirmed the merge via `gh pr view`, pulled `main`, set task 033 to `Completed`, removed the worktree, force-deleted the local branch, rebuilt the workspace. Hit a second PAT-switch 403 on the completion-bookkeeping push; hard-stopped per the new rule, retried cleanly after user confirmation.
- Discovered during Phase 2 that v2.0.1's published GitHub Release notes were polluted with task 031's still-pending `(pending v2.0.2 · PR #129)` entry — a race where a `main`-into-branch merge on PR #128 (after task 031 had pushed its own pending entry) nested task 031's unpromoted bullet under PR #128's own version header via line-based git merge. Recorded as an unfiled follow-up in task 033's Findings; task 033's own change was unaffected and shipped correctly. Task 031 also completed during this session (parallel activity), shipping as v2.0.2.
- At the user's request, live-tested `smaqit-extensions update` against the real global install and this project. First run (upgrading the locally-installed v2.0.0 binary to v2.0.2) **reproduced the original bug** — full mirror written into the project. Diagnosed live: `git show v2.0.2:installer/main.go` confirmed the fix genuinely shipped in the tagged source; the reproduction was explained by the calling process being the OLD (pre-fix) binary's already-loaded code — `checkAndReInitWithBinary` replaces the binary file on disk and re-execs it as a subprocess, but the *decision* of which arguments to pass to that subprocess is made by the currently-running (old) process's compiled logic, not the new binary's. Cleaned up the accidentally-created untracked mirror directories, then re-ran `update` — starting this time from the now-installed fixed v2.0.2 binary — and confirmed clean behavior (global refresh + scaffold-only project reinit, no mirror writes).

## Problems Solved

- **`update` project-scoped mirror leak (task 033).** Fixed by converging both reinit paths onto `scaffoldProject`/`init`. Confirmed via regression tests, a fail-then-pass check against the pre-fix code, `make test`/`make smoke-test`, and two live `update` runs against the real global install.
- **PAT-switch 403 confusion.** Previously this class of failure prompted diagnostic effort (credential helpers, `gh auth status`, `gh auth setup-git`) that never found anything actionable, because the real cause — the user's own `vault-gh-token.sh` switching the active token between projects — isn't discoverable from the repository or Git state at all. Now codified as an immediate hard-stop-and-ask in both `CLAUDE.md` and memory.

## Decisions Made

- **Converge `update`'s reinit onto the same function `init` uses**, rather than adding a parallel scope check — satisfies task 033's own acceptance criterion that both paths are verifiably the same code path, not parallel implementations that can drift again (the exact failure mode task 033 itself was reporting).
- **Manually override the release-boundary search again** (same workaround as the 2026-08-15 session) rather than block task 033's own completion on task 031 landing first — task 031 was already independently in flight in a parallel session.
- **Hard-stop immediately on a PAT-looking 403**, no diagnosis — per explicit user instruction, now durable in both `CLAUDE.md` and memory, since the failure is external to the repository and unresolvable by inspecting it.
- **Live-test `update` against the real global install** rather than only a scratch repro, since the shipped fix's actual end-to-end behavior — including the one-time old-binary transition caveat — could only be observed that way.
- **Record the transitional old-binary caveat as a task Finding, not a new task.** It's inherent to any self-replacing binary's in-process logic (the decision code is whatever was already loaded before the file swap) and isn't something task 033's code can retroactively fix for already-distributed old binaries; per user direction, the existing Finding is sufficient documentation.
- **Leave the v2.0.1 release-notes changelog-pollution finding unfiled** — real but out of task 033's scope, a race in the pending-entry-promotion mechanism between two concurrent PR-gated releases; recorded in Findings for future attention.

## Files Modified

- `installer/main.go` — `checkAndReInitWithBinary` and `checkAndReInit` both converged onto `scaffoldProject`/`init`
- `installer/main_test.go` — fixed `TestCheckAndReInitWithBinaryRunsFreshProcess`; added `TestScaffoldProjectCreatesOnlyProjectTrackingPaths`
- `CHANGELOG.md` — v2.0.1 entry (task 033); v2.0.2 landed separately via task 031
- `.smaqit/tasks/033_fix_update_writing_project_scoped_mirrors.md` — Findings, acceptance criteria, status lifecycle (`Not Started` → `In Progress` → `PR Open` → `Completed`)
- `.smaqit/tasks/PLANNING.md` — task 033 moved to Completed
- `CLAUDE.md` — new PAT-switch hard-stop instruction
- `smaqit-extensions.code-workspace` — regenerated after worktree removal

## Next Steps

- Consider filing a task for the v2.0.1 release-notes changelog-pollution race between concurrent PR-gated releases, if it recurs or becomes disruptive — currently just a recorded Finding.
- Tasks 002, 007, 028, 010 remain Not Started, untouched this session.
- Global install is now confirmed current at v2.0.2 on this machine, verified via two live `update` runs.

## Session Metrics

- **Duration:** Full session, single continuous thread
- **Tasks completed:** 1 (033); task 031 completed concurrently by a parallel session
- **Releases shipped:** 2 — v2.0.1 (PATCH, task 033) and v2.0.2 (PATCH, task 031, parallel session)
- **PAT-switch 403 stops:** 2, both resolved cleanly on user confirmation with no diagnostic effort per the new instruction
- **Live `update` runs:** 2 against the real global install — first reproduced the pre-fix transitional bug (expected, explained, not a regression), second confirmed clean post-fix behavior
- **Regression tests added:** 1, verified to fail against the pre-fix code
