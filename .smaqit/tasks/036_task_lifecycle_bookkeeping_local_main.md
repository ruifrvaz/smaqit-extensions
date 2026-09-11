---
status: In Progress
created: "2026-09-11"
mode: Assisted
started: "2026-09-11"
---

# Move task-lifecycle bookkeeping commits off origin/main onto local main

## Description

`smaqit.task-start` and `smaqit.task-complete` push every bookkeeping transition (task-status
frontmatter, `PLANNING.md` rows, pending/promoted `CHANGELOG.md` entries) directly to
`origin/main`, on the assumption that a plain `git push origin main` succeeds. That assumption
already required a bounded fetch-rebase-retry loop in this repo (concurrent local sessions can
race a direct push even with no branch protection at all) — and it breaks outright in any
downstream repo that adds required-PR-review protection on `main` (a completely ordinary,
recommended setup, not an edge case). Observed in one such downstream repo this week: a single
task needed **6-8 separate PRs**, nearly all of them pure bookkeeping with no reviewable content,
because every one of `task-start`'s Step 8 and `task-complete`'s Steps 12/14/18 had no path to
land except through a full push-branch-open-PR-get-reviewed cycle. Two of the observed PRs in
that repo existed only to fix mistakes the fragmentation itself caused.

**Corrected premise, established while investigating this:** `smaqit-extensions` sessions are
always local — there is no cross-machine or cloud-session coordination requirement here. Given
that, the fix doesn't need new infrastructure: `git worktree` doesn't create separate clones —
every worktree of a repository shares the same `.git` object database and ref namespace as the
primary checkout. A commit to local `main` from any worktree is immediately visible to every
other worktree of that repo, with no fetch, no push, no network operation. `task-start`'s own
branch-creation instruction already relies on exactly this (`SKILL.md:67`, *"create or reuse the
resolver's branch from `main`"* — bare `main`, not `origin/main`) — the bookkeeping *commits* just
never followed the same logic.

## Issue Triage Context

**Mode:** Skip
**Technologies:** bash (skill scripts), git worktree/ref mechanics
**Platforms/Environments:** N/A — documentation/prose changes to `SKILL.md`/`RULES.md`, verified against `9_resolve_task_lifecycle.sh` (confirmed to contain zero `origin/main` references already — this is not a script or Go-installer code change)
**Features/Integrations:** `smaqit.task-start`, `smaqit.task-complete`, `smaqit.utils.worktree`, `smaqit.release-analysis` (one lookup explicitly excluded, see Design Decisions)
**Versions/Constraints:** must not regress this repo's own (unprotected-`main`) task lifecycle, and must not reintroduce a cross-machine-coordination assumption anywhere in the affected prose

## Design Decisions

- **Bookkeeping commit points move to local `main` only — commit, never push:**
  - `smaqit.task-start/SKILL.md` Step 8 (lines 99-121): `chore: start task NNN`
  - `smaqit.task-complete/SKILL.md` Step 12 (line 89): pending `CHANGELOG.md` entry
  - `smaqit.task-complete/SKILL.md` Step 14 (lines 105-109): `chore: task NNN — PR #NNN opened`
  - `smaqit.task-complete/SKILL.md` Step 18 (lines 145-150): `chore: complete task NNN`
- **Step 13 rebases onto local `main`, not `origin/main`.** Since Step 12's pending entry now
  lives only on local `main`, Step 13's `git fetch origin main` / `git rebase origin/main`
  (`SKILL.md:93-94`) must become `git rebase main` — rebasing against a stale `origin/main` would
  simply never pick up the pending entry it's supposed to promote.
- **Step 17 needs a merge, not a fast-forward pull.** After a real PR merges into `origin/main`,
  the primary checkout currently does `git pull --ff-only origin main` (`SKILL.md:140-141`). Once
  local `main` can legitimately hold un-pushed bookkeeping commits ahead of `origin/main` — the
  normal state under this change, not an edge case — a fast-forward-only pull will refuse to
  proceed. This needs to become a real merge of `origin/main` into local `main` (fetch, then
  `git merge origin/main`, never `git merge -X ours`/`theirs`), with the same "never
  auto-resolve a conflict, abort and report" policy this skill already applies everywhere else if
  that merge itself conflicts. This is the one genuinely tricky mechanical piece in this task —
  budget real design attention here, not just a one-line edit.
- **`smaqit.release-analysis`'s boundary lookup is explicitly out of scope.** Its "fetch
  `origin/main` fresh" step (referenced from `task-complete/SKILL.md:76`) resolves the last
  *released* tag, and tags only ever exist on the remote — this fetch is correct as-is and must
  not change.
- **The actual implementation and release PRs are unaffected.** `task-complete` Steps 9, 11, and
  13's own `push -u origin <branch-name>` / `gh pr create` calls stay exactly as they are — this
  task only touches bookkeeping that was never meant to be reviewed, not the PR(s) that carry real
  content.
- **`9_resolve_task_lifecycle.sh` needs no code change** — confirmed via direct inspection, it
  contains zero references to `origin/main`, fetch, or pull. This is a `SKILL.md`/`RULES.md`
  prose change only.
- **Collision handling on local `main` still needs a retry shape**, just against local refs
  instead of the network: if two worktrees both commit bookkeeping to local `main` around the
  same moment, whichever commits second rebases onto the first — near-instant since there's no
  network round-trip, but a genuine content conflict (e.g. both touching the same `PLANNING.md`
  line) still needs the existing "abort, never auto-resolve, report to the user" policy, not a
  silent merge.
- **Applies uniformly regardless of whether the adopting repo protects `origin/main`.** This
  isn't a protected-repo-only branch: this repo's own existing bounded-retry loop exists precisely
  *because* concurrent direct pushes to an unprotected `origin/main` can already collide — local
  `main` sidesteps that race more cheaply here too, not just in a protected downstream repo.

## Implementation Steps

1. Rewrite `smaqit.task-start/SKILL.md` Step 8 (lines 99-121): replace the
   push-with-bounded-fetch-rebase-retry block with a local-only commit. Keep an analogous
   bounded-retry shape for the local-collision case (rebase onto local `main` if it moved since
   this worktree last read it), but drop every `origin`/network reference.
2. Rewrite `smaqit.task-complete/SKILL.md`:
   - Step 12 (line 89): pending entry commits to local `main` only.
   - Step 13 (lines 92-95): `git fetch origin main` / `git rebase origin/main` → `git rebase main`.
   - Step 14 (lines 105-109): commits to local `main` only.
   - Step 17 (lines 137-143): fetch `origin/main`, then merge it into local `main` (not
     fast-forward-only); on conflict, abort and report per this skill's existing policy.
   - Step 18 (lines 145-150): commits to local `main` only.
   - Leave Step 10's release-analysis fetch, and Steps 9/11/13's branch push + `gh pr create`,
     untouched.
3. Update both `smaqit.task-start/references/RULES.md` and
   `smaqit.task-complete/references/RULES.md` (lines 148 and 169 in each) to match the corrected
   language — these currently restate the exact "push to `origin/main` immediately" policy this
   task is changing.
4. Spot-check `smaqit.utils.worktree`'s remaining scripts (`6_detect_orphans.sh`,
   `7_build_workspace.sh`, and the rest not already confirmed) for any undocumented
   `origin`/fetch/pull dependency beyond the already-correct local-`main` branch-creation
   instruction — fix or explicitly rule out each one.
5. Add a short, explicit note in the affected `SKILL.md` files stating the "local-only sessions,
   no cross-machine/cloud coordination" premise, so a future edit doesn't reintroduce the
   origin-push out of a mistaken cross-machine-safety instinct.
6. Verify: exercise `task.start`/`task.complete` end-to-end (a) in this repo (unprotected `main`)
   to confirm no regression in existing collision-handling behavior, and (b) in a
   `main`-branch-protected test repo (required PR review, mirroring the downstream repo that
   surfaced this) to confirm a task now needs only its implementation PR and, if applicable, its
   release PR — zero bookkeeping-only PRs.

## Known Issues Triage

**Triaged:** 2026-09-11
**Result:** Skipped — explicitly marked `Mode: Skip` in task Notes.

## Acceptance Criteria

- [ ] `task-start` Step 8 commits bookkeeping to local `main` only — no push, no PR
- [ ] `task-complete` Steps 12, 14, and 18 commit bookkeeping to local `main` only — no push, no PR
- [ ] `task-complete` Step 13 rebases onto local `main` (not `origin/main`) to pick up the pending `CHANGELOG.md` entry
- [ ] `task-complete` Step 17 merges `origin/main` into local `main` after a real PR merge, tolerating local `main` being ahead with bookkeeping commits, with the existing abort-and-report policy on conflict
- [ ] `task-complete` Step 10's release-analysis boundary fetch against `origin/main` is explicitly left unchanged
- [ ] `task-start`'s existing "branch from `main`" instruction is confirmed unchanged (already local)
- [ ] Both `references/RULES.md` files are updated to match
- [ ] End-to-end verification in a `main`-branch-protected test repo shows a task needing only its implementation PR and (if applicable) its release PR — no bookkeeping-only PRs
- [ ] End-to-end verification in this repo shows no regression in the existing unprotected-`main` task lifecycle

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
| `skills/smaqit.task-start/SKILL.md` | Modify |
| `skills/smaqit.task-start/references/RULES.md` | Modify |
| `skills/smaqit.task-complete/SKILL.md` | Modify |
| `skills/smaqit.task-complete/references/RULES.md` | Modify |
| `skills/smaqit.utils.worktree/scripts/*.sh` | Modify (only if step 4's spot-check finds a dependency) |
| `installer/skills/...` and `installer/skills-claude/...` mirrors of the above | Modify (kept in sync with `skills/`, per this repo's existing mirror convention) |

## Notes

- Origin: raised in a downstream repo (`Magnificah/infrastructure`) after tasks needed 6-8 PRs
  each, almost entirely bookkeeping, once that repo added required-PR-review branch protection on
  `main`. An initial framing wrongly assumed `smaqit-extensions` needed cross-machine/cloud-session
  coordination and rejected a local-`main` fix on that basis; the user corrected this directly —
  all `smaqit-extensions` sessions are local, and the actual constraint is git worktree ref-sharing
  mechanics, not cross-machine visibility. A first draft of this task was mistakenly created in the
  downstream repo's own task tracker as a "requirements handoff document" (mirroring an unrelated
  precedent, task 015 there, whose content was genuinely repo-specific domain knowledge unlike
  this) before being recreated here directly, once local access to this repo was confirmed.
- Concrete PR-count evidence from the downstream repo, for whoever picks this up: two spec/doc-only
  tasks (no code) each still needed 6-8 PRs; one infra-change task needed 8; one CI-fix task needed
  6. Two of those PRs existed purely to correct mistakes caused by the bookkeeping fragmentation
  itself.
