---
status: In Progress
mode: Assisted
created: "2026-10-11"
started: "2026-10-18"
---

# Release Chain: Preflight post-merge-release.yml and Warn on Isolated Subagent Worktrees

## Description

Migrated from smaqit task 114 (Findings 5 and 6) on 2026-10-11. The task-lifecycle and release
skills live only in this repository, so these two gaps belong here. Priority: Medium.

**1. No preflight for `post-merge-release.yml`.** The PR-gated release chain assumes
`.github/workflows/post-merge-release.yml` exists in the project. A downstream repository that
never had it installed followed the full `Prepare release vX.Y.Z` convention, merged the PR, and
silently got no tag and no GitHub Release. Nothing in the chain checks for the file:

- `skills/smaqit.task-complete/SKILL.md` Step 11 (~82–90) runs `gh pr create --title "Prepare
  release vX.Y.Z"` with no existence check; ~91 only explains that a wrong *title* makes the
  workflow skip every job, and Step 13 (~97) assumes the workflow's release-notes extraction runs.
- `skills/smaqit.release-git-pr/SKILL.md` ~29 covers the wrong-title case only; ~97 states the
  file is installed by `smaqit-extensions install --scope project` / `update` (create-if-absent)
  as a given.
- `agents/smaqit.release.pr.agent.md` (~95, ~99) and `skills/smaqit.release-git-local/SKILL.md`
  (~299) make the same assumption.

The installer does ship the file (`installer/workflow-templates/post-merge-release.yml`,
`installReleaseWorkflow()` via `writeFileIfMissing`, called from `scaffoldProject()` on
`init`/`update`), so the gap is a repository that never ran `init`/`update`, or ran one that
predates task 021.

**2. Isolated subagent worktrees can't see uncommitted Assisted-mode work.** `task-start` (~122)
and `task-complete` (~58, ~74) deliberately keep implementation uncommitted in the task worktree
until `task-complete`, so Assisted-mode review sees a normal working-tree diff. A subagent that
runs in its own isolated worktree is checked out from the branch's last *commit* and can't see
that uncommitted state. In the originating incident, a delegated deployment agent had to escape
into the real task worktree to function. Nothing in this repository warns about it. (The
smaqit-side half, guidance in the `smaqit-deployment` agent, stays in smaqit task 114.)

## Issue Triage Context

**Mode:** Auto
**Technologies:** GitHub Actions, GitHub CLI, Git
**Platforms/Environments:** Linux, WSL2, macOS
**Features/Integrations:** PR-gated releases, post-merge-release workflow, git worktrees, Assisted-mode task workflow, subagent worktree isolation
**Versions/Constraints:** Release workflow matches on the exact `Prepare release vX.Y.Z` PR title, implementation stays uncommitted until task-complete

## Design Decisions

- **Warn, don't block or auto-install:** the preflight warns before a release-titled PR is opened
  and points at `smaqit-extensions init`/`update` (create-if-absent) to install the workflow.
  Installing it from inside `task-complete` would mix scaffolding into a lifecycle step.
- **One shared check:** the same existence check serves `task-complete` and `release-git-pr`
  (and the release-pr agent that calls it), so the wording and the path stay in one place.
- **Check the git object, not the filesystem:** the workflow must exist on the base branch the
  release PR merges into, and a task worktree's sparse checkout can hide `.github/workflows`
  (task 019), so a filesystem check could give a false warning.
- **The worktree caveat is guidance, not mechanism:** `task-start`/`task-complete` state that a
  subagent delegated during Assisted-mode implementation must run in the task worktree, not an
  isolated one. No change to the uncommitted-until-complete rule.

## Implementation Steps

1. `skills/smaqit.task-complete/SKILL.md`: between Step 10 (version compute) and Step 11 (PR
   creation), check that `.github/workflows/post-merge-release.yml` exists on the PR's base
   branch, e.g. `git cat-file -e origin/main:.github/workflows/post-merge-release.yml`, not
   on disk, since a task worktree's sparse patterns can hide `.github/workflows` (task 019).
   If missing, warn that merging will publish no tag or release, name `smaqit-extensions init`/
   `update` as the fix, and ask whether to stop or continue.
2. `skills/smaqit.release-git-pr/SKILL.md`: the same preflight before opening the release PR;
   reword ~97 so the file's presence is checked, not assumed.
3. `agents/smaqit.release.pr.agent.md` and `skills/smaqit.release-git-local/SKILL.md`: align the
   wording that assumes the file exists.
4. `skills/smaqit.task-start/SKILL.md` (near the uncommitted-implementation rule, ~122) and
   `skills/smaqit.task-complete/SKILL.md` (~74): add the isolated-subagent-worktree caveat.
5. Bump `metadata.version` on each changed skill; run `make sync` and the repository's tests.
6. `CHANGELOG.md` entry and a `Prepare release vX.Y.Z` PR.

## Known Issues Triage
**Triaged:** 2026-10-18
**Tools searched:** GitHub Actions (`actions/starter-workflows`), GitHub CLI (`cli/cli`), Git (`git/git`)
**Result:** Advisory

### Advisory Issues
- [#8362 `gh pr merge` "delete local branch" deletes the wrong branch](https://github.com/cli/cli/issues/8362) — `cli/cli` — opened 2023-11-21 — bug, priority-2, gh-pr
- [#12144 Make `gh pr create` output capable of being piped to other commands](https://github.com/cli/cli/issues/12144) — `cli/cli` — opened 2025-11-13 — enhancement, gh-pr, stale

### Historical (Closed)
- [#14242 gh pr create fails with "Repository was archived so is read-only (createPullRequest)" for a non-archived repository](https://github.com/cli/cli/issues/14242) — `cli/cli` — closed 2026-08-27
- [#7590 gh pr view and gh pr status still not detecting ongoing PR branch](https://github.com/cli/cli/issues/7590) — `cli/cli` — closed 2026-07-09

### Search Warnings
- `git/git` open and closed searches — repository has GitHub issues disabled (mailing-list project); zero results are not evidence of no known issues
- `actions/starter-workflows` was the helper's resolution for GitHub Actions; it holds workflow templates, not the Actions runtime, so its empty results say little about trigger behavior
- Research map task block carries documentation URLs only, no GitHub repository URLs; all three repositories were resolved through the helper fallback

## Acceptance Criteria

- [ ] `task-complete` and `release-git-pr` detect a missing `.github/workflows/post-merge-release.yml`
      and warn before a `Prepare release` PR is opened, naming `smaqit-extensions init`/`update`
      as the fix.
- [ ] No release skill or agent states the workflow's presence as a given without the check.
- [ ] `task-start` and `task-complete` state that subagents delegated during Assisted-mode
      implementation must run in the task worktree, because an isolated worktree sees only
      committed state.
- [ ] `make sync` and the repository's tests pass; `CHANGELOG.md` is updated.

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
| `skills/smaqit.task-complete/SKILL.md` | Modify |
| `skills/smaqit.release-git-pr/SKILL.md` | Modify |
| `skills/smaqit.release-git-local/SKILL.md` | Modify |
| `agents/smaqit.release.pr.agent.md` | Modify |
| `skills/smaqit.task-start/SKILL.md` | Modify |
| `CHANGELOG.md` | Modify |

## Notes

- Origin: smaqit `.smaqit/tasks/114_refactor_infrastructure_skills_for_machine_monorepo_pattern.md`
  (Findings 5 and 6), planned and migrated 2026-10-11.
- Related tasks here: 021 (ships the workflow template), 027 (PR-gated releases), 019 (sparse
  checkout excluding `.github/workflows` from task worktrees — relevant if the check runs in a
  worktree whose sparse patterns hide `.github/workflows`).
