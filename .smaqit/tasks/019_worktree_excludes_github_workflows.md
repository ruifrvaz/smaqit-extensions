---
status: Completed
mode: Assisted
created: "2026-07-27"
started: "2026-07-29"
completed: "2026-07-29"
---

# Repair Worktree Visibility and Sparse Checkout

## Description

Task worktrees must remain isolated from duplicate generated agents and skills without hiding project-owned configuration or making scaffolding disappear from the primary VS Code workspace.

The v1.9.0 workflow has two defects:

1. `scripts/5_create_worktrees.sh` excludes `.github/workflows/` and whole platform directories, making legitimate CI/CD and project configuration unavailable from task worktrees.
2. `scripts/7_build_workspace.sh` writes workspace-global `files.exclude` entries for scaffolding paths, hiding those paths from every root in a multi-root workspace, including `main`.

The original sparse checkout used:

```
'!.github/agents/' \
'!.github/skills/' \
'!.github/workflows/' \
'!.agents/' \
'!.codex/' \
'!.claude/' \
```

The sparse-checkout rationale applies only to generated mirror subdirectories. It must not suppress project-owned files, and workspace Explorer settings must not be used as a discovery-control mechanism.

`.github/workflows/` does not fit that rationale. For a downstream project using smaqit (not smaqit-extensions itself), `.github/workflows/` holds that *project's own* CI/CD — `deploy.yml`, `validation.yml`, release automation, and so on — authored and evolved as part of the project's own infrastructure, not generated smaqit scaffolding. There is no `.claude/workflows/` or `.agents/workflows/` equivalent anywhere, so no duplicate-discovery concern applies to it at all. It appears to have been swept into the exclusion list by association with the other `.github/*` paths rather than by deliberate design.

Discovered on test project (2026-07-27, task 016/021 — the same `smaqit.feature-new` cycle that surfaced the sister gap now tracked as task 094 in `~/projects/smaqit`). That task needed to add a new `.github/workflows/post-merge-release.yml` to the downstream project from within its task worktree; `git add .github/workflows/post-merge-release.yml` failed there with "paths ... matched paths that exist outside of your sparse-checkout definition." Worked around by temporarily checking out the task branch in the main (non-sparse) checkout, committing/pushing there, then returning — the task worktree itself could not be used for this legitimate, in-scope change.

This is the first time the worktree feature (shipped 2026-07-26) has been exercised by a task needing a `.github/workflows/` edit — every prior task on that downstream project predates the worktree feature entirely and worked directly in a non-sparse checkout, so the defect had no prior opportunity to surface.

## Design Decisions

- Keep sparse checkout for linked task worktrees, but exclude only known generated mirror subdirectories: `.github/agents/`, `.github/skills/`, `.claude/agents/`, `.claude/commands/`, `.claude/skills/`, `.agents/skills/`, and `.codex/agents/`.
- Always retain `.github/workflows/` and all other project-owned tool configuration in task worktrees.
- Remove all scaffolding paths from workspace-level `files.exclude`; retain build-output exclusions only. Workspace settings apply to every root and cannot safely distinguish `main` from a linked worktree.
- Configure sparse checkout with one validated `git sparse-checkout set --no-cone` command; do not transiently initialize cone mode or discard configuration errors.
- If sparse configuration fails after a worktree is created, disable sparse checkout in that new worktree, report the error, and leave the full checkout usable rather than reporting a broken sparse worktree as successful.
- Treat this as a PATCH release candidate (v1.9.1) after multi-platform generation and installer validation.

## Implementation Steps

1. Update `5_create_worktrees.sh` to use the exact generated-mirror exclusion list, preserve project-owned paths, and make sparse configuration failure-safe.
2. Update `7_build_workspace.sh` to keep only build-output exclusions and explain why platform paths remain visible.
3. Update `smaqit.utils.worktree/SKILL.md` so sparse and workspace behavior match the scripts.
4. Add a hermetic temporary-repository regression script that creates a task worktree, verifies main remains non-sparse and fully populated, verifies the task worktree includes `.github/workflows/`, verifies only generated mirrors are absent, and verifies a workspace rebuild does not hide platform paths.
5. Expose the regression through the root Makefile, regenerate Copilot, Claude Code, and Codex targets, and run the regression, Go tests, sync parity checks, and installer smoke test.

## Known Issues Triage

[Populated by smaqit.task-start via smaqit.utils.triage-issues. Do not edit manually.]

## Acceptance Criteria

- [x] A task worktree includes `.github/workflows/` and other project-owned platform configuration, allowing normal in-scope CI/CD and configuration edits.
- [x] A task worktree excludes only generated mirror subdirectories: `.github/agents/`, `.github/skills/`, `.claude/agents/`, `.claude/commands/`, `.claude/skills/`, `.agents/skills/`, and `.codex/agents/`.
- [x] The primary checkout remains non-sparse and retains all platform directories after task worktree creation.
- [x] A rebuilt `.code-workspace` never hides `.github`, `.claude`, `.agents`, or `.codex` from `main` or linked workspace roots.
- [x] Sparse-checkout setup reports failures and leaves the newly created worktree as a usable full checkout rather than silently accepting a partial state.
- [x] `smaqit.utils.worktree/SKILL.md` accurately documents the exact exclusions, workspace visibility, and failure behavior.
- [x] Hermetic regression coverage exercises creation, sparse layout, main checkout preservation, and workspace generation.
- [x] Copilot, Claude Code, and Codex generated targets remain synchronized; Go tests and installer smoke tests pass.

## Findings

[Populated by smaqit.task-complete. Do not fill in manually before task is complete.]

**Implementation approach:**
- Narrowed sparse exclusions to generated mirror directories and added a full-checkout fallback on setup failure.
- Reworked workspace generation to exclude only build output and added hermetic regression coverage.

**Decisions made:**
- Retained sparse task worktrees to prevent duplicate discovery while preserving project-owned configuration.
- Treated workspace Explorer visibility separately from sparse checkout behavior.

**Blockers encountered:**
- None; the regression reproduced and verified the reported downstream failure modes.

**Follow-up identified:**
- Publish the verified patch as v1.9.1.

## Files to Create / Modify

| File | Action |
|------|--------|
| `skills/smaqit.utils.worktree/scripts/5_create_worktrees.sh` | Modify — narrow sparse exclusions and make configuration failure-safe |
| `skills/smaqit.utils.worktree/scripts/7_build_workspace.sh` | Modify — preserve platform visibility in every workspace root |
| `skills/smaqit.utils.worktree/SKILL.md` | Modify — align the documented contract with sparse and workspace behavior |
| `tests/skills/test-worktree-layout.sh` | Create — hermetic worktree and workspace regression coverage |
| `Makefile` | Modify — expose the regression suite and include it in the smoke gate |

## Notes

triage: skip — this task repairs a confirmed local workflow contract; no third-party component is being introduced or selected.

Discovered on test project during task 016/021 (Decommission Frontend Variant A / Close-out phase), 2026-07-27, in the same session that also surfaced a sister gap now tracked as task 094 in `~/projects/smaqit` (`smaqit.feature-new` has no mandatory browser/E2E gate for frontend-touching features). Both gaps were caught by the same downstream user in the same session and explicitly asked to be fed back to their respective owning projects rather than left as one-off local workarounds — this task is that feedback loop for the worktree feature specifically, filed against `smaqit-extensions` (the actual canonical source of `smaqit.utils.worktree`, confirmed via `skills/smaqit.utils.worktree/` existing here and not in `~/projects/smaqit`) rather than the `smaqit` core project.
