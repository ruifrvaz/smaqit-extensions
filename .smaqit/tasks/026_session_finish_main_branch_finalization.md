# Session-Finish Main Branch Finalization

**Status:** In Progress
**Created:** 2026-08-14
**Mode:** Autonomous
**Started:** 2026-08-14

## Description

`smaqit.session-finish` currently runs zero git commands — it is entirely branch-agnostic, writing history, memory, research-map, and compendium entries with no check of current branch, no commit, and no push. This leaves `main` potentially dirty or stale relative to `origin/main` at the end of a session.

Add a new final step to `smaqit.session-finish` that resolves the primary checkout (never assumes cwd), verifies/restores `main`, commits only the files this session-finish run itself wrote, syncs with `origin/main` via fetch + fast-forward-only pull, and pushes — gated Assisted/Autonomous by an explicit `--autonomous` flag (default Assisted, mirroring `smaqit.task-start`). Any state that cannot be resolved safely (detached HEAD, merge-conflict markers, diverged history, a dirty non-main branch, an unexpectedly rejected push) always stops and reports in both modes, with zero destructive fallback — no conflict resolution, no force-push, no hard reset or discard, no rebase, no auth/permission fixing, no touching other worktrees or branches, no automatic retry after a rejection.

## Design Decisions

- **Mode source:** an explicit `--autonomous` flag on `session.finish` (default Assisted) — mirrors `task.start`'s existing flag convention. No new session-level `Mode` field is introduced; today `Mode` only ever lives inside an individual task file, written by `task-start`.
- **Commit scope:** a targeted `git add` of only the exact paths this run wrote (history file, `.smaqit/compendium.md`, `.smaqit/references/project-research.md` when refreshed) — never `git add -A`. Matches `task-complete`'s own targeted-add convention and avoids sweeping up unrelated stray work.
- **Push trigger:** Autonomous pushes automatically only when the sync check has already confirmed a clean fast-forward is possible. Assisted always stops for explicit confirmation before pushing. A push rejected anyway (race condition) stops and reports in both modes — no automatic retry, no force-push.
- **Sync mechanism:** `git fetch origin main` then `git pull --ff-only` if local is behind. Refuses (and flags) instead of merging/rebasing if history has genuinely diverged.
- **Auto-checkout to `main`:** if the primary checkout is on a non-main branch with a *clean* tree, check it out to `main` unconditionally in **both** modes — non-destructive and mirrors `task-complete`'s own unconditional `git checkout main`. A non-main branch with a *dirty* tree is instead treated as a blocking condition (see below).
- **`smaqit.task-refresh` is intentionally not invoked by this new step** — kept out of scope, even though `task-refresh`'s own description says it should run "as part of or immediately after session-finish."

## Implementation Steps

1. Add a `## Usage` section to `skills/smaqit.session-finish/SKILL.md` documenting `session.finish` (Assisted default) and `session.finish --autonomous`, matching `smaqit.task-start`'s own `## Usage` block shape. Bump frontmatter `metadata.version` `0.9.1` → `0.10.0`.
2. Insert a new **Step 7: Finalize main branch state**, after the existing Step 6 ("Update the project compendium"):
   - Resolve the primary checkout path via `git worktree list --porcelain` — never assume cwd (matches `task-complete` Step 9's pattern).
   - Detect blocking conditions first, before any mutation: detached HEAD, unmerged/conflict markers (`.git/MERGE_HEAD` present, or `git status --porcelain` showing `UU`/`AA`/etc.), or a non-`main` branch with a dirty tree. Any match → STOP, report the exact condition, take no action, in both modes.
   - A non-`main` branch with a clean tree → `git checkout main` unconditionally; report the switch.
   - On `main`, check `git status --porcelain` scoped only to the exact paths this run wrote. No changes → skip to the sync check.
   - Uncommitted targeted changes found — Assisted: list the files, stop, ask for explicit confirmation to commit. Autonomous: `git add <exact paths>` (never `-A`), commit (e.g. `chore: session housekeeping — history, compendium, research map`), continue.
   - Sync: `git fetch origin main`; compare local `main` vs `origin/main` SHAs. Equal → report up to date, done. Behind only → `git pull --ff-only origin main`. Diverged (both ahead and behind) → STOP, report the commit counts, no pull/merge/rebase attempted.
   - Push (only reached if local is ahead and not diverged) — Assisted: report N commit(s) ready to push, stop for explicit confirmation. Autonomous: `git push origin main`; a rejection (e.g. a race with another push) → STOP and report, no retry, no force.
3. Extend (or add, if none exists) a Failure Handling table in `SKILL.md` with a row per nasty condition (detached HEAD, conflict markers, dirty non-main branch, diverged history, rejected push), each mapped to "STOP, report the exact state, take no action." State the explicit non-goals (no conflict resolution, no force-push, no hard reset/discard, no rebase, no auth/permission fixing, no touching other worktrees, no auto-retry) directly in the new step's text or Scope section.
4. Add `tests/skills/test-session-finish-main-sync.sh` (bare-repo + clone fixture, following the pattern of `tests/skills/test-worktree-layout.sh`) covering: clean main with nothing to do; clean non-main branch auto-checkout; dirty non-main branch stop; detached HEAD stop; conflict-marker stop; Autonomous targeted commit; Assisted stop-before-commit; behind-only fast-forward pull; diverged-history stop; Autonomous push success; push-rejected-race stop.
5. Register a `test-session-finish-main-sync` target in the root `Makefile` (`.PHONY` line, new target block, add to the `test:` composite target) alongside the existing `test-worktree-layout`/`test-parent-task-lifecycle`/`test-project-research-verify-urls` targets.
6. Add a concise `CHANGELOG.md` entry under `[Unreleased]`. Update the `smaqit.session-finish` bullet in `README.md` to mention it now finalizes `main`'s git state. Run the focused test, then `make test` and `make smoke-test` to confirm the modified `SKILL.md` still compiles identically into all three platform trees.

## Known Issues Triage

[Populated by smaqit.task-start via smaqit.utils.triage-issues. Do not edit manually.]

## Acceptance Criteria

- [ ] `session.finish` (default Assisted) and `session.finish --autonomous` are both documented and supported invocation forms.
- [ ] The finalize step always resolves the primary checkout via `git worktree list --porcelain`, never cwd.
- [ ] Detached HEAD, merge-conflict markers, and a dirty non-main branch are detected before any mutation and always STOP with an exact report, in both modes — no auto-fix is attempted for any of these.
- [ ] A non-main branch with a clean tree is checked out to `main` automatically in both modes.
- [ ] Only the exact files this session-finish run wrote are staged for commit — never `git add -A`.
- [ ] Assisted mode stops for explicit confirmation before committing and before pushing; Autonomous mode commits and pushes automatically only when the sync check confirms a clean fast-forward.
- [ ] `main` is synced against `origin/main` via `git fetch` + `git pull --ff-only`; a truly diverged history STOPs and reports commit counts instead of pulling/merging/rebasing.
- [ ] A push rejected unexpectedly (race condition) STOPs and reports — no automatic retry, no force-push.
- [ ] No permission/auth fix, cross-session/worktree conflict resolution, or destructive operation (force-push, hard reset, discarding uncommitted work, rebase) is ever attempted — all such cases STOP and defer to the user.
- [ ] Hermetic test `tests/skills/test-session-finish-main-sync.sh` covers all the branching conditions above without touching a real remote.
- [ ] `make test` and `make smoke-test` pass; `CHANGELOG.md` and `README.md` updated; skill version bumped `0.9.1` → `0.10.0`.

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
| `skills/smaqit.session-finish/SKILL.md` | Modify |
| `tests/skills/test-session-finish-main-sync.sh` | Create |
| `Makefile` | Modify |
| `CHANGELOG.md` | Modify |
| `README.md` | Modify |

## Notes

- Reference-only precedents (not modified by this task): `skills/smaqit.task-complete/SKILL.md` (checkout/targeted-add/STOP-and-report pattern), `skills/smaqit.release-git-local/SKILL.md` (push gating, error table, "never force push"), `skills/smaqit.task-start/SKILL.md` (`--autonomous` flag / `## Usage` shape), `tests/skills/test-worktree-layout.sh` (bash git-fixture style).
- Open question carried from planning, not yet resolved: should this new step also invoke `smaqit.task-refresh` (currently undocumented/unwired despite its own description claiming that relationship)? Deliberately left out of this task's scope — raise separately if wanted.
- Also carried from planning as the most debatable design call: should Assisted mode stop-and-confirm before the automatic `main` checkout (from a clean non-main branch), for full parity with how conservative the rest of Assisted mode is? Current decision leaves it unconditional in both modes since it cannot lose data — revisit during implementation if it feels wrong in practice.

Child tasks inherit their active parent's branch, worktree, and workflow mode. Only a standalone or parent task owns Git lifecycle cleanup.
