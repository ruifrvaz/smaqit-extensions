# PR-Gated Task Completion & Per-Task Releases

**Status:** In Progress
**Created:** 2026-08-14
**Mode:** Assisted
**Started:** 2026-08-14

## Description

Replace `task-complete`'s direct local merge to `main` with a two-phase, PR-gated flow where every completed owner task's PR is also its release (version bump, changelog, tag, GitHub Release on merge), while smaqit's cross-session metadata (tasks, `PLANNING.md`, `CHANGELOG.md`, history, compendium) keeps syncing directly to `main` for real-time visibility across parallel sessions. Ships as the new default across all consumer projects.

This applies only to owner (standalone or parent) task completion — child task completion is completely unaffected: children continue to merge into the shared parent worktree/branch via plain commit + bookkeeping, with no PR and no release of their own; their work ships as part of whichever PR the owner eventually opens.

## Issue Triage Context

**Mode:** Auto
**Technologies:** GitHub REST API, GitHub CLI (gh), git, GitHub Actions
**Platforms/Environments:** Codex, Claude Code, GitHub Copilot
**Features/Integrations:** PR-based task completion, per-task release automation, post-merge-release.yml, task worktree lifecycle, cross-session metadata sync
**Versions/Constraints:** global default for all consumer projects; no GitHub branch protection added; concurrency-group hardening only, no CI auto-retry on tag collision

## Design Decisions

- **Split enforcement:** Main's code is always PR-gated (skill-level convention only; no GitHub branch protection rule added).
- **Immediate metadata sync:** Main's metadata always pushes directly to `origin/main`, immediately, at `task-start` and `task-complete`'s pre-PR step.
- **Task PR is a release:** Every owner task's PR is also a release — a deliberate cadence change from today's batched releases.
- **Pending CHANGELOG annotations:** `[Unreleased]` holds per-entry `(pending PR #NNN)` annotations, not a renamed section; supports multiple concurrent pending tasks; tags may land out of numeric merge order (accepted).
- **Fresh version boundary:** `release-analysis` must fetch-and-diff against live `origin/main` (fixes a real staleness bug found during discovery) and treat pending entries as claimed versions.
- **Push retry policy:** Metadata pushes retry (bounded fetch-rebase-retry) on rejection; `post-merge-release.yml` gets a concurrency group and fails loudly on residual tag collisions, no CI auto-retry.
- **Branch cleanup:** Local branch cleanup force-deletes (`-D`) once `gh pr view` confirms `MERGED`, regardless of merge strategy; remote branches are never deleted.
- **Mode-specific merge behavior:** Autonomous mode self-merges its own PR immediately (`gh pr merge --merge`), no human wait, single invocation. Assisted mode's Phase 2 (including agent-executed merge) only runs on explicit user request, never self-initiated.
- **Global default:** Ships as the new default for every consumer project, not gated behind a repo-specific opt-in.
- **Child tasks untouched:** The new PR/release flow applies only to owner (standalone or parent) task completion. Child task completion keeps merging into the parent's shared branch/worktree via plain commit + bookkeeping, with no PR and no release of its own — the parent's eventual PR is what ships the child's work.
- **New status:** `PR Open` sits between `In Progress` and `Completed`, recording the PR number.
- **Out of scope:** Tasks 007/010's pre-existing stale draft PRs are explicitly untouched by this task.

## Implementation Steps

1. Define the `(pending PR #NNN)` per-entry annotation convention for `CHANGELOG.md`'s `[Unreleased]` section (one entry per in-flight owner task, each independently promotable).
2. Update `release-prepare-files`' Unreleased-to-versioned-section promotion logic (its Step 2C) to promote exactly one named pending entry, leaving sibling pending entries untouched, instead of relocating the whole section.
3. Fix `release-analysis`'s boundary search to `git fetch origin main` and compute against `origin/main`'s tip every time, not the possibly-stale local/branch history.
4. Extend `release-analysis` to accept an explicit "diff a given branch against `origin/main`" mode for pre-merge version computation, and to treat other pending `CHANGELOG.md` entries on `main` as already-claimed versions.
5. Add a `concurrency:` group to `post-merge-release.yml` (both this repo's copy and `installer/workflow-templates/post-merge-release.yml`); leave tag-push collisions failing loudly with no CI-side auto-retry.
6. Give `task-start` (its Step 8) and the new `task-complete` pre-PR step an immediate `origin/main` push, not a local-only commit — add a bounded fetch-rebase-retry loop on rejection, distinct from `session-finish`'s stricter stop-on-rejection policy.
7. Rewrite `task-complete` Steps 8-13: Phase 1 (commit implementation on the task branch, run the new branch-vs-`origin/main` `release-analysis` mode, push the pending `CHANGELOG.md` entry to `main`, push the branch, open a code-only PR via `release-git-pr` which no longer stages `CHANGELOG.md`, set task status to a new `PR Open` state recording the PR number) — stop for Assisted mode. Gated strictly to `kind == owner` (standalone or parent) from the lifecycle resolver, exactly like today's existing Child/Owner branch in Steps 8-9 — a child's completion takes neither this nor any other new path; it continues to commit its implementation directly into the shared parent worktree and update task-file bookkeeping only, with no branch push, no PR, and no release of its own.
8. Add Autonomous-mode-only merge step: immediately after opening the PR, self-merge via `gh pr merge --merge` (explicit merge-commit strategy, matching this repo's existing convention) with no wait, then continue straight into Phase 2 in the same invocation.
9. Add Phase 2 as a separate, re-entrant entry point (`task.complete NNN` invoked again, any mode), owner-only — a child never reaches Phase 2 since it never entered Phase 1: `gh pr view <PR#> --json state,mergedAt` — if merged, pull `main`, flip status to `Completed`, remove the worktree, then force-delete (`-D`) the local branch only (never the remote branch); if not merged, report pending and make no changes. For Assisted mode, this phase (including performing the merge itself) only runs on an explicit user request — never self-initiated, mirroring the existing "explicit chat request, not just the slash command" pattern already documented for today's `task-complete`.
10. Add the abandon path: if a pending PR closes unmerged, delete its pending `CHANGELOG.md` entry via the same direct-push mechanism; never reuse the burned version number.
11. Add the `PR Open` status to `.smaqit/templates/task.template.md`, `skills/smaqit.task-create/assets/TASK_TEMPLATE.md`, `PLANNING.md`'s documented status values, and all three synced `RULES.md` copies (`task-start`, `task-complete`, `task-list`).
12. Update the memory `"task state"` convention (in `task-start`/`task-complete`) to record `PR Open` and the PR number.
13. Add hermetic tests: pending-annotation parsing/promotion, `release-analysis` fresh-origin-fetch and pending-version-awareness, retry-loop push behavior, squash-merge-safe local branch force-delete after a confirmed `gh pr view` merge state, and a test asserting a child task never triggers Phase 1 or Phase 2.
14. Register new test targets in the root `Makefile`, bump every touched skill's version and `CHANGELOG.md`, regenerate installer staging, run focused tests, `make test`, `make smoke-test`, install the verified build globally.
15. Manually verify end-to-end against this actual repo with a disposable throwaway task/branch — hermetic tests can't cover real `gh pr merge`/`gh pr view` semantics or GitHub's actual squash-merge behavior.

## Known Issues Triage
**Triaged:** 2026-08-14
**Tools searched:** GitHub REST API, GitHub CLI (gh), Git, GitHub Actions
**Result:** Clear

### Blocking Issues
None.

### Advisory Issues
None.

### Historical (Closed)
None.

### Unresolvable Tools
None.

### Omitted Tools
None.

### Search Warnings
None.

## Acceptance Criteria

- [ ] `task-complete` never runs a local `git merge` into `main`; Assisted-mode completion always produces a pushed branch and an open PR, then stops.
- [ ] `task-start` and `task-complete`'s pre-PR metadata commit are pushed to `origin/main` immediately, with a bounded fetch-rebase-retry loop on rejection.
- [ ] `CHANGELOG.md`'s `[Unreleased]` section supports multiple simultaneous `(pending PR #NNN)`-annotated entries, each independently promotable to its own dated version section by its own PR.
- [ ] `release-analysis` computes version/severity against live `origin/main` (never stale local state) and treats other pending entries as already-claimed versions.
- [ ] `post-merge-release.yml` (this repo's copy and the consumer template) has a concurrency group; a residual tag collision fails the workflow run visibly rather than silently dropping a release.
- [ ] Local task-branch cleanup force-deletes the branch only after `gh pr view` confirms `MERGED`, regardless of merge strategy; the remote branch is never deleted.
- [ ] Autonomous-mode `task-complete` opens and merges its own PR in one invocation with no human wait; Assisted-mode's merge-check-and-cleanup phase never self-initiates and only runs on explicit user request.
- [ ] A new `PR Open` task status (recording the PR number) is documented in both task templates, `PLANNING.md`, and all three synced `RULES.md` copies.
- [ ] An abandoned task with an unmerged, closed PR has its pending `CHANGELOG.md` entry removed; its claimed version number is never reused.
- [ ] Child task completion is unchanged: no branch push, no PR, no release; its commits land only in the shared parent worktree via the existing bookkeeping-only path, and this is exercised by a hermetic test asserting a child never triggers Phase 1 or Phase 2.
- [ ] Hermetic tests cover pending-entry promotion, fresh-boundary version computation, push retry, and squash-merge-safe branch deletion; `make test` and `make smoke-test` pass.

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
| `skills/smaqit.task-start/SKILL.md` | Modify |
| `skills/smaqit.release-analysis/SKILL.md` | Modify |
| `skills/smaqit.release-approval/SKILL.md` | Modify |
| `skills/smaqit.release-prepare-files/SKILL.md` | Modify |
| `skills/smaqit.release-git-pr/SKILL.md` | Modify |
| `skills/smaqit.utils.worktree/SKILL.md` | Modify |
| `.github/workflows/post-merge-release.yml` | Modify |
| `installer/workflow-templates/post-merge-release.yml` | Modify |
| `.smaqit/templates/task.template.md` | Modify |
| `skills/smaqit.task-create/assets/TASK_TEMPLATE.md` | Modify |
| `skills/smaqit.task-start/references/RULES.md` | Modify |
| `skills/smaqit.task-complete/references/RULES.md` | Modify |
| `skills/smaqit.task-list/references/RULES.md` | Modify |
| `tests/skills/test-task-complete-pr-lifecycle.sh` | Create |
| `tests/skills/test-release-analysis-pending-versions.sh` | Create |
| `Makefile` | Modify |
| `CHANGELOG.md` | Modify |

## Notes

- Scoped via an extended `smaqit.session-assess` discussion (branch protection reality-checked against live GitHub state; two Explore agents investigated worktree/cleanup mechanics and the post-merge release workflow before drafting this plan via `smaqit.task-plan`).
- Discovery found two real pre-existing bugs this task must also fix, not just new behavior to add: `release-analysis`'s boundary search never fetches/compares against fresh `origin/main` (stale-boundary version-collision risk), and `git branch -d` cannot recognize a squash-merged branch as merged.
- `release-git-local`-only projects (no PR-based release model) are not addressed by this task; flagged as a candidate follow-up once this proves out as the global default.
- "Main is never pushed into directly" remains an agent-side convention only — no GitHub branch protection rule is being added as part of this task.

Child tasks inherit their active parent's branch, worktree, and workflow mode. Only a standalone or parent task owns Git lifecycle cleanup.
