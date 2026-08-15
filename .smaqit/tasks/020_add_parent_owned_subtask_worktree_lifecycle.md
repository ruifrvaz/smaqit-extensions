---
status: Completed
mode: Assisted
created: "2026-07-29"
started: "2026-07-29"
completed: "2026-07-29"
---

# Add Parent-Owned Subtask Worktree Lifecycle

## Description

Extend the task lifecycle so a feature cycle can use one parent-owned branch and worktree while recording multiple child tasks independently. Today every `task.start` derives a new task branch and worktree, and every `task.complete` merges that branch into `main` and removes its worktree. That works for standalone tasks but breaks sequential multi-phase feature workflows.

A parent feature-cycle task must own the only branch/worktree for its children. Child tasks must inherit that location, retain their own task state and findings, and never create, merge, or remove Git resources. The parent closes the shared lifecycle only after every child is completed.

## Design Decisions

- **Generic parent metadata:** Add optional `**Parent:** NNN` task metadata to both task templates. The behavior belongs in the reusable task lifecycle, not in a feature-specific override.
- **Single lifecycle owner:** A standalone task or parent task owns its branch and worktree. A child task joins its declared parent's active branch and worktree.
- **Parent precondition:** Starting a child requires its parent to be `In Progress`; do not implicitly start the parent or create a fallback child branch.
- **Mode inheritance:** Children inherit their parent's Assisted or Autonomous mode. Reject a conflicting child mode argument.
- **Deterministic lifecycle resolution:** Add a worktree-skill resolver script that is run from the primary checkout and returns the owner/child relationship, active worktree, branch, and effective mode. Prompt instructions invoke this script rather than reconstructing parent state ad hoc.
- **Completion split:** Child completion validates criteria, writes findings, and updates task state only. Parent completion accepts only `Completed` children, then alone merges and cleans up.
- **Relationship limits:** Reject missing, self-referential, nested, and cyclic parent relationships in this first version. A blocked or abandoned child prevents parent completion until the user explicitly resolves the cycle.
- **Branch-local task state:** Child metadata and status live in the parent worktree until the parent merge; lifecycle calls resolve the owner's registered worktree instead of assuming the primary checkout is current.
- **Feature workflow adoption:** The sister feature-cycle workflow can adopt this contract after it separately resolves its Phase 3 PR merge versus post-deployment phase behavior.
- **Concurrency boundary:** Shared-parent children are for sequential or coordinated work in one worktree. Parallel independent editing remains out of scope.

## Implementation Steps

1. Reconcile parent metadata in the task-creation asset template and the installed `.smaqit` template; update task creation to validate and create child records in the active parent's worktree.
2. Add a deterministic resolver to `smaqit.utils.worktree` that finds the registered owner worktree, validates parent state and relationship limits, and returns JSON describing the owner/child lifecycle and effective mode.
3. Update `smaqit.task-start` to invoke the resolver before branch/worktree actions. Preserve the existing owner path; attach eligible children to the resolved parent branch/worktree without creating child Git resources.
4. Update `smaqit.task-complete` so child completion performs findings, criteria, and status bookkeeping only. Gate owner cleanup on every declared child being `Completed`, then retain the existing merge/remove/delete/workspace sequence exactly once.
5. Update task-list, lifecycle rules, worktree guidance, and README documentation to describe ownership, inherited mode, branch-local task state, and sequential-work boundaries.
6. Add hermetic resolver and Git-topology coverage for parent plus sequential children, parent completion gating, final owner cleanup, and standalone-task compatibility. Wire the tests into root Make and CI gates.
7. Regenerate Copilot, Claude Code, and Codex outputs; run targeted lifecycle coverage, sync parity checks, Go tests, and installer smoke tests. Record the resulting generic contract for the related feature workflow without modifying that workflow here.

## Known Issues Triage

**Triaged:** 2026-07-29
**Tools searched:** None — no third-party tools identified
**Result:** Clear

### Blocking Issues
- None.

### Advisory Issues
- None.

### Historical (Closed)
- None.

### Unresolvable Tools
- None.

## Acceptance Criteria

- [x] Both canonical task templates support documented optional `Parent: NNN` metadata, while existing standalone task files remain valid.
- [x] Task creation validates declared parent relationships and creates child task records in the active parent worktree.
- [x] A deterministic resolver returns the owner/child relationship, registered worktree, branch, and effective mode; it rejects missing, inactive, self-referential, nested, and cyclic parent relationships with actionable errors.
- [x] Starting a parent creates or reuses exactly one branch and one worktree using the existing lifecycle.
- [x] Starting an eligible child reuses the active parent's branch and registered worktree, creates no child branch or worktree, and inherits the parent mode.
- [x] Starting a child whose parent is not In Progress, missing, or has no usable registered worktree stops safely with an actionable error.
- [x] Completing a child updates only child task state and findings; it does not merge, remove a worktree, delete a branch, or rebuild the workspace.
- [x] Completing a parent blocks unless every declared child is `Completed`; after all children complete, it performs the existing merge, worktree removal, branch deletion, and workspace refresh exactly once.
- [x] Task creation, start, completion, listing, mode rules, worktree guidance, and README consistently document lifecycle ownership and preserve standalone-task behavior.
- [x] Hermetic coverage executes resolver validation and proves the parent/child Git topology and standalone compatibility; generated Copilot, Claude Code, and Codex targets remain synchronized and installer tests pass.

## Findings

**Implementation approach:**
- Added a deterministic lifecycle resolver, parent metadata support, and ownership-aware task workflow guidance across all generated targets.

**Decisions made:**
- Standalone and parent tasks own Git resources; children inherit the parent branch, worktree, and mode under a single-level relationship model.

**Blockers encountered:**
- None. Completion used the branch-local resolver before its merge made it available in the primary checkout.

**Follow-up identified:**
- Adopt this generic lifecycle contract in the related feature-cycle workflow after its Phase 3 PR and deployment semantics are resolved.

## Files to Create / Modify

| File | Action |
|------|--------|
| `.smaqit/templates/task.template.md` | Modify — add optional parent-task metadata contract |
| `skills/smaqit.task-create/assets/TASK_TEMPLATE.md` | Modify — keep creation-time template metadata aligned |
| `skills/smaqit.task-create/SKILL.md` | Modify — support parent declaration and validation |
| `skills/smaqit.task-start/SKILL.md` | Modify — resolve parent lifecycle ownership before Git setup |
| `skills/smaqit.task-complete/SKILL.md` | Modify — distinguish child bookkeeping from parent cleanup |
| `skills/smaqit.task-list/SKILL.md` | Modify — display parent/child lifecycle state |
| `skills/smaqit.utils.worktree/SKILL.md` | Modify — document parent-owned lifecycle boundaries |
| `skills/smaqit.utils.worktree/scripts/9_resolve_task_lifecycle.sh` | Create — deterministically resolve and validate task ownership |
| `skills/smaqit.task-start/references/RULES.md` | Modify — align parent/child mode and start rules |
| `skills/smaqit.task-complete/references/RULES.md` | Modify — align parent/child completion rules |
| `skills/smaqit.task-list/references/RULES.md` | Modify — align parent/child listing rules |
| `README.md` | Modify — correct task-worktree ownership documentation |
| `Makefile` | Modify — expose parent-lifecycle coverage |
| `.github/workflows/test-integration.yml` | Modify — execute root lifecycle test gates |
| `tests/skills/test-parent-task-lifecycle.sh` | Create — hermetic parent/child lifecycle coverage |

## Notes

Related to `smaqit` Task 095, which identified that a multi-phase feature workflow currently invokes the uniform task lifecycle once per phase while assuming one feature branch. This task intentionally delivers the generic lifecycle support. The feature workflow will adopt it separately after resolving its Phase 3 PR merge and later-phase write semantics.
