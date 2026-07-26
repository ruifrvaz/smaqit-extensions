# Converge Worktree-Aware Task Lifecycle

**Status:** Completed
**Created:** 2026-07-26
**Mode:** Assisted
**Started:** 2026-07-26
**Completed:** 2026-07-26

## Description

Integrate a proven branch, Git worktree, and VS Code multi-root workspace workflow into the canonical smaqit skill sources.

Every `task.start` creates or reuses a `task/NNN-title` branch and sibling worktree. `task.complete` merges the task branch, removes its worktree, safely deletes the merged branch, and rebuilds the workspace file. This is a skill-level workflow refactor; it does not add a binary command or new lifecycle architecture.

## Design Decisions

- **Implementation:** Reuse the proven `smaqit.utils.worktree` workflow and scripts rather than adding an installer command.
- **Task start:** Branch and worktree creation happen for every started task using `task/NNN-kebab-title`.
- **Task completion:** Merge into `main`, remove the registered worktree, safely delete the merged local branch, and rebuild the workspace.
- **Project portability:** Derive the repository name and sibling worktree prefix instead of hardcoding a project identity.
- **Workspace behavior:** Update an existing root `.code-workspace` file or create `<project>.code-workspace`.
- **Behavioral baseline:** Preserve the complete proven workflow instructions and script contracts; make only explicit portability and safety corrections.
- **Sparse checkout:** Preserve generated-scaffolding exclusions in task worktrees to prevent duplicate skill and agent discovery.
- **Session migration:** Include explicit opt-in VS Code chat-session migration with injectable storage paths and dependency checks.
- **Instruction contract:** Add an execute-skills-verbatim rule to the canonical smaqit project-instructions template.
- **Dependencies:** Preserve the proven Bash, Git, jq, and `realpath --relative-to` workflow.
- **Distribution:** Install the skill and scripts for Copilot, Claude Code, and Codex as the 29th skill.
- **Scope boundary:** No new Go command, lifecycle metadata, control-plane abstraction, or CI architecture.

## Implementation Steps

1. Use the proven worktree skill and eight scripts as the behavioral baseline, changing only hardcoded project paths, cross-platform storage discovery, and confirmed safety defects.
2. Preserve non-interactive task setup, interactive `worktree.sync`, sparse checkout, workspace generation, reporting, failure handling, and explicit session migration.
3. Port detailed branch derivation, complete worktree-skill execution, path reporting, and workspace reopen instructions into `smaqit.task-start`.
4. Port the merge/remove/delete lifecycle into `smaqit.task-complete`, using registered worktree paths and refusing force removal.
5. Add the execute-skills-verbatim rule to the canonical project-instructions template.
6. Register the 29th skill in the generator/dogfooding list and installer help counts.
7. Update README and CHANGELOG with the complete skill-level workflow.
8. Generate all platform targets; test branch creation, sparse checkout, workspace generation, cleanup, and session migration in temporary fixtures; then run existing installer tests.

## Known Issues Triage

**Triaged:** 2026-07-26
**Tools searched:** Go, Git, Visual Studio Code, GitHub Actions
**Result:** Advisory

### Advisory Issues
- [#293123 VS Code switches to wrong instance to commit code in multi-root workspace](https://github.com/microsoft/vscode/issues/293123) — `microsoft/vscode` — opened 2026-02-05 — no labels
- [#285712 "Error creating worktree"](https://github.com/microsoft/vscode/issues/285712) — `microsoft/vscode` — opened 2026-01-03 — bug, git
- [#257396 Multiple Repos with git worktrees in workspace](https://github.com/microsoft/vscode/issues/257396) — `microsoft/vscode` — opened 2025-07-23 — bug, help wanted, scm
- [#282806 Support .code-workspace.local files for untracked local setting overrides](https://github.com/microsoft/vscode/issues/282806) — `microsoft/vscode` — opened 2025-12-11 — feature-request, config, workbench-multiroot

### Historical (Closed)
- [#270697 GHPR shows the same repo twice when using Git work trees in multi-root workspace](https://github.com/microsoft/vscode/issues/270697) — `microsoft/vscode` — closed 2025-12-08

## Acceptance Criteria

- [x] `task.start [id]` derives and creates or reuses `task/NNN-kebab-title`.
- [x] Starting a task creates or reuses its sibling worktree and rebuilds the root VS Code workspace.
- [x] `task.complete [id]` merges the task branch, removes its worktree, safely deletes the merged branch, and rebuilds the workspace.
- [x] The worktree scripts derive project names and paths without project-specific constants.
- [x] Existing registered worktrees are skipped without duplication.
- [x] Dirty worktrees are not force-removed.
- [x] Task worktrees preserve sparse-checkout exclusions for generated platform scaffolding while retaining canonical project source.
- [x] `worktree.migrate-sessions` is installed as an explicit opt-in operation with storage-path injection, dependency validation, and idempotent delta migration.
- [x] Canonical project instructions require agents to execute every documented skill script in order without streamlining.
- [x] The new skill and scripts are generated and installed for Copilot, Claude Code, and Codex, increasing the skill count to 29.
- [x] Temporary-repository script checks cover slugging, enumeration, creation, sparse checkout, workspace generation, cleanup, and session migration.
- [x] Existing Go tests, installer tests, synchronization checks, and installer smoke tests pass.
- [x] README, installer help counts, and CHANGELOG describe the workflow.

## Findings

**Implementation approach:**
- Ported the proven eight-script worktree workflow into canonical skill sources and generated platform targets.
- Integrated branch, worktree, workspace, sparse-checkout, cleanup, and opt-in session migration behavior into task start and completion.

**Decisions made:**
- Kept worktree management at the skill layer with no new installer command.
- Preserved the base repository's canonical-source model while deriving all project names and paths.

**Blockers encountered:**
- Initial implementations were rolled back or expanded until they preserved the complete proven workflow without project-specific content.

**Follow-up identified:**
- Corrected release-boundary detection so local and PR release markers remain compatible across all generated targets.

## Files to Create / Modify

| File | Action |
|------|--------|
| `skills/smaqit.utils.worktree/SKILL.md` | Create |
| `skills/smaqit.utils.worktree/scripts/*.sh` | Create |
| `skills/smaqit.task-start/SKILL.md` | Modify |
| `skills/smaqit.task-complete/SKILL.md` | Modify |
| `.smaqit/templates/copilot-instructions.template.md` | Modify |
| `Makefile` | Modify |
| `installer/main.go` | Modify skill counts only |
| `README.md` | Modify |
| `CHANGELOG.md` | Modify |

## Notes

- Convergence assessment: `docs/parity/reference-scaffolding/ASSESSMENT.md`.
- The proven worktree implementation is the behavioral source for this refactor.
- The first Task 018 implementation was intentionally rolled back after it introduced an unnecessary Go command and broad lifecycle architecture.
- The second implementation was reassessed because it streamlined documented task-start and worktree steps and excluded sparse checkout and session migration.
