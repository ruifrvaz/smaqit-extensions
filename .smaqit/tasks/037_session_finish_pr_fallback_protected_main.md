---
status: Completed
created: "2026-09-12"
mode: Assisted
started: "2026-09-12"
completed: "2026-09-12"
---

# Session-Finish Falls Back to a PR When Direct Push to origin/main Is Rejected

## Description

Task 036 moved `task-start`/`task-complete`'s bookkeeping commits (task status, `PLANNING.md`,
pending `CHANGELOG.md` entries) off a direct push to `origin/main` onto local `main` only, to fix
a downstream repo needing 6-8 bookkeeping-only PRs per task under required-PR-review branch
protection. That fix is scoped to per-task transitions — it deliberately left `smaqit.session-finish`
untouched.

`session-finish`'s own Step 7 ("Finalize main branch state") still ends every session by attempting
`git push origin main` directly for its own outputs (history file, `.smaqit/compendium.md`,
`.smaqit/references/project-research.md`) — and now, as a direct consequence of task 036, local
`main` will *routinely* be ahead of `origin/main` by an entire session's worth of task-lifecycle
bookkeeping commits that were deliberately never pushed. On an unprotected `main` (this repo), that
push still succeeds exactly as before — confirmed live in the session that shipped task 036. On a
`main`-branch-protected downstream repo, that push is rejected, and today's failure-handling table
(`SKILL.md:118`, `\`git push\` is rejected unexpectedly → STOP. Report the rejection...`) has no
path forward except a manually-authored PR the user has to build by hand — reintroducing the exact
bookkeeping-PR friction task 036 eliminated for individual task transitions, just consolidated into
one end-of-session blocker instead of several scattered ones.

## Issue Triage Context

**Mode:** Skip
**Technologies:** bash (skill scripts), git, GitHub CLI (`gh`), GitHub branch protection
**Platforms/Environments:** N/A — documentation/prose change to `smaqit.session-finish/SKILL.md` only, using `git`/`gh` patterns this codebase already relies on elsewhere (`smaqit.task-complete` already does `gh pr create`/`gh pr view` routinely)
**Features/Integrations:** `smaqit.session-finish`; builds directly on task 036's local-only bookkeeping model for `smaqit.task-start`/`smaqit.task-complete`
**Versions/Constraints:** must not change behavior on an unprotected `main` (this repo) — the direct push stays the first attempt, zero added overhead; must never self-merge the fallback PR; must never auto-resolve a conflict; must not collide with the standing PAT-switch 403 hard-stop instruction (see Design Decisions)

## Design Decisions

- **Fallback only, not a default.** `git push origin main` remains Step 7's first attempt, completely unchanged, in the existing "ahead of `origin/main` with nothing to pull" branch. Only a rejection is inspected further; the happy path (this repo, and any other unprotected `main`) never opens a PR and behaves identically to today. Confirmed by the user explicitly over the "always via PR" alternative.
- **Narrow rejection classification — protected-branch only.** Inspect the push's stderr for protected-branch-specific wording (GitHub's actual text: `GH006`, `protected branch`, `Changes must be made through a pull request`, or an equivalent required-review/required-status-check message). Only *that* classification triggers the new fallback path below.
  - **Every other push failure is untouched** and still hits the existing STOP-and-report path exactly as today — in particular, a 403/permission-denied rejection must **never** be reclassified as a protected-branch fallback. This project's own standing instruction (`CLAUDE.md`) requires a 403 on `git push`/`gh` to hard-stop and ask the user to restore their PAT, with zero diagnosis. That instruction is about `smaqit-extensions`' own dogfooding convention, not something this task can assume every adopting repo also has — but the underlying distinction still matters generically: a 403 means "you don't have push rights at all" (an auth problem to fix out-of-band), while a protected-branch rejection means "you have rights, but this ref specifically requires a PR" (exactly what this task's fallback exists to route around). Conflating the two would silently paper over real auth problems by always falling back to "just open a PR."
- **One reused branch, not one per session.** The fallback pushes local `main`'s current tip to a single well-known branch, `chore/session-bookkeeping-sync`, reused and force-updated across sessions rather than accumulating a new branch+PR every time the direct push is rejected. These commits carry no reviewable "feature," just metadata — a single rolling PR is the right shape, not a growing pile of near-duplicate ones.
- **PR title must never match the release-trigger pattern.** `post-merge-release.yml` fires its tag+release automation on a merged PR titled `Prepare release vX.Y.Z` or `Release vX.Y.Z`. The bookkeeping-sync PR carries no version bump and nothing changelog-worthy — its title (e.g. `chore: sync session bookkeeping`) must deliberately avoid that pattern so merging it never spuriously creates a tag or GitHub Release.
- **Two-phase shape, mirroring `task-complete`'s own PR lifecycle — but session-finish can never self-merge.** A required-PR-review protected branch exists specifically to force a human review before merge; session-finish has no task-owner-approval concept to lean on the way `task-complete`'s Autonomous mode does, so it must never attempt `gh pr merge` under any condition here.
  - **Phase 1 (this session, on rejection):** if an open bookkeeping-sync PR already exists (`gh pr list --head chore/session-bookkeeping-sync --state open`), force-with-lease-push local `main`'s tip onto that same branch to update it in place; otherwise create the branch and open a new PR. Report the PR link and STOP — do not proceed further in Step 7, do not retry the direct push.
  - **Phase 2 (a later session-finish invocation, before attempting the normal Step 7 decision tree):** check whether a bookkeeping-sync PR exists.
    - **Merged** (`gh pr view --json state,mergedAt` reports `MERGED`) → reconcile local `main`: `git fetch origin main && git merge origin/main` (never a fast-forward-only pull — local `main` may have advanced further with additional session/task bookkeeping since the PR branch was last force-pushed, exactly the same reasoning as task 036's own `task-complete` Step 17). A genuine merge conflict is never auto-resolved — abort and report, matching this skill's existing policy everywhere else. On a clean reconcile, continue into the normal Step 7 decision tree for anything left over.
    - **Still open** → report that it's awaiting review and STOP; do not attempt a duplicate push or open a second PR.
    - **No bookkeeping-sync PR exists at all** → proceed through Step 7 exactly as documented today (this is the common case for every session on an unprotected `main`).
- **Never delete the bookkeeping-sync branch or close/self-merge its PR**, in either phase — it is a deliberately long-lived, reused branch, not a per-task branch with the one-shot lifecycle `task-complete` cleans up. This differs from `task-complete`'s own remote-branch-preservation policy only in that there's no branch to *delete*; there's a branch to keep reusing indefinitely.
- **Scope boundary.** This task touches only `smaqit.session-finish/SKILL.md`. It does not touch `smaqit.task-start`/`smaqit.task-complete` (already fixed by task 036) or `smaqit.release-analysis`'s `origin/main` tag-boundary fetch (unrelated, and explicitly out of scope for the same reason task 036 excluded it). `smaqit.session-finish` has no `references/RULES.md` and no generated installer mirror to update directly (`installer/skills/`, `installer/skills-claude/` are gitignored `make sync` output).

## Implementation Steps

1. Rewrite `smaqit.session-finish/SKILL.md` Step 7 (`SKILL.md:91-100`):
   - Keep the existing decision-tree branches (clean/in-sync no-op, different-branch checkout, this-run's-own-files commit, behind-with-no-local-commits fetch+pull) exactly as they are.
   - Before entering that decision tree, add the Phase 2 check described in Design Decisions: look for an existing `chore/session-bookkeeping-sync` PR and resolve merged/open/absent as specified.
   - Change the "ahead of `origin/main` with nothing to pull" branch to attempt `git push origin main` first, exactly as today; on rejection, classify it (protected-branch pattern vs. everything else) and either run the Phase 1 fallback (open/update the bookkeeping-sync PR, report, STOP) or fall through to the existing STOP-and-report failure-handling path unchanged.
2. Update the Failure Handling table (`SKILL.md:109-121`) to add the new protected-branch-rejection row (routes to the Phase 1 fallback, not a bare STOP) while leaving every existing row — including the 403/authentication row — completely unchanged in wording and behavior.
3. Add a short design note (mirroring task 036's own "Local-Only Sessions" note) explaining why the fallback exists, the reused-branch convention, and explicitly stating it must never self-merge or auto-resolve a conflict.
4. Verify in this repo (unprotected `main`): confirm the existing direct-push happy path is byte-for-byte unaffected — no new branch, no PR, no behavior change, matching a live re-run of `session.finish` after this change.
5. Verify against a `main`-branch-protected test repo (mirroring task 036's own verification approach — live if the user opts in, or an equivalent hermetic simulation otherwise, per the same trade-off discussion from task 036): confirm a rejected push correctly opens/updates the bookkeeping-sync PR instead of stopping with no path forward, that a second rejection in a later session updates the same PR rather than opening a duplicate, and that a merged bookkeeping-sync PR is correctly reconciled into local `main` on the next `session.finish` run.
6. Confirm the standing 403/PAT-switch hard-stop behavior (`CLAUDE.md`) is unaffected — a live or simulated 403 during Step 7's push must still hard-stop exactly as before, never falling into the new PR-fallback path.

## Known Issues Triage

**Triaged:** 2026-09-12
**Result:** Skipped — explicitly marked `Mode: Skip` in task Notes.

## Acceptance Criteria

- [x] On an unprotected `main`, `session-finish`'s Step 7 behavior is unchanged — direct push succeeds, no bookkeeping-sync branch or PR is created
- [x] A push rejected for protected-branch reasons (GH006 / "protected branch" / "Changes must be made through a pull request") triggers the Phase 1 fallback: creates or updates the single reused `chore/session-bookkeeping-sync` branch/PR and reports its link, then stops
- [x] A push rejected for any other reason (auth failure, unrelated error) is unaffected and still hits the existing STOP-and-report path — explicitly verified this does not regress the standing 403/PAT-switch hard-stop instruction
- [x] The bookkeeping-sync PR's title never matches the `Prepare release vX.Y.Z`/`Release vX.Y.Z` pattern, so merging it never triggers `post-merge-release.yml`'s tag/release automation
- [x] A second consecutive rejection (a later session) updates the same existing open PR rather than opening a duplicate
- [x] Once the bookkeeping-sync PR merges, the next `session-finish` invocation reconciles local `main` via fetch+merge (never a fast-forward-only pull), tolerating local `main` having advanced further since the PR branch was last updated
- [x] A genuine merge conflict during that reconciliation aborts and reports — never auto-resolved
- [x] `session-finish` never attempts to self-merge the bookkeeping-sync PR under any condition
- [x] The bookkeeping-sync branch/PR is never deleted or closed by this flow — it persists indefinitely, reused across sessions

## Findings

**Implementation approach:**
- Rewrote `session-finish/SKILL.md` Step 7 in place: added an unconditional pre-check for an existing `chore/session-bookkeeping-sync` PR (open → stop and report; merged → reconcile local `main` via fetch+merge, never `--ff-only`; absent → proceed normally), then classified push rejections in the "ahead of origin/main" branch — protected-branch wording (GH006, "protected branch", "Changes must be made through a pull request") falls back to a `git fetch` + `git push --force-with-lease origin main:refs/heads/chore/session-bookkeeping-sync` refspec push (creates the branch on first use, updates it in place thereafter, no local branch ever created) and opens/updates a PR titled `chore: sync session bookkeeping`; every other rejection (403 most of all) is untouched.
- Added `tests/skills/test-session-finish-bookkeeping-sync.sh` (wired into `make test`): hermetic mechanical tests for the refspec create-then-update push, the merge-based reconciliation tolerating local `main` ahead, a genuine conflict aborting cleanly, plus contract assertions on the documented SKILL.md text (including the never-reclassify-403 guarantee and the release-trigger-avoidance of the PR title).
- Verified `make test` (15 suites) and `make smoke-test` both pass — no regression to this repo's own unprotected-`main` behavior.
- Per user feedback mid-task, removed an initial standalone "## Bookkeeping-Sync Fallback" section and folded its rationale directly into Step 7's own prose instead — the mechanism now lives entirely where it's used, with no separate cross-referenced section.

**Decisions made:**
- Live main-branch-protected GitHub repo trial was offered and declined again (same call as task 036) — accepted the hermetic test's mechanical coverage (refspec push, reconciliation merge, conflict-abort) plus the contract assertions on the SKILL.md text as sufficient verification. Unlike task 036, none of this task's acceptance criteria literally required the live trial, so no criterion was revised to accommodate the decision.
- Used a single reused `chore/session-bookkeeping-sync` branch (force-with-lease refspec push, no local branch ever created) rather than a per-session branch, per the task's own design — keeps this as one rolling PR instead of an accumulating pile.

**Blockers encountered:**
- None.

**Follow-up identified:**
- The literal main-branch-protected GitHub repo trial remains unverified live for this task too (same residual gap as task 036's own criterion 8). If a downstream repo ever reports the fallback not firing or misbehaving, that live trial is the next diagnostic step.

## Files to Create / Modify

| File | Action |
|------|--------|
| `skills/smaqit.session-finish/SKILL.md` | Modify |
| `tests/skills/test-session-finish-bookkeeping-sync.sh` | Create (not in original plan — added for hermetic mechanical coverage) |
| `Makefile` | Modify (wire the new test into `test`/`smoke-test`) |

## Notes

- Origin: surfaced directly from task 036's own completion session — the user asked "does that mean
  we have to push from local main to origin main? what if there is branch protection on origin?"
  immediately after confirming task 036's fix was live via `smaqit-extensions update`, and the
  analysis in that conversation is the basis for this task's Design Decisions.
- The user explicitly chose the "fallback only" design (direct push first, PR only on rejection)
  over "always via PR" when asked — see Design Decisions' first bullet.
- Task 036's own verification of the protected-repo scenario was itself deferred (its acceptance
  criterion 8 was revised to a local concurrency bench instead, on user approval) — this task's own
  Implementation Step 5 inherits that same open question about how rigorously to verify against a
  real protected-branch GitHub repo versus an equivalent simulation, and should resolve it the same
  way (ask the user) rather than assume either approach.
