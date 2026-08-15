---
status: Completed
mode: Assisted
created: "2026-08-11"
started: "2026-08-11"
completed: "2026-08-11"
---

# Fix Worktree Script Repo-Root Resolution for Global Install

## Description

8 of the 9 `smaqit.utils.worktree` scripts resolve the git repository root from their own installed script location (`${BASH_SOURCE[0]}`) instead of the caller's working directory, which broke when task 023 moved skill installation from per-project committed mirrors to global user-level paths (`~/.claude/skills/`, `~/.agents/skills/`). Under the global install, the script file no longer lives inside the project it operates on, so `git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel` resolves the wrong repo (or errors).

Replace the script-location-based `git -C` idiom with a bare, caller-cwd-based `git rev-parse --show-toplevel` in all 8 affected scripts — matching the pattern already used correctly by `2_validate_prereqs.sh`, `skills/smaqit.project-diagnose/scripts/diagnose-inventory.sh`, and the Go CLI's own `resolveDefaultProjectDir` (`installer/main.go`). Also document the caller-cwd contract in `SKILL.md`, and harden the two existing test fixtures that currently mask this bug by copying the scripts inside the fixture repo before invoking them (which accidentally makes the buggy resolution succeed under test).

## Design Decisions

- **Resolution strategy:** rely on caller cwd via bare `git rev-parse --show-toplevel`, not by threading an explicit repo-root argument through every script invocation. Matches the existing house pattern already used elsewhere in this codebase (see Description).
- **Test fixtures are in scope:** `tests/skills/test-worktree-layout.sh` and `tests/skills/test-parent-task-lifecycle.sh` both copy the worktree scripts inside the fixture repo before running them, which is why this bug shipped undetected by `make test`. Both need to install scripts outside the fixture repo (mirroring real global-install topology) so the suite can actually catch a regression of this defect class.
- **Downstream callers out of scope:** skills that invoke `smaqit.utils.worktree` (e.g. `smaqit.task-start`) are assumed to already run from the project root, matching Step 9's already-documented convention. No evidence surfaced during planning that any caller changes cwd first. Worth a quick sanity check during implementation, but not a separate audit task.

## Implementation Steps

**Phase A — Script fixes**
1. Fix `1_present_branches.sh:22-23`, `4_enumerate_worktrees.sh:12-13`, `6_detect_orphans.sh:12-13`, `7_build_workspace.sh:14-15` — replace the `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` / `git -C "$SCRIPT_DIR" ...` two-liner with `REPO_ROOT="$(git rev-parse --show-toplevel)"`.
2. Fix `3_compute_slugs.sh:22-24` — same replacement; `PROJECT_NAME="$(basename "$REPO_ROOT")"` (line 24) needs no change once `REPO_ROOT` is correct.
3. Fix `5_create_worktrees.sh:16-18` — same replacement; `REPO_PARENT="$(dirname "$REPO_ROOT")"` (line 18) needs no change.
4. Fix `8_migrate_sessions.sh:29-31` — same replacement; preserve the existing `PROJECT_NAME="${PROJECT_NAME:-$(basename "$REPO_ROOT")}"` env-override behavior (line 31).
5. Fix `9_resolve_task_lifecycle.sh:63-64` — replace `mapfile -t worktree_lines < <(git -C "$SCRIPT_DIR" worktree list --porcelain)` with a bare `git worktree list --porcelain`. Confirm nothing else in the script still references `SCRIPT_DIR` before deleting the derivation line.

**Phase B — Documentation**
6. Update `skills/smaqit.utils.worktree/SKILL.md` to state that Steps 1–8 must also be invoked with cwd already at the project root (Step 9 / Gotcha #15 already document this for themselves; extend the same contract to the rest of the skill). Bump `metadata.version` from `1.2.0` per this project's version-on-every-change convention.

**Phase C — Test hardening** (depends on Phase A)
7. Update `tests/skills/test-worktree-layout.sh` — currently copies scripts to `$repo/.agents/skills/smaqit.utils.worktree-scripts/` *inside* the fixture repo (lines 37-38), which masks the bug. Install scripts to a location outside the fixture repo instead, and invoke them by absolute path with cwd set to the fixture repo, matching real global-install topology.
8. Update `tests/skills/test-parent-task-lifecycle.sh` — identical masking problem via `WORKTREE_SCRIPTS="$PRIMARY_ROOT/.agents/skills/smaqit.utils.worktree/scripts"` (line 9). Same fix.

**Phase D — Verification**
9. Run `make test` (covers both hardened fixtures plus `test-project-research-verify-urls`) and confirm all pass.

## Known Issues Triage

[Populated by smaqit.task-start via smaqit.utils.triage-issues. Do not edit manually.]

## Acceptance Criteria

- [x] All 8 affected scripts (`1_present_branches.sh`, `3_compute_slugs.sh`, `4_enumerate_worktrees.sh`, `5_create_worktrees.sh`, `6_detect_orphans.sh`, `7_build_workspace.sh`, `8_migrate_sessions.sh`, `9_resolve_task_lifecycle.sh`) resolve the repo root via a bare, caller-cwd-based `git rev-parse --show-toplevel` (or bare `git worktree list --porcelain` for script 9), with no `SCRIPT_DIR`/`BASH_SOURCE`/`-C` involvement remaining
- [x] `2_validate_prereqs.sh` is left unchanged (already correct)
- [x] `SKILL.md` documents that Steps 1–8 require cwd = project root at invocation time, and `metadata.version` is bumped from `1.2.0`
- [x] `tests/skills/test-worktree-layout.sh` installs scripts outside the fixture repo and still passes
- [x] `tests/skills/test-parent-task-lifecycle.sh` installs scripts outside the fixture repo and still passes
- [x] `make test` passes in full

## Findings

**Implementation approach:**
- Replaced the `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` / `git -C "$SCRIPT_DIR" ...` idiom with bare, caller-cwd-based `git rev-parse --show-toplevel` (and bare `git worktree list --porcelain` for script 9) across all 8 affected scripts.
- Added Gotcha #16 to `SKILL.md` documenting the Steps 1–8 cwd contract, and hardened both `tests/skills/test-worktree-layout.sh` and `tests/skills/test-parent-task-lifecycle.sh` to install scripts outside the fixture repo, invoking with cwd explicitly set to the fixture repo to mirror real global-install topology.

**Decisions made:**
- Relied on caller cwd rather than threading an explicit repo-root argument through every invocation, matching the existing house pattern (`2_validate_prereqs.sh`, `smaqit.project-diagnose/scripts/diagnose-inventory.sh`, the Go CLI's `resolveDefaultProjectDir`).
- Included test-fixture hardening in scope since both fixtures' pre-existing design — copying scripts inside the fixture repo before invoking them — is exactly why this bug shipped undetected by `make test`.

**Blockers encountered:**
- None blocking. Discovered mid-implementation that the installed copy at `~/.claude/skills/smaqit.utils.worktree/scripts/` had already been manually patched to this exact fix out-of-band (explains the user's original "7 of 9" observation vs. the 8-of-9 canonical-source count — script 9 was already hand-fixed locally). Verified the canonical-source fix is byte-identical to that working patch, and separately confirmed regression-detection value by temporarily reintroducing the bug into `5_create_worktrees.sh` — `make test-worktree-layout` failed with `fatal: not a git repository` as expected, then restored.

**Follow-up identified:**
- `SKILL.md`'s `metadata.version` landed at `1.2.1` on this branch, but `main` separately bumped the same file to `1.2.1` for an unrelated stale-reference cleanup (commit `f01e95b`) before this merge. Since both changes are real and distinct, the version needs a follow-up bump to `1.2.2` post-merge to correctly reflect two independent changes since `1.2.0` — handled as part of this completion.

## Files to Create / Modify

| File | Action |
|------|--------|
| `skills/smaqit.utils.worktree/scripts/1_present_branches.sh` | Modify |
| `skills/smaqit.utils.worktree/scripts/3_compute_slugs.sh` | Modify |
| `skills/smaqit.utils.worktree/scripts/4_enumerate_worktrees.sh` | Modify |
| `skills/smaqit.utils.worktree/scripts/5_create_worktrees.sh` | Modify |
| `skills/smaqit.utils.worktree/scripts/6_detect_orphans.sh` | Modify |
| `skills/smaqit.utils.worktree/scripts/7_build_workspace.sh` | Modify |
| `skills/smaqit.utils.worktree/scripts/8_migrate_sessions.sh` | Modify |
| `skills/smaqit.utils.worktree/scripts/9_resolve_task_lifecycle.sh` | Modify |
| `skills/smaqit.utils.worktree/SKILL.md` | Modify — cwd contract + version bump |
| `tests/skills/test-worktree-layout.sh` | Modify — fixture hardening |
| `tests/skills/test-parent-task-lifecycle.sh` | Modify — fixture hardening |

## Notes

Discovered during `smaqit.session-start` on 2026-08-11 while reviewing the aftermath of task 023 (global user-level installation). Root cause and full script-by-script audit were confirmed via two parallel Explore agents; the test-fixture masking issue (fixtures copy scripts inside the repo they test) was found separately while scoping verification for this task. Not covered by any prior task file through 023.

Child tasks inherit their active parent's branch, worktree, and workflow mode. Only a standalone or parent task owns Git lifecycle cleanup.
