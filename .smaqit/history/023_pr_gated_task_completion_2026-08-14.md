# PR-Gated Task Completion

**Date:** 2026-08-14
**Session focus:** Redesigning `task-complete` so main is never pushed into directly for code while smaqit's own metadata stays synced in real time, then implementing, self-reviewing, and shipping that redesign as task 027 — including two live-discovered bugs fixed after the fact — plus diagnosing a separate `smaqit-extensions update` regression, then planning a follow-up hotfix to `session-finish`'s own confirmation gate based on direct feedback during this session's own close-out.
**Tasks completed:** 027 — PR-Gated Task Completion & Per-Task Releases
**Tasks created:** 029 — Relax Session-Finish Push Confirmation Gate (Not Started)
**Tasks referenced:** 002, 007, 010, 028 (untouched, still Not Started/new)

## Actions Taken

- Started session with `smaqit.session-start`; loaded context — task 025 already completed, no other in-progress work.
- User asked to assess (`smaqit.session-assess`) why `task-complete` doesn't play well with release planning. Verified empirically that "main is protected" was never actually true — `task-complete` merges directly and `session-finish` pushes directly, no GitHub branch protection exists. Worked through the design in an extended back-and-forth: code stays PR-gated (convention only, no GitHub enforcement); metadata (`PLANNING.md`, task files, `CHANGELOG.md`) syncs directly to `main` immediately; every owner task's PR is also its release; `CHANGELOG.md`'s `[Unreleased]` holds per-entry `(pending vX.Y.Z · PR #NNN)` annotations so concurrent tasks don't collide; local branch cleanup force-deletes (`-D`) once `gh pr view` confirms merged (handles squash merges); Autonomous mode self-merges immediately, Assisted mode's Phase 2 needs its own explicit request; ships as the global default; child tasks are untouched.
- Handed off to `smaqit.task-plan`. Two Explore agents investigated worktree/lifecycle mechanics and the post-merge release workflow, surfacing two real pre-existing bugs the plan needed to fix, not just new behavior: `release-analysis`'s boundary search never fetched fresh `origin/main` (a real version-collision risk), and `git branch -d` can't recognize a squash-merged branch. Resolved several more design forks via targeted questions (squash cleanup policy, collision-hardening scope, Autonomous Phase 2 trigger, stale draft PRs out of scope), then a final child-task caveat. Plan approved; created task 027.
- Started task 027 (Assisted mode) and implemented across 18 files: the pending-CHANGELOG-entry convention and its promotion logic (`release-prepare-files`), `release-analysis`'s Task mode + pending-version awareness, `release-approval`'s auto-confirm path, `release-git-pr`'s narrowed role, both `post-merge-release.yml` copies (concurrency group), `task-start`'s immediate-push retry loop, and a full rewrite of `task-complete` into Phase 1 (commit → version → PR → pending entry → promote → `PR Open`) and Phase 2 (re-entrant merge-check → cleanup), plus all three synced `RULES.md` copies, both task templates, and two new hermetic test files. `make test` and `make smoke-test` green; installed globally.
- User asked for a critical self-review (switched to Opus). Found six real defects, three of them blocking: nothing ever called `gh pr create` (release-git-pr only verifies titles, never opens PRs); the pending CHANGELOG entry was written *before* the PR existed even though its annotation names the PR; nothing promoted the pending entry on the PR's own branch, which would have shipped every release with empty notes and an orphaned pending annotation forever. Also found: Phase 2 was reachable without re-checking the Assisted-mode gate, the Abandon Path was never routed to, and a stale step cross-reference. Fixed all six, added regression assertions for each, reran the full suite, rebuilt and reinstalled globally.
- User approved and asked to complete the task (back to Sonnet). Ran Phase 1 live against the real repo: computed v1.17.0 via `release-analysis`, pushed the branch, opened PR #124, pushed the pending entry to `main` — hit a real rebase conflict (an old pre-mechanism CHANGELOG draft colliding with the entry the mechanism itself had just pushed), resolved it explicitly rather than auto-resolving blindly, promoted the entry on the branch, force-pushed, set `PR Open`, stopped for review.
- User merged the PR and said so. Phase 2 hit a second live bug immediately: `9_resolve_task_lifecycle.sh`'s `find_active_task()` hardcoded `Status: In Progress`, which rejected `--purpose complete` once Status became `PR Open` — a gap the implementation and the self-review both missed because neither actually ran Phase 2 end-to-end. Since PR #124 had already merged, fixed it as a direct commit to `main` (this repo's own established convention for small infra fixes), with a regression test verified to fail against the pre-fix resolver and to confirm the parent-child join path still requires strict `In Progress`. Completed Phase 2: pulled `main`, worktree removed, local branch force-deleted, remote branch preserved. `v1.17.0` tag and GitHub Release confirmed live.
- User asked to confirm `smaqit-extensions update` picked up the fixes. Verified independently (ancestry check, not just trusting output) that the resolver fix was **not** in `v1.17.0` — it landed on `main` after the tag, since only PR merges trigger `post-merge-release.yml`, not direct commits. Explained the gap and offered options.
- User asked for a small patch release via the local release agent. Delegated to the `smaqit-release-local` subagent, which produced `v1.17.1` (analyzed the two-commit delta since `v1.17.0`, confirmed PATCH severity, also fixed a stale `CHANGELOG.md` compare-links footer). Verified independently (ancestry check, GitHub Actions run success, GitHub Release not a draft), then ran `smaqit-extensions update` myself to confirm end-to-end.
- That verification run exposed a third bug: `update`'s project-rescaffolding step has no special case for "this directory is smaqit-extensions' own source repo" — it re-created the exact committed-dogfooding-mirror pattern removed in v1.14.3 (`.github/agents/`, `.github/skills/`, `.claude/`, `.codex/agents/`, `.agents/skills/`) plus resurrected an orphaned template file, directly inside this repo. Everything was untracked (nothing committed), so cleaned it up and flagged it as a follow-up rather than fixing it unprompted.
- User asked whether this was the known "self-update runs stale in-process code" bug class. Read `installer/main.go`'s actual `runUpdate`/`replaceBinary`/`checkAndReInitWithBinary` implementation rather than guessing — confirmed that class of bug is correctly avoided (`exec.Command(binaryPath, ...)` respawns a fresh subprocess of the just-replaced binary). Pinpointed the real cause precisely: `checkAndReInitWithBinary`'s scaffold check (`main.go` ~1304-1305) only tests "does `.smaqit/` exist here," with no repo-identity check at all — and the `cmp == 0`/`cmp > 0` early-return path calls the equivalent `checkAndReInit`, so the bug is unrelated to versioning or process staleness.
- Ran `session.finish`. Mid-way, at the Step 7 commit/push confirmation, user gave direct feedback: the routine confirm-before-commit/push gate is "too slow and too fearful" — should proceed directly on the unambiguous case (known self-authored files, clean fast-forward) and reserve stopping for actual critical errors, using the exact pending push as a live example of what should have gone through without asking. Captured as a feedback memory, scoped explicitly against the separate, still-standing release-approval feedback so the two don't get conflated. Pushed the pending commit directly per the new guidance, then planned (`smaqit.task-plan`, no Explore agents needed — the target file's current content was already fully known from earlier in this session) and created task 029 to make the fix: a subtractive rewrite of `session-finish` Step 7's two confirmation sentences, explicitly not replaced with new prescriptive logic, with all existing hard-stop conditions left untouched. Applied the same new push-autonomy guidance immediately to task 029's own creation commit.

## Problems Solved

- **Root design gap:** `task-complete` merged directly into `main` with no review gate and no actual GitHub enforcement of "main is protected" — resolved by making code PR-gated (convention-only) while keeping smaqit's own metadata on a fast, direct-push path so parallel sessions stay in sync.
- **Version-collision risk (pre-existing, found during discovery):** `release-analysis` computed boundaries from possibly-stale local refs; fixed to always fetch `origin/main` fresh, plus made it aware of other tasks' pending-claimed versions.
- **Three blocking self-review defects:** no PR-creation step, pending-entry-before-PR-exists ordering, and a missing promotion-on-branch step — each would have broken the mechanism silently (no PR ever opens; malformed annotation; every release ships with empty notes and a permanently orphaned pending line).
- **Two Phase-2 process gaps:** an unreachable Abandon Path and a missing independent mode-check for Phase 2 (closed so Assisted-mode tasks can't slip through on a stale Phase-1 authorization).
- **Live resolver bug:** `find_active_task()`'s hardcoded `In Progress` check rejected the very `PR Open` status this task introduced, for `--purpose complete`. Found only because Phase 2 was actually run for real, not because it was reasoned about in review.
- **`smaqit-extensions update` self-scaffolding regression:** `checkAndReInitWithBinary` treats any directory with `.smaqit/` as a scaffoldable consumer project, with no exemption for the tool's own source repo — confirmed via source reading, not speculation.

## Decisions Made

- Main's code stays PR-gated by convention only; no GitHub branch protection rule added (explicit user choice).
- Every owner task's PR is also its release — a deliberate cadence change from the previous batched-release model; child tasks are completely unaffected.
- `CHANGELOG.md` pending entries use per-entry `(pending vX.Y.Z · PR #NNN)` annotations (not a renamed section) so multiple tasks can be pending concurrently; tags may land out of numeric order.
- Local branch cleanup always force-deletes (`-D`) once `gh pr view` confirms `MERGED` — GitHub's own state is authoritative, never git's local ancestry check; the remote branch is never deleted, kept as an audit trail.
- Direct fixes to `main` remain the right tool for small infra bugs discovered outside a task's own PR (used for both the resolver fix and, implicitly, accepted for the `update` scaffolding bug as a future follow-up rather than an in-band fix).
- Rebase conflicts are never auto-resolved blindly — even when the cause is understood with certainty (as in the CHANGELOG conflict during Phase 1), the resolution is made explicit and reasoned through, not silently applied.

## Files Modified

**Task 027 (PR-gated task completion):**
- `skills/smaqit.task-complete/SKILL.md`, `references/RULES.md` (+ synced copies in `task-start`, `task-list`)
- `skills/smaqit.task-start/SKILL.md`
- `skills/smaqit.release-analysis/SKILL.md`, `smaqit.release-approval/SKILL.md`, `smaqit.release-prepare-files/SKILL.md`, `smaqit.release-git-pr/SKILL.md`
- `skills/smaqit.utils.worktree/SKILL.md`
- `.github/workflows/post-merge-release.yml`, `installer/workflow-templates/post-merge-release.yml`
- `.smaqit/templates/task.template.md`, `installer/templates/task.template.md`, `skills/smaqit.task-create/assets/TASK_TEMPLATE.md`, `skills/smaqit.task-create/SKILL.md`
- `tests/skills/test-task-complete-pr-lifecycle.sh`, `tests/skills/test-release-analysis-pending-versions.sh` (new)
- `Makefile`, `CHANGELOG.md`

**Post-merge direct fixes (not part of PR #124):**
- `skills/smaqit.utils.worktree/scripts/9_resolve_task_lifecycle.sh` — `find_active_task()` now accepts a per-call status allow-list (`v1.17.1`)
- `tests/skills/test-task-complete-pr-lifecycle.sh` — regression coverage for the above

## Next Steps

- Task 029 (Not Started) is ready to start: subtractive rewrite of `session-finish` Step 7's confirmation gate.
- `smaqit-extensions update`'s scaffolding logic still needs a repo-identity check so it stops re-creating dogfooding mirrors when run inside this repo's own checkout — root cause pinpointed (`installer/main.go` ~1304), not yet fixed or task-tracked.
- Tasks 002, 007, 010 remain open (Not Started), unchanged this session.
- Task 028 ("Benchmark Glossary Skill Invocation") appeared in `PLANNING.md` during this session from outside this thread — not investigated here.
- Working tree should be clean on `main` after this session-finish run; verify before next session.

## Session Metrics

- **Duration:** Full session, single continuous thread (model switched Sonnet → Opus for review → Sonnet)
- **Tasks completed:** 1 (027)
- **Tasks created:** 1 (029, Not Started)
- **Releases shipped:** 2 (v1.17.0 via task 027's own new PR-gated mechanism — the first task ever completed through it; v1.17.1 patch via `smaqit-release-local`)
- **Real bugs found and fixed:** 9 total — 3 blocking + 3 non-blocking in self-review before merge; 1 live in Phase 2 after merge; 1 pre-existing bug fixed as part of discovery (release-analysis stale boundary); 1 (`update` scaffolding) found and diagnosed but deliberately left unfixed pending a future task
- **Files modified/created:** ~20 across the task 027 PR, plus 2 more in the post-merge direct fix
- **Direct process feedback incorporated mid-session:** relaxed push-confirmation behavior for routine session-finish commits, applied immediately and captured as a standing memory
