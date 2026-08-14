# Global Install Reference Repair

**Date:** 2026-08-11
**Session focus:** Fixing fallout from the task-023 global-install migration — a worktree-script bug that broke repo-root resolution, and a broad sweep of stale documentation/skill-source still describing the retired per-project committed-mirror model
**Tasks completed:** 024 — Fix Worktree Script Repo-Root Resolution for Global Install
**Tasks referenced:** 002, 007, 010 (untouched, still Not Started); 023 (root cause of everything this session addressed)

## Actions Taken

- Started session with `smaqit.session-start`; loaded context — 3 open tasks (002, 007, 010), all Not Started, no in-progress work.
- User reported a real bug from the global-install migration: 7 of 9 `smaqit.utils.worktree` scripts resolve the git repo root from their own installed script location instead of the caller's cwd. Planned via `smaqit.task-plan` (Mode A): two parallel Explore agents confirmed 8 of 9 scripts (not 7) affected in canonical source, and found the correct cwd-based pattern already used by `2_validate_prereqs.sh`. Created and started Task 024 (Assisted mode).
- Mid-implementation discovery: the *installed* copy at `~/.claude/skills/smaqit.utils.worktree/scripts/` had already been manually patched to the exact intended fix out-of-band — explaining the user's original "7 of 9" count (script 9 was already hand-fixed locally, leaving 7 visibly broken) vs. the 8-of-9 canonical-source count. Verified the new fix was byte-identical to that working patch.
- Implemented: replaced the `SCRIPT_DIR`/`BASH_SOURCE` + `git -C` idiom with bare, caller-cwd-based `git rev-parse --show-toplevel` (or bare `git worktree list --porcelain`) across all 8 scripts; documented the cwd contract in `SKILL.md` (Gotcha #16); hardened both `tests/skills/test-worktree-layout.sh` and `tests/skills/test-parent-task-lifecycle.sh`, which previously masked this exact bug class by installing scripts inside the fixture repo before invoking them. Verified regression-detection by temporarily reintroducing the bug and confirming the hardened test failed as expected.
- Stopped for Assisted-mode review per workflow rules.
- User asked for a project-wide scan for other stale references to the old per-project mirror model. Found and fixed directly on `main` (not task-tracked, per established convention of direct fixes for small doc/CI issues): `.github/copilot-instructions.md` (self-contradictory — said "no committed mirrors" while still instructing `make sync` to populate `.github/` and citing a nonexistent `test-sync.yml` CI gate), two stale Q&A entries in `.smaqit/compendium.md`, a stale docstring in `scripts/generate-targets.py`, and an orphaned duplicate `templates/copilot-instructions.template.md` at repo root (confirmed dead — traced the real build path to `.smaqit/templates/` only; already flagged as a removal candidate in task 023's own notes and never acted on).
- User then reported a second bug: `smaqit.project-init` failed in a consumer project because `.smaqit/templates/copilot-instructions.template.md` was missing, with the skill's own remediation message pointing at `smaqit-extensions install --scope project` — an internal/testing-only command dropped from the public CLI surface back in v1.14.1. User proposed deprecating `.github/copilot-instructions.md` entirely in favor of `AGENTS.md`, and relocating/renaming the template. Invoked `smaqit.session-assess` (explicit trigger word).
- Assessment finding: `.github/copilot-instructions.md` was **already** fully deprecated as content — `smaqit.project-init` has created it as a relative symlink to `../AGENTS.md` since its inferential-merge design, never separate content. The real, narrower bugs were the stale CLI-command remediation text and the misleadingly-named template (its content seeds `AGENTS.md`, not Copilot-specific instructions).
- User approved the "wide fix" with backward compatibility explicitly deprioritized (sole consumer). Moved `.smaqit/templates/copilot-instructions.template.md` → `skills/smaqit.project-init/references/AGENTS.template.md` (skill-bundled, always present at install time — eliminates the missing-template failure mode structurally, following the existing `smaqit.task-create/assets/TASK_TEMPLATE.md` precedent). Fixed `SKILL.md`'s read step and error message; bumped its version 0.5.0 → 0.6.0.
- Self-caught regression: initially wrote the new template reference using the `[SMAQIT_SKILLS_DIR]` placeholder, which resolves to a *different* literal path per platform — this broke `smaqit.project-init`'s own "compiled output must be byte-identical across Copilot/Claude/Codex" contract, caught immediately by `make smoke-test`. Fixed by switching to a plain relative path (matching the `smaqit.task-start` → `references/RULES.md` convention), reverted the now-incorrect compendium mention, reran the full smoke test to confirm green.
- Re-swept for the same "dogfooding mirror" staleness pattern while verifying the fix and found three more currently-active instances that the first pass missed: `README.md`, `skills/smaqit.utils.worktree/SKILL.md` (two clauses), and a second `.smaqit/compendium.md` Q&A entry — all asserting or conditionally implying this repository still carries committed per-project mirrors. Fixed all three.
- User said "complete task" — completed Task 024. Committed the wide-fix cleanup on `main` first (since it touched the same `SKILL.md` task 024 also modified, avoiding a dirty-tree merge), then committed task 024's implementation and merged with `--no-ff`. Both changes had independently bumped `smaqit.utils.worktree`'s version to `1.2.1`; the merge auto-resolved that collision silently (identical string on both sides), so added one follow-up commit bumping to `1.2.2` to correctly represent two independent changes since `1.2.0`. Removed the task worktree, deleted the branch, rebuilt the workspace file.

## Problems Solved

- **Root cause:** task 023's move from per-project committed skill/agent mirrors to global user-level installation broke every script in `smaqit.utils.worktree` that derived its own repo root from `${BASH_SOURCE[0]}` — those scripts now live outside any project entirely, so `git -C "$(dirname "${BASH_SOURCE[0]}")"` resolves the wrong repo (or errors).
- **Detection gap:** both hermetic test fixtures for this skill copied the scripts *inside* the fixture repo before invoking them, which happened to make the buggy resolution succeed under test — so `make test` could not have caught this regression even though it existed since task 023 shipped. Fixed structurally, not just patched.
- **Documentation drift class:** the global-install migration (and the subsequent "remove committed dogfooding mirrors" commit) left roughly a dozen currently-active references across `README.md`, `.github/copilot-instructions.md`, `.smaqit/compendium.md`, `scripts/generate-targets.py`, and two skill `SKILL.md` files still describing the retired architecture as current. All identified and corrected; historical files (`.smaqit/history/`, completed task files, `CHANGELOG.md`) deliberately left untouched as point-in-time records.
- **Consumer-facing failure mode:** `smaqit.project-init`'s dependency on a project-scaffolded template file (rather than a skill-bundled one) meant any project whose `.smaqit/templates/` was incomplete or stale would hit a hard stop with a remediation instruction pointing at a command no longer in the public CLI. Eliminated by relocating the template to ship with the skill itself.

## Decisions Made

- Direct fixes on `main` for documentation/skill-source staleness, no task created — consistent with prior guidance that small CI/infra-adjacent corrections don't need the full task lifecycle.
- Worktree scripts rely on caller cwd (bare `git rev-parse --show-toplevel`), not an explicit repo-root argument threaded through every invocation — matches the existing house pattern used elsewhere in the codebase.
- Template relocation: skill-bundled reference over project-scaffolded file, since the content is smaqit-owned boilerplate with no per-project customization expected (all project-specific detail is inference-filled at `project-init` runtime, not template-edited).
- Committed the unrelated cleanup fix before merging task 024, rather than merging over a dirty working tree that touched the same file.

## Files Modified

**Task 024 (worktree fix):**
- `skills/smaqit.utils.worktree/scripts/{1,3,4,5,6,7,8,9}_*.sh` — repo-root resolution fix
- `skills/smaqit.utils.worktree/SKILL.md` — Gotcha #16, version 1.2.0 → 1.2.2 (see version-collision note above)
- `tests/skills/test-worktree-layout.sh`, `tests/skills/test-parent-task-lifecycle.sh` — fixture hardening

**Stale-reference cleanup (direct, untracked):**
- `.github/copilot-instructions.md`, `.smaqit/compendium.md`, `README.md`, `scripts/generate-targets.py`, `scripts/smoke-test-installer.sh`, `skills/smaqit.project-recap/references/OUTPUT_FORMAT.md`

**project-init template relocation:**
- `.smaqit/templates/copilot-instructions.template.md` → `skills/smaqit.project-init/references/AGENTS.template.md` (renamed, git-tracked move)
- `skills/smaqit.project-init/SKILL.md` — version 0.5.0 → 0.6.0
- `templates/copilot-instructions.template.md` (root-level) — deleted, confirmed orphaned

## Next Steps

- Tasks 002, 007, 010 remain open (Not Started), unchanged this session — next candidate is likely 002 (smallest, still accurate per last session's assessment).
- No other in-progress work; working tree clean, all tests and the full smoke test green as of session end.

## Session Metrics

- **Duration:** Full session, single continuous thread
- **Tasks completed:** 1 (024)
- **Commits:** 6 (`f01e95b`, `811d0bc`, `29da37b` merge, `9bb8c6d`, `7ddf81b`, plus the task-024 branch commit folded into the merge)
- **Files modified/moved/deleted:** ~20 across the worktree fix, stale-reference cleanup, and template relocation
- **Bugs found and fixed:** 3 (worktree repo-root resolution; project-init missing-template due to stale CLI reference; a self-introduced `[SMAQIT_SKILLS_DIR]` regression caught by the smoke test before it shipped)
