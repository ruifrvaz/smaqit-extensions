# Task-Lifecycle Local Bookkeeping

**Date:** 2026-09-12
**Session focus:** Implemented and shipped task 036 end-to-end — moved `task-start`/`task-complete`'s bookkeeping commits from a required push to `origin/main` onto local `main` only, fixing a downstream repo's 6-8-bookkeeping-PRs-per-task problem under required-PR-review branch protection.
**Tasks completed:** 036 — Move Task-Lifecycle Bookkeeping Commits Off origin/main Onto Local main (shipped v2.0.4, PR #134)
**Tasks referenced:** None else touched; 028/002/007/010 remain Not Started, untouched this session

## Actions Taken

- Started with `smaqit.session-start` (continuing from session 029's 2026-08-21 confidentiality-hook abandonment); task 036 had already been created just before this session with a fully detailed spec.
- Ran `smaqit.task-start 036`: resolved as owner, created branch/worktree. Research map was stale (21 days old, 7-day threshold) — rebuilt it, re-verifying all 11 existing project-layer URLs live plus 4 new task-layer URLs (Bash manual, `git-worktree`/`git-rebase`/`git-merge` docs), and upserted task 036's own map block. Issue triage exited cleanly (task declared `Mode: Skip`, no third-party tool surface). Hit one 403 PAT-permission interruption pushing the start-bookkeeping commit — handled per the repo's standing instruction (hard-stop, no diagnosis, retried after user confirmed the PAT was restored).
- Implemented the fix: rewrote `task-start/SKILL.md` Step 8 and `task-complete/SKILL.md` Steps 12/14/18 (plus its Abandon Path Step 24) to commit bookkeeping to local `main` only, never pushed, replacing the old push-with-bounded-fetch-rebase-retry loop with a re-read-before-write policy and an explicit never-auto-resolve rule on a genuine collision. Rewrote Step 13 to rebase onto local `main` (no fetch needed) and Step 17 — the task's own flagged "genuinely tricky" piece — to `fetch` + `merge origin/main` instead of a fast-forward-only pull, since local `main` can now legitimately sit ahead of `origin/main` with unpushed bookkeeping. Added a "Local-Only Sessions" note to both `SKILL.md` files. Spot-checked all nine `smaqit.utils.worktree` scripts for `fetch`/`pull`/`push`; found none, no script changes needed.
- Updated `references/RULES.md` in `task-start`, `task-complete`, **and `task-list`** — the third copy wasn't in the task's own file list, but the existing hermetic test suite enforces all three stay byte-identical, so it had to be included too (a small gap in the original task spec, recorded in Findings).
- Rewrote `tests/skills/test-task-complete-pr-lifecycle.sh`'s old two-clone push-race fixture into one exercising the new Step 17 merge behavior (local `main` ahead + a real remote PR-merge commit converging cleanly; a genuine conflict aborting cleanly via `git merge --abort`), and fixed three stale string assertions that referenced removed push language.
- Verified with `make test` (all 12 hermetic suites) and `make smoke-test` — both passed clean, confirming no regression to this repo's own unprotected-`main` task lifecycle.
- User declined a live main-branch-protected GitHub repo trial (the task's own acceptance criterion 8) when offered. Instead, planned and ran an ad-hoc two-agent concurrency bench: two parallel subagents raced real `task-start` mechanics (`9_resolve_task_lifecycle.sh`, `git worktree add`, a task-awareness scan, a local bookkeeping commit) against one shared plain local repo with **no remote configured at all**. Confirmed no push ever occurred, no lock contention, correct task-awareness detection of a concurrent in-flight *uncommitted* edit via `git status`, and a clean re-read-before-write outcome with no data loss on `PLANNING.md`.
- User asked whether the formal `.smaqit/bench/` Codex-discovery harness (`smaqit.bench-scaffold`/`smaqit.bench-run`) had been used — clarified it hadn't, since that harness tests skill *discovery/invocation* (an A/B comparison mechanism), not the mechanical git-concurrency question this session needed answered; offered to switch if the user wanted the formal harness used instead, which they did not take up.
- Ran `task.complete 036`: wrote Findings, then flagged that acceptance criterion 8 (the literal protected-repo trial) was genuinely unmet per the skill's own hard gate. Asked the user how to handle it; user chose to **revise the criterion** to reflect the concurrency-bench evidence instead, with the deferral rationale recorded in the task's Notes. Checked off all 9 criteria, computed the release version via `release-analysis` Task mode (v2.0.4, PATCH — internal workflow fix, no breaking/public-API change) and `release-approval` Pattern 4 auto-confirm, opened PR #134 ("Prepare release v2.0.4"), pushed the pending `CHANGELOG.md` entry to `main`, promoted it on the branch. Stopped per Assisted mode's Phase 1 gate.
- User merged the PR and said "merged" — ran Phase 2: confirmed `MERGED` via `gh pr view`, pulled `main` (fast-forward), preserved the user's own concurrent uncommitted edit to the task file's Notes (redacting a downstream repo name), set status to `Completed`, moved the `PLANNING.md` entry, removed the worktree, force-deleted the local branch, rebuilt the workspace file. Verified tag `v2.0.4` and its GitHub Release (with built binaries) were published by `post-merge-release.yml`.

## Problems Solved

- **The actual bug**: `task-start`/`task-complete` assumed a plain `git push origin main` for every bookkeeping transition would always succeed — true only on an unprotected `main`. A downstream repo with ordinary required-PR-review branch protection needed 6-8 separate PRs per task, nearly all pure bookkeeping with no reviewable content, because every bookkeeping commit had no path to land except a full push-branch-open-PR-review cycle.
- **The fix's premise**: since `smaqit-extensions` sessions are always local (no cross-machine/cloud coordination), and `git worktree` shares one `.git` object database and ref namespace across every worktree, bookkeeping commits never needed to leave the local checkout at all — visibility across worktrees is already instant with zero network operation.
- **A stale reference discovered mid-task**: the task file's "Files to Create/Modify" table cited `installer/skills/...`/`installer/skills-claude/...` mirrors as things to modify — those trees are actually gitignored, ephemeral `make sync` output with no committed mirrors, so nothing there needed direct editing (confirmed by running `make sync`/`make prepare`/`make build` and the full smoke test instead).

## Decisions Made

- **Extended the RULES.md sync scope to `task-list`'s copy**, beyond what the task file itself listed, because the pre-existing hermetic test enforces a three-way byte-identical contract across `task-start`, `task-complete`, and `task-list`'s `references/RULES.md` — leaving it out would have broken that contract on merge.
- **Revised acceptance criterion 8** (live main-branch-protected GitHub repo trial) to the ad-hoc no-remote concurrency bench evidence instead, on explicit user approval, after the user declined to stand up a disposable protected-branch GitHub repo this session. The literal protected-repo trial remains a documented, unverified follow-up if a real downstream regression is ever reported.
- **Used an ad-hoc two-agent bench rather than the formal `.smaqit/bench/` harness** for the concurrency validation — that harness is purpose-built for Codex-based skill-discovery A/B comparison (as task 028 will use it), not for a direct mechanical question about git behavior with no variant to compare.

## Files Modified

- `skills/smaqit.task-start/SKILL.md`, `skills/smaqit.task-start/references/RULES.md`
- `skills/smaqit.task-complete/SKILL.md`, `skills/smaqit.task-complete/references/RULES.md`
- `skills/smaqit.task-list/references/RULES.md` (kept in sync, not originally listed on the task)
- `tests/skills/test-task-complete-pr-lifecycle.sh` — new Step 17 merge-behavior fixture, replacing the old push-race test; three stale assertions fixed
- `CHANGELOG.md` — `## [2.0.4]` section
- `.smaqit/tasks/036_task_lifecycle_bookkeeping_local_main.md` — full lifecycle (created pre-session, started, implemented, criterion 8 revised, completed)
- `.smaqit/tasks/PLANNING.md` — task 036 moved Active → Completed
- `.smaqit/references/project-research.md` — project table re-verified, task 036 block added
- `smaqit-extensions.code-workspace` — regenerated across worktree create/remove cycles
- `installer/skills/`, `installer/skills-claude/` — regenerated via `make sync` (gitignored, not committed)

## Next Steps

- Tasks 028, 002, 007, 010 remain Not Started, untouched this session. Per the prior session's note, re-read task 002 before starting it — it may be subsumed by task 031's already-shipped tag-based boundary detection fix.
- The literal main-branch-protected GitHub repo trial (task 036's original acceptance criterion 8) is still unverified live. If a downstream repo with required-PR-review protection reports a bookkeeping-only-PR regression, that live trial is the next diagnostic step.
- No new follow-up filed in this repo beyond what's recorded in task 036's own Findings/Notes.

## Session Metrics

- **Duration:** Full session, single continuous thread
- **Tasks completed:** 1 (036), shipped v2.0.4 (PR #134, merged)
- **Tasks abandoned:** 0
- **Releases shipped:** 1 (v2.0.4 — PATCH, internal workflow behavior fix)
- **Tests written/modified:** 1 hermetic test file rewritten (new Step 17 merge fixture; 3 stale assertions fixed); full `make test` (12 suites) and `make smoke-test` both passing
- **Live verification:** `make smoke-test` (this repo, unprotected `main`); ad-hoc two-agent concurrency bench (no remote configured) — protected-branch-repo trial deferred by user decision
- **403 PAT interruptions handled:** 1 (`git push` during task-start bookkeeping), per standing instruction (hard-stop, no diagnosis, retry on confirmation)
