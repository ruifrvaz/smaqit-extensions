---
status: PR Open
pr: 129
mode: Assisted
created: "2026-08-15"
started: "2026-08-16"
---

# Fix Release-Analysis Boundary Detection for PR-Gated Releases

## Description

`smaqit.release-analysis`'s Step 1c boundary search (`git log origin/main --format="%H %s" | grep -iE "^[0-9a-f]+ (Prepare release|Release) v[0-9]+\.[0-9]+\.[0-9]+$"`) looks for a commit whose message exactly matches `Prepare release vX.Y.Z` or `Release vX.Y.Z`. This worked for the old batch-release flow, where `release-git-pr` actually created such a commit. Since task 027's PR-gated per-task release mechanism shipped, that exact string only ever exists as a PR title (enforced by `task-complete` Step 11 / `release-git-pr` Step 4) — GitHub's default merge commit message is `Merge pull request #NNN from owner/branch`, which never matches the regex.

Discovered live while completing task 030: the search skipped past `v1.17.2` (task 029's PR-gated release, tagged at merge commit `219d67c`) entirely and fell back to `v1.17.1` (the last pre-PR-gated release), which would have caused task 030's changelog delta and severity/version computation to incorrectly re-include all of task 029's already-released changes. Worked around manually for task 030 by overriding the boundary to the correct merge commit SHA; this task fixes the underlying detection so every future `task-complete` run computes the correct boundary automatically.

## Issue Triage Context

**Mode:** Auto
**Technologies:** Bash, git, GitHub CLI (gh), GitHub Actions
**Platforms/Environments:** Any consumer project using smaqit-extensions' PR-gated task-complete flow
**Features/Integrations:** smaqit.release-analysis, smaqit.task-complete, post-merge-release.yml
**Versions/Constraints:** Must not break the existing batch-mode (smaqit.release-git-local) boundary search; must handle mixed old-style and new-style release history in the same repo

## Design Decisions

Resolved via `smaqit.task-plan` on 2026-08-15. All three candidate approaches were evaluated against this repository's real history.

- **Git tags are the primary boundary; the marker-commit regex is demoted to a fallback.** Verified correct across both eras: `v1.16.0`→`6e8a2c2` (batch-era merge), `v1.17.1`→`fb133be` (literal marker commit), `v2.0.0`→`41c7c88` (PR-gated merge). Every release carries a correct tag regardless of which flow produced it. Lookup order becomes: tag → marker regex (tagless repo) → `v0.0.0`/`v0.1.0` (new repo).
- **Rejected: writing an explicit marker commit at release time.** Would add a commit to `main` and a CI push per release, and — decisively — cannot repair the three releases already landed (v1.17.2, v1.18.0, v2.0.0), since their markers cannot be added retroactively.
- **Rejected: querying merged PR titles via `gh`.** Requires network and auth merely to compute a version, and is blind to local `release-git-local` releases, which never open a PR.
- **The read-side-only fix repairs existing history retroactively.** No release-time machinery changes, so the three already-landed PR-gated releases become visible immediately.
- **Boundary SHA and last-version become two separate lookups.** `<boundary-sha>` comes from the topologically-latest reachable tag (`git describe --tags --abbrev=0 origin/main`) — the correct changelog delta. `<last-version>` comes from the highest reachable tag (`git tag --merged origin/main --sort=-v:refname | head -1`) — a safe version baseline. Under the per-task release model, tags land out of numeric order by design (the compendium states this explicitly), at which point the two diverge: if PR #200 claims v2.1.0 and merges first, then PR #201 claims v2.0.1 and merges second, the topologically-latest tag is v2.0.1 while the highest is v2.1.0. Deriving the version baseline from the boundary commit would then suggest v2.0.2 — *below* the already-released v2.1.0. Step 1e's pending-claim check does not catch this, because the colliding version is already released and promoted, no longer a pending annotation.
- **Both skills are fixed**, resolving this task's original "modify if" hedge. `release-prepare-files` Step 2A-2 carries the identical regex; in a mixed-era history its batch path skips back to the last literal marker, past every PR-gated release. Its Pending Entry Mode is unaffected — `task-complete` never reaches Step 2A.
- **`release-prepare-files` Step 2A-2 is also realigned to search `origin/main`** rather than local `HEAD`, matching the staleness hardening `release-analysis` already received. Scope widening accepted deliberately: it is a one-line change to a line already being rewritten.
- **Tags are fetched explicitly** (`git fetch --tags --force --quiet`) in the deepen step. This neutralizes the shallow-clone objection that originally motivated preferring marker commits over tags, and `--force` prevents a moved tag leaving a stale local ref.
- **Skills are markdown instructions, not executable code**, so regression coverage takes the form of a reference implementation run against fixtures plus `rg` contract assertions against the SKILL.md files — the pattern already established by `tests/skills/test-release-analysis-pending-versions.sh`.

## Implementation Steps

**Phase 1 — `smaqit.release-analysis` (core fix)**

1. Step 1a: add `git fetch --tags --force --quiet` beside the existing fetch/deepen commands, with a note explaining that tags must be fetched explicitly for the boundary lookup to be reliable in a shallow clone.
2. Rewrite Step 1c: primary lookup `git describe --tags --abbrev=0 origin/main`, then `git rev-list -n1 <tag>` to resolve `<boundary-sha>`. Demote the existing marker regex to fallback #1 (tagless repo); keep `v0.0.0`→`v0.1.0` as fallback #2 (new repo).
3. Carry Step 1b's Batch-mode edge case across to the tag path: today it reads "HEAD is itself a release marker → take the second entry"; the tag equivalent is "if the boundary tag points at the analysis tip itself, step back one tag." (Depends on step 2.)
4. Rewrite Step 1d: derive `<last-version>` from `git tag --merged origin/main --sort=-v:refname | head -1` instead of parsing the boundary commit message, documenting why the two lookups can diverge under out-of-order per-task tags.
5. Correct the Important Notes block (~lines 199–201), which currently asserts marker commits are canonical and "more reliable than git tags" — that claim is now inverted.
6. Bump skill version `0.8.0` → `0.9.0`.

**Phase 2 — `smaqit.release-prepare-files`** (parallel with Phase 1)

7. Apply the same tag-primary / regex-fallback structure to Step 2A-2 (line 102) and its Important Note (~line 277), and realign the search from local `HEAD` to `origin/main`.
8. Bump skill version `0.7.0` → `0.8.0`.

**Phase 3 — regression coverage**

9. Create `tests/skills/test-release-analysis-boundary-detection.sh`, modeled on `test-release-analysis-pending-versions.sh`: build a fixture repo with mixed-era history (a literal `Release vX.Y.Z` commit, PR-gated merge commits, tags on both), run a reference implementation of the new Step 1c/1d against it, and assert both the correct boundary and the correct last-version — including the out-of-order-tag divergence case. Add `rg` contract assertions that both SKILL.md files document the tag-primary algorithm and its fallbacks.
10. Wire the new target into the `Makefile` `.PHONY` line (line 1), its own target block (after line 36), and the `test` aggregate (line 38). (Depends on step 9.)

**Phase 4 — verification**

11. Replay the historical failure: at task 030's completion point the old regex yields `fb133be Release v1.17.1`, while `git describe --tags --abbrev=0 898305b~1` yields `v1.17.2`. This reproduces the exact failure that required a manual override and demonstrates the fix correcting it.
12. Run `make test` and `make smoke-test`; confirm the marker-regex fallback still fires against a tagless fixture and batch mode is unregressed.

## Known Issues Triage
**Triaged:** 2026-08-16
**Tools searched:** Git, GitHub CLI (gh), GitHub Actions
**Result:** Advisory

### Advisory Issues
- [#12800 `pr create` fails when local branch name differs from upstream](https://github.com/cli/cli/issues/12800) — `cli/cli` — opened 2026-02-27 — bug, priority-3, core, gh-pr, stale
- [#10509 `gh pr status` returns error message `no remote for "<branch name>@push" found in "origin"`](https://github.com/cli/cli/issues/10509) — `cli/cli` — opened 2025-02-27 — bug, priority-3, gh-pr

Neither touches boundary detection. Both are recorded only because `task-complete`'s PR flow — which this task calls but does not modify — sits on the affected `gh pr` surface.

### Historical (Closed)
- [#1137 Question: workflow_run event to filter by tags](https://github.com/actions/starter-workflows/issues/1137) — `actions/starter-workflows` — closed 2022-01-05

### Unresolvable Tools
- Bash — the helper resolved `dylanaraps/pure-bash-bible`, a tips repository, not an authoritative tracker. Bash upstream uses GNU Savannah and the `bug-bash` mailing list, not GitHub issues, so no meaningful search exists. Not searched.

### Search Warnings
- `git/git` open and closed searches both returned zero results, but the repository is a **read-only mirror that does not accept GitHub issues** (Git development happens on the `git@vger.kernel.org` mailing list). The empty result is uninformative and must not be read as evidence of absence.
- `actions/starter-workflows` is a workflow-template gallery, not the GitHub Actions platform tracker; its results carry no signal about workflow-trigger or tag semantics.

### Categorization Limitation
No resolved repository is an authoritative tracker for the specific mechanism this task changes — `git describe` / `git tag` ordering semantics. Triage coverage for this task is therefore weak, and the Advisory result reflects absence of evidence rather than evidence of absence. The task's own risk is contained: the change is confined to this repository's own Markdown skill instructions and a Bash test fixture, with behavior verified directly against real local history (see Implementation Steps, Phase 4).

## Acceptance Criteria

- [x] `release-analysis`'s Step 1c reliably finds the correct boundary for a repo whose most recent release went through the PR-gated flow (task 027+), without requiring manual override
- [x] Works correctly for a mix of old-style batch releases (literal `Release vX.Y.Z`/`Prepare release vX.Y.Z` commits) and new-style PR-gated releases (title-only, no matching commit) in the same history
- [x] No regression for the existing batch-mode boundary search used by `release-git-local`
- [x] Verified against this repo's own real history — replaying task 030's completion point yields `v1.17.2` where the old regex yielded `v1.17.1` (`fb133be`), and the current tip resolves to `v2.0.0` (`41c7c88`)
- [x] Falls back to the marker-commit regex in a tagless repo, and to `v0.0.0`/`v0.1.0` in a repo with neither tags nor markers
- [x] `<boundary-sha>` and `<last-version>` are derived from separate lookups, so an out-of-order tag sequence never produces a version baseline below an already-released version
- [x] `release-prepare-files` Step 2A-2 carries the same tag-primary detection and searches `origin/main` rather than local `HEAD`
- [x] Regression test covers mixed-era history and the out-of-order-tag divergence, and is wired into `make test`
- [x] `make test` and `make smoke-test` pass

## Findings

**Implementation approach:**
- Replaced the marker-commit regex with `git describe --tags --abbrev=0 origin/main` → `git rev-list -n1` in `release-analysis` Step 1c, demoting the regex to Fallback 1 and adding `v0.0.0`/`v0.1.0` as Fallback 2.
- Split Step 1d into an independent lookup (`git tag --merged origin/main --sort=-v:refname | head -1`) rather than parsing the boundary commit message.
- Added `git fetch --tags --force` to Step 1a, which is what makes the tag approach safe in the shallow clones that originally motivated preferring commits.
- Applied the same structure to `release-prepare-files` Step 2A-1/2A-2 and corrected both skills' Important Notes, which asserted the now-inverted claim that marker commits are "more reliable than git tags."
- Wrote `tests/skills/test-release-analysis-boundary-detection.sh` as a reference implementation over three fixture repos (mixed-era, out-of-order tags, tagless), since skills are Markdown instructions rather than executable code — matching the precedent set by `test-release-analysis-pending-versions.sh`.

**Decisions made:**
- Tags over the two rejected alternatives: a release-time marker commit cannot repair the three releases already landed and would add a CI push to `main`; `gh` PR-title lookup needs network and auth to compute a version and is blind to local `release-git-local` releases.
- Boundary and version baseline kept as genuinely separate lookups. Under per-task releases, PRs merge in review order rather than version order, so the topologically-latest and highest-numbered tags legitimately diverge; conflating them lets the next suggestion regress below an already-released version, which Step 1e cannot catch because the collision is released rather than pending.
- Scope widened to realign `release-prepare-files` Step 2A-2 from local `HEAD` to `origin/main` — flagged to the user as a scope decision before implementing, and accepted as a one-line change to a line already being rewritten.
- Test asserts the *old* regex disagrees with the tag lookup on mixed-era history, so the test proves the bug rather than merely agreeing with the new implementation.

**Blockers encountered:**
- A 403 on `git push origin main` interrupted the pre-start commits. Both commits were held locally and the push succeeded on retry without any workaround; the underlying cause (fine-grained PAT scope) was diagnosed but not conclusively resolved, and it recurred from the same cause that kept task 032's fix out of PR #126.
- Concurrent session activity in the same primary checkout throughout: task 032 was completed and task 033 created, started, and moved to `PR Open` by a peer session mid-task. Handled by committing the peer's uncommitted task-033 state as its own commit before touching `PLANNING.md`, so neither session's work was swept into the other's.

**Follow-up identified:**
- Task 002 ("Fix Changelog Extraction for Cumulative Releases") plausibly overlaps this fix and may now be partly or wholly subsumed — worth re-reading before starting it.
- Triage coverage for this task was weak: no resolved repository is an authoritative tracker for `git describe`/`git tag` semantics (`git/git` is a read-only mirror, Bash upstream is not on GitHub, GitHub Actions resolved to the template gallery). The `github-issues.sh` resolver returning a plausible-but-wrong repository for such tools may be worth its own task.
- The recurring `git push` 403 on `main` is unresolved and has now cost time in two separate tasks; it warrants its own investigation.

## Files to Create / Modify

| File | Action |
|------|--------|
| `skills/smaqit.release-analysis/SKILL.md` | Modify — Steps 1a–1d (lines 28–74), Important Notes (~199–201); version `0.8.0` → `0.9.0` |
| `skills/smaqit.release-prepare-files/SKILL.md` | Modify — Step 2A-2 (line 102) and Important Note (~line 277); version `0.7.0` → `0.8.0`. Confirmed to share the bug |
| `tests/skills/test-release-analysis-boundary-detection.sh` | Create — mixed-era fixture repo, reference implementation, contract assertions |
| `Makefile` | Modify — register the new test target (lines 1, 36–38) |

## Notes

Filed directly out of task 030's completion (`smaqit.task-complete` Step 10), after the user chose to manually override the boundary for task 030 itself rather than block its completion on this fix. Not urgent — every task since v1.17.2 has presumably been affected, but the practical consequence so far has only been an inflated/incorrect changelog delta, not a wrong version bump (severity assessment tends to be conservative regardless). Worth prioritizing before too many more tasks complete against the wrong boundary.
