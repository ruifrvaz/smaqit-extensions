---
status: Not Started
created: "2026-08-15"
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

TBD — to be confirmed during assessment. Candidate approaches to evaluate:
- **Match git tags instead of/in addition to commit messages** — `post-merge-release.yml` always creates a `vX.Y.Z` tag regardless of which flow released it.
- **Write an explicit lightweight marker at release time** — have `post-merge-release.yml` or `task-complete`'s Phase 2 create an empty `Release vX.Y.Z` commit (or annotate the merge commit) when a PR-gated release lands, restoring the original commit-message-based contract.
- **Search PR metadata via `gh`** — look up merged PR titles directly instead of relying on `git log`'s commit messages.

## Implementation Steps

TBD — to be filled in during planning/assessment (recommend running `smaqit.task-plan 031` before starting).

## Known Issues Triage

[Populated by smaqit.task-start via smaqit.utils.triage-issues. Do not edit manually.]

## Acceptance Criteria

- [ ] `release-analysis`'s Step 1c reliably finds the correct boundary for a repo whose most recent release went through the PR-gated flow (task 027+), without requiring manual override
- [ ] Works correctly for a mix of old-style batch releases (literal `Release vX.Y.Z`/`Prepare release vX.Y.Z` commits) and new-style PR-gated releases (title-only, no matching commit) in the same history
- [ ] No regression for the existing batch-mode boundary search used by `release-git-local`
- [ ] Verified against this repo's own real history (at minimum: correctly identifies v1.17.2's merge commit `219d67c` as the boundary, not v1.17.1)

## Findings

[Populated by smaqit.task-complete. Do not fill in manually before task is complete.]

**Implementation approach:**
- TBD

**Decisions made:**
- TBD

**Blockers encountered:**
- TBD

**Follow-up identified:**
- TBD

## Files to Create / Modify

| File | Action |
|------|--------|
| `skills/smaqit.release-analysis/SKILL.md` | Modify — fix Step 1c boundary detection |
| `skills/smaqit.release-prepare-files/SKILL.md` | Modify if its own Step 2A-2 boundary search shares the same bug |
| `tests/skills/*` | Create or modify — regression coverage for PR-gated boundary detection |

## Notes

Filed directly out of task 030's completion (`smaqit.task-complete` Step 10), after the user chose to manually override the boundary for task 030 itself rather than block its completion on this fix. Not urgent — every task since v1.17.2 has presumably been affected, but the practical consequence so far has only been an inflated/incorrect changelog delta, not a wrong version bump (severity assessment tends to be conservative regardless). Worth prioritizing before too many more tasks complete against the wrong boundary.
