# Branch-Born Release Mechanism Verified

**Date:** 2026-09-15
**Session focus:** Diagnosed and fixed a designed-but-unguarded rebase conflict in `task-complete`'s per-task release mechanism, rejected the first fix on review as a workaround rather than a repair, redesigned the mechanism structurally, and proved the redesign live end-to-end.
**Tasks completed:** 039 — Guard Against Implementer-Written CHANGELOG.md Conflicts (shipped v2.1.1, PR #138); 040 — E2E Live Verification of Task 039's Release Mechanism (shipped v2.1.2, PR #139)
**Tasks referenced:** None — no other task touched this session

## Actions Taken

- Started with `smaqit.session-start`; presented the four Not Started tasks and recommended task 002. The user instead pasted a real incident report: an agent in a consuming project hit `task-complete` Step 13's "rebase conflict — STOP and report, never auto-resolve" hard stop, caused by its own implementation commit and `task-complete`'s pending-`CHANGELOG.md`-entry commit both touching `[Unreleased]`.
- Diagnosed the root cause directly against source: the conflict-on-rebase mechanism had existed since task 027 (2026-08-14), unchanged in shape by task 036's later move of the rebase target from `origin/main` to local `main`; nothing in any skill or template told an implementing agent not to hand-write a `CHANGELOG.md` entry during implementation. Proposed and (on approval) implemented a two-location instruction-level guardrail (`task-start` Step 11, `AGENTS.template.md`) via the normal `task.plan` → `task.create` → `task.start` pipeline as task 039, verified with `make test`/`make smoke-test` clean.
- The user challenged the finished implementation directly: the `AGENTS.template.md` guardrail looked like an ad hoc circuit breaker on something foundationally wrong, and asked for an assessment of what was actually broken. Investigated the full mechanism (task-complete, release-analysis, release-approval, release-prepare-files, release-git-pr, both hermetic tests) and found three verified structural problems: `[Unreleased]` had two writers on one line range (the branch's own commit and `main`'s Step 12); the version-claim registry had been silently dead since task 036 (Step 1e read `origin/main`'s `CHANGELOG.md` while the writing commit moved to local `main` only); and Step 13's rebase onto local `main` leaked unpushed bookkeeping commits into release PRs — verified directly against `origin/main`'s history (tasks 037 and 038's bookkeeping had ridden in through their own PR branches).
- Stashed the rejected guardrail implementation, re-planned task 039 in place via `task.plan 039` (Mode B) as a structural fix: a task's changelog entry is now authored directly on its own branch after the PR exists (folding in any `[Unreleased]` bullets the implementer already wrote, rather than guarding against them) and plain-pushed — no rebase, no force-push, no write to `main`. The version-claim registry became the set of open PRs titled `Prepare release vX.Y.Z`, read live via `gh pr list --json` and filtered client-side. `task-start` now branches from freshly fetched `origin/main` instead of local `main`, closing the bookkeeping-leak independently of removing the rebase.
- Rewrote six skills (`task-complete`, `task-start`, `release-analysis`, `release-approval`, `release-prepare-files`, `release-git-pr`), synced all three `RULES.md` copies, replaced `test-release-analysis-pending-versions.sh` with a renamed `test-release-analysis-claimed-versions.sh` carrying a new fold-algorithm reference test and a repo-wide `(pending v` absence guard, rewrote the affected `compendium.md` entries, and rebuilt/reinstalled the binary locally so `task.complete 039` itself would run the new mechanism live rather than the old installed one.
- Ran `task.complete 039` for real: Phase 1 opened PR #138 titled `Prepare release v2.1.1`, correctly found no false version-claim collision against two unrelated pre-existing open PRs (#65, #61 — Copilot-agent PRs for tasks 007/010, neither reflected in local `PLANNING.md`), wrote `## [2.1.1]` on the branch, plain-pushed. User merged and confirmed the local binary updated to v2.1.1; ran Phase 2 (merge, cleanup) to close out the task cleanly.
- Planned a second task (040) specifically to prove the two pieces of the redesign task 039's own dogfood run never exercised: `task-start`'s new `origin/main`-branching fix (039's branch predated that fix) and the live on-branch fold of an implementer's own `[Unreleased]` bullet (039 shipped with an empty one). Exploited the natural precondition that local `main` sat 5 commits ahead of `origin/main` at the time. Ran the full cycle for real — `task.start 040`, synthetic no-op implementation (a permanent Makefile comment plus a deliberate `[Unreleased]` bullet), `task.complete 040` Phase 1 (PR #139) — verifying each claim with direct evidence (`git merge-base`, `git log origin/main..<branch>`, `gh pr view`, branch `git reflog`) rather than trusting the skill's own report. User merged; ran Phase 2, polled `post-merge-release.yml` to completion, and independently confirmed the `v2.1.2` tag and GitHub Release via `gh release view`, with release notes matching the branch's changelog section exactly.
- Ran `smaqit.session-finish` and `smaqit.session-title` to close out the session.

## Problems Solved

- **A designed-in rebase conflict with no prevention path**: `task-complete`'s pending-`CHANGELOG.md`-entry mechanism (task 027) put two writers on the same `[Unreleased]` line range — an implementer's branch commit and `main`'s own pending-entry commit — with no guardrail against the collision and no way to resolve it except a hard stop. Root-caused to the mechanism's own design, not an isolated instruction gap.
- **A version-claim registry that had been silently broken since task 036**: `release-analysis`/`release-approval` read pending annotations from `origin/main`'s `CHANGELOG.md`, but the writing commit had moved to local-`main`-only, so concurrent-task version collision detection had zero real coverage for over a month with no test catching it.
- **A bookkeeping leak into release PRs**: Step 13's rebase onto local `main` dragged any unpushed task/session bookkeeping commits sitting there into the PR being reviewed, contradicting task 036's own "bookkeeping commits are never pushed" contract — verified concretely against `origin/main`'s actual merge history for PRs #136 and #137.
- **An ad hoc fix rejected before it shipped**: the first implementation (an instruction-level "don't touch `CHANGELOG.md`" guardrail) would have reduced how often the conflict fired without addressing any of the three structural causes. Caught on review before merge, not after.

## Decisions Made

- **Move the changelog entry to the branch, not guard against touching it**: eliminates the dual-writer conflict at the source rather than papering over it — an implementer's `[Unreleased]` bullet becomes input to fold in, not an error to prevent.
- **Claim registry = live open PR titles, not a `CHANGELOG.md` annotation**: remote, always current by construction, and reuses `gh` (already a hard dependency of PR creation) — no new dependency, no possibility of a dead registry.
- **`task-start` branches from freshly fetched `origin/main`, not local `main`**: closes the bookkeeping-leak class of bug independently of removing the rebase, since a future change could reintroduce some other main-touching step.
- **Task-complete's "STOP and report, never auto-resolve" policy on git conflicts is retained everywhere it already existed** — this was a prevention/redesign fix, not a relaxation of that policy.
- **Task 039 was re-planned in place (same number, same PR-continuity framing) rather than abandoned and recreated** — the branch and worktree were reused; the rejected implementation was stashed and later dropped once the redesign shipped.
- **A dedicated task (040) verifies the redesign live rather than trusting the hermetic tests alone**: the hermetic tests exercise the fold algorithm and file contracts in isolation; only a real `task-start`/`task-complete` run against this repo's own GitHub remote, at a moment engineered to reproduce the original bug's precondition, proves the fix end to end. Content was deliberately synthetic and permanent (not reverted afterward) to keep the verification isolated from real backlog outcomes.

## Files Modified

- `skills/smaqit.task-complete/SKILL.md`, `references/RULES.md` — Phase 1 rewritten: on-branch changelog write and plain push replace the pending-entry commit and rebase; Local-Only Sessions, Step 17/21 text, and the Abandon Path updated to match
- `skills/smaqit.task-start/SKILL.md`, `references/RULES.md` — Step 3 branches from fetched `origin/main`
- `skills/smaqit.task-list/references/RULES.md` — synced byte-identical
- `skills/smaqit.release-analysis/SKILL.md` — Step 1e is now claimed-version awareness via `gh pr list --json`
- `skills/smaqit.release-approval/SKILL.md` — Step 4b's defense-in-depth re-check reads the same PR-title registry
- `skills/smaqit.release-prepare-files/SKILL.md` — Pending Entry Convention/Mode replaced by Task-Release Mode
- `skills/smaqit.release-git-pr/SKILL.md` — invocation-from-task-complete section updated
- `tests/skills/test-task-complete-pr-lifecycle.sh` — pending-write/force-with-lease assertions replaced with on-branch/plain-push assertions
- `tests/skills/test-release-analysis-pending-versions.sh` → `tests/skills/test-release-analysis-claimed-versions.sh` (renamed, new fold-algorithm reference test, repo-wide `(pending v` absence guard)
- `Makefile` — test target rename; task 040's permanent verification-marker comment
- `.smaqit/compendium.md` — task-complete Phase 1 entry rewritten; new entry recording the mechanism and why the `main`-born design was retired
- `CHANGELOG.md` — `## [2.1.1]` and `## [2.1.2]` sections (both written on their respective task branches, per the new mechanism)
- `.smaqit/tasks/039_guard_against_implementer_changelog_conflicts.md`, `040_e2e_verify_task_039_release_mechanism.md` — full lifecycle (created, re-planned in 039's case, started, completed)
- `.smaqit/tasks/PLANNING.md` — tasks 039 and 040 moved Active → Completed
- `.smaqit/references/project-research.md` — task blocks for both tasks

## Next Steps

- Tasks 028, 002, 007, 010 remain Not Started, untouched this session.
- **Two open PRs discovered mid-session are not tracked in local `PLANNING.md`**: #65 (`copilot/implement-task-007`, "smaqit MCP server PoC") and #61 (`copilot/implement-task-010`, "Copilot plugin marketplace distribution") — both correspond to Not Started tasks, apparently assigned to GitHub's Copilot coding agent outside this project's own task lifecycle. Worth reconciling before they go stale or collide with anything.
- No other follow-up filed. The redesigned release mechanism is now verified working end to end with zero discrepancies found.

## Session Metrics

- **Duration:** Full session, single continuous thread
- **Tasks completed:** 2 (039, 040)
- **Tasks abandoned:** 0
- **Releases shipped:** 2 — v2.1.1 (PATCH, PR #138, the structural redesign) and v2.1.2 (PATCH, PR #139, its live end-to-end verification)
- **Tests written/changed:** hermetic test suite rewritten for the new mechanism (`test-task-complete-pr-lifecycle.sh` updated, `test-release-analysis-claimed-versions.sh` new); `make test` (15 suites) and `make smoke-test` both passing after every change
- **Live verification:** two full real `task-start` → `task-complete` Phase 1 → PR merge → Phase 2 cycles against this repo's own GitHub remote, each independently verified with direct evidence (merge-base, commit-range diffs, PR title/state, branch reflog, tag/release existence) rather than trusted from the skills' own reports
- **Design gaps caught before shipping:** 1 (the first guardrail-based fix, rejected on review before merge, replaced with the structural redesign)
