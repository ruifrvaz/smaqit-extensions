# Tag-Based Release Boundary Detection

**Date:** 2026-08-17
**Session focus:** Planning, implementing, and shipping task 031 — replacing `release-analysis`' release-marker-commit boundary search with a git-tag lookup, and splitting the boundary SHA from the version baseline so out-of-order per-task tags cannot regress a suggested version. Released as v2.0.2 via PR #129.
**Tasks completed:** 031 — Fix Release-Analysis Boundary Detection for PR-Gated Releases
**Tasks referenced:** 032 and 033 (both completed concurrently by a peer session in the same checkout), 002, 028, 007, 010 (untouched)

## Actions Taken

- Ran `smaqit.session-start`. Found v2.0.0's release workflow still building mid-read; confirmed it published with all 5 binaries. Flagged two apparent blockers: task 032 sat at `PR Open` despite its PR having merged, and the global install was v1.17.2 — two releases behind, with a lifecycle resolver that still parsed `**Status:**` bold-markdown against YAML-frontmatter task files.
- Ran `smaqit.task-plan 031`. Scored the task Complex (Design Decisions and Implementation Steps both `TBD`). Discovery — run inline rather than via subagents — established three things the task file had not anticipated: the boundary had been resolving to `fb133be Release v1.17.1` and was **three** releases stale rather than one; tags were uniformly correct across both release eras (`v1.16.0`→batch-era merge, `v1.17.1`→literal marker commit, `v2.0.0`→PR-gated merge); and Step 1d derived `<last-version>` *from the boundary commit*, conflating two questions that diverge once tags land out of numeric order.
- Presented both decisions to the user via structured options with previews. Both recommendations accepted: git tags as the mechanism, and splitting boundary SHA from version baseline.
- User asked what "blocked until `smaqit-extensions update` + task 032 Phase 2" meant. Checked rather than re-asserted: ran the stale v1.17.2 resolver against task 031 and it returned exit 0 with correct branch, kind, and mode — because task 031 is standalone, parentless, and Assisted, so every empty-defaulted field coincided with the truth. The correct claim was that the stale install would have blocked `task-complete` (whose `find_active_task` gates on status), not `task-start`. Both conditions were moot by then anyway: the peer session had updated the install to v2.0.0 and completed task 032.
- Ran `smaqit.task-start 031` end to end: owner resolution, branch and sparse worktree, research-map task block (9 URLs verified; Bash's gnu.org host unreachable, resolved to man7.org matching the map's own precedent), and triage.
- Implemented in the worktree across four phases: `release-analysis` Steps 1a–1d rewritten to tag-primary with a two-level fallback chain; `release-prepare-files` Step 2A given the same treatment plus realignment from local `HEAD` to `origin/main`; a new `tests/skills/test-release-analysis-boundary-detection.sh` over three fixture repositories; and the Makefile target wired in. Both skills' Important Notes had asserted marker commits were "more reliable than git tags" — inverted and corrected.
- Verified the new test is a genuine regression guard by running it against the pre-fix skills pulled from `main`; it failed as intended. `make test` and `make smoke-test` both passed.
- Ran `smaqit.task-complete 031` Phase 1: Findings written, 9/9 criteria checked off, implementation committed, version computed as **v2.0.2** (PATCH; `v2.0.1` already claimed by task 033's PR #128), PR #129 opened with its title verified against `post-merge-release.yml`'s `startsWith` contract, pending changelog entry pushed to `main`, then promoted on the branch. Stopped per Assisted mode.
- After user confirmation of merge, ran Phase 2: merge verified via `gh pr view` (`d8df267`), release v2.0.2 confirmed published with 5 assets, task flipped to `Completed`, worktree removed, local branch force-deleted, remote branch preserved.

## Problems Solved

- **Boundary detection blind to every PR-gated release.** Under the per-task model, `Prepare release vX.Y.Z` exists only as a PR title; GitHub's merge commit (`Merge pull request #NNN from …`) matches no marker pattern. Every task completed since v1.17.2 had computed its changelog delta against a stale boundary. Fixed read-side only, so the three already-landed releases became visible retroactively with no release-time machinery changes.
- **Latent wrong-version bug in the version baseline.** Deriving `<last-version>` from the boundary commit means that when tags land out of numeric order — which per-task releases produce by design, since PRs merge in review order — the next suggestion can fall *below* an already-released version. Step 1e's pending-claim check cannot catch it, because by then the collision is released and promoted rather than pending. Split into an independent highest-reachable-tag lookup.
- **Verification that proves the bug rather than restating the fix.** Replaying task 030's completion point on real history: the old regex yields `fb133be Release v1.17.1`, the fix yields `v1.17.2` / `219d67c` — reproducing the exact failure that had required a manual override.
- **Concurrent-session collisions in a shared checkout.** A peer session worked the same primary checkout throughout, completing task 032 and creating, starting, and shipping task 033. Its uncommitted task-033 state was committed as its own commit before touching `PLANNING.md`, so neither session's work was swept into the other's. All metadata pushes landed on the first attempt.

## Decisions Made

- Git tags over the two rejected alternatives. A release-time marker commit would add a CI push to `main` and — decisively — cannot repair releases already landed. A `gh` PR-title lookup needs network and auth merely to compute a version and is blind to local `release-git-local` releases.
- Boundary SHA and version baseline kept as genuinely separate lookups, accepting one extra command and one extra acceptance criterion to close a latent bug the release model actively produces.
- Scope widened to realign `release-prepare-files` Step 2A-2 from local `HEAD` to `origin/main` — surfaced to the user as a scope decision, left unanswered, then taken as a judgment call and flagged explicitly as reversible.
- Regression coverage written as a reference implementation plus `rg` contract assertions, since skills are Markdown instructions rather than executable code — matching the precedent in `test-release-analysis-pending-versions.sh`. The test asserts the *old* regex disagrees with the tag lookup on mixed-era history.
- Triage recorded as Advisory with an explicit categorization limitation rather than a clean Clear: no resolved repository is an authoritative tracker for `git describe`/`git tag` semantics.

## Files Modified

- `skills/smaqit.release-analysis/SKILL.md` — Steps 1a–1d rewritten to tag-primary with fallback chain; Important Notes corrected; `latest_version` output field redefined; version 0.8.0 → 0.9.0.
- `skills/smaqit.release-prepare-files/SKILL.md` — Step 2A-1/2A-2 same treatment plus `origin/main` realignment; Important Note corrected; version 0.7.0 → 0.8.0.
- `tests/skills/test-release-analysis-boundary-detection.sh` — created; three fixture repositories (mixed-era, out-of-order tags, tagless) plus contract assertions.
- `Makefile` — new test target registered in `.PHONY` and the `test` aggregate.
- `CHANGELOG.md` — `[2.0.2]` entry (pending annotation on `main`, promoted on the PR branch).
- `.smaqit/tasks/031_*.md` — Design Decisions and Implementation Steps resolved from `TBD`, acceptance criteria expanded 4 → 9, triage block, Findings, status transitions.
- `.smaqit/tasks/PLANNING.md` — task 031 status transitions; task 033's row committed on the peer session's behalf.
- `.smaqit/tasks/033_*.md` — committed (created by the peer session, left untracked).
- `.smaqit/references/project-research.md` — task 031 research block.
- `smaqit-extensions.code-workspace` — regenerated by worktree creation and removal.

## Next Steps

- **Potential bug — release-notes pollution during concurrent PR-gated releases.** v2.0.1's published GitHub Release notes carry task 031's still-pending entry, annotation and all (`(pending v2.0.2 · PR #129)`), and `CHANGELOG.md` now lists `## [2.0.1]` above `## [2.0.2]`, contrary to Keep a Changelog's newest-first convention. The user resolved a `CHANGELOG.md` merge conflict **manually** while merging PR #128, so this is not confirmed to be an automatic promotion race — a stored memory note attributing it to a line-based git merge is at least partly inaccurate on that point. Left as-is at the user's direction. Worth investigating whether the mechanism should avoid producing that conflict at all when two per-task releases are in flight, since a released section retaining a `(pending …)` annotation is a signal the promotion step can silently no-op.
- Task 002 ("Fix Changelog Extraction for Cumulative Releases") plausibly overlaps what shipped here and may now be partly or wholly subsumed — re-read before starting.
- `github-issues.sh` resolves plausible-but-wrong repositories for tools not hosted on GitHub (Bash → `dylanaraps/pure-bash-bible`, GitHub Actions → `actions/starter-workflows`, `git/git` being a read-only mirror that accepts no issues). Triage silently produces weak coverage for such tasks; possibly worth its own task.
- Tasks 028, 002, 007, 010 remain Not Started.

## Session Metrics

- **Duration:** Full session, single continuous thread spanning two dates
- **Tasks completed:** 1 (031), planned and shipped in the same session
- **Releases shipped:** 1 (v2.0.2, PATCH, PR #129)
- **Files modified/created:** 10 (2 skills, 1 new test, Makefile, CHANGELOG, 3 task-state files, research map, workspace file)
- **Test coverage added:** 5 assertion groups across 3 fixture repositories; verified failing against pre-fix skills
- **Concurrency:** 4 peer sessions active; 1 working the same checkout, shipping v2.0.1 in parallel with this session's v2.0.2
- **Corrections made mid-session:** 1 (an overstated "blocked" claim, checked and narrowed rather than restated)
