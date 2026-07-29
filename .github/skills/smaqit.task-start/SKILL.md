---
name: smaqit.task-start
description: Start working on a task by creating its task branch and worktree, updating the VS Code workspace, and setting assisted or autonomous workflow mode.
metadata:
  version: "0.9.0"
---

# Task Start

Start working on a task with specified workflow mode: autonomous or assisted.

## Usage

```
task.start [id]                    # Assisted mode (default) - requires user approval
task.start [id] --autonomous       # Autonomous mode - AI completes task
task.start [id] --assisted         # Explicit assisted mode
```

## Modes

### Assisted Mode (Default)

**Workflow:** AI implements → STOPS → User approves → User completes

- Agent implements the task
- Agent STOPS and hands back to user
- Agent MUST NOT invoke task-complete
- User reviews work and invokes `/task.complete [id]` if satisfied

**Use for:**
- Complex features requiring validation
- User-facing changes
- Changes requiring human judgment
- Quality gates before completion

### Autonomous Mode

**Workflow:** AI implements → AI verifies → AI completes

- Agent implements the task
- Agent verifies acceptance criteria
- Agent invokes task-complete autonomously
- No user approval gate required

**Use for:**
- Automated workflows (CI/CD pipelines)
- Batch operations
- Well-defined tasks with clear success criteria
- Non-critical refactoring

## Steps

1. **Read task file** (`.smaqit/tasks/NNN_*.md`) to understand requirements
   - If `## Findings` already contains non-placeholder content, surface it in context for continuity:
     - Print: `Existing findings loaded from previous execution: [summary]`

2. **Resolve lifecycle ownership** — run from the primary checkout, before creating any branch or worktree:
   ```bash
   bash .github/skills/smaqit.utils.worktree/scripts/9_resolve_task_lifecycle.sh \
     --task NNN --purpose start [--requested-mode assisted|autonomous]
   ```
   - Capture the JSON result: `kind`, `parent`, `branch`, `worktree`, `mode`, and `task_file`.
   - A task without `**Parent:** NNN` is an `owner`; it keeps the standalone lifecycle below.
   - A child requires an active registered parent worktree. The resolver rejects a missing, inactive, nested, self-referential, cyclic, or mode-conflicting relationship. Do not create a fallback child branch or worktree.
   - Sparse task worktrees intentionally omit installed skills, so always invoke the resolver from the primary checkout. The returned worktree is the only location for child task state.

3. **Set up the owner worktree or join the parent**:
   - **Owner:** create or reuse the resolver's `branch` from `main`, then execute every documented `smaqit.utils.worktree` setup step in order. Capture its returned worktree and workspace paths. Resolve the task file inside that returned worktree before updating task state.
   - **Child:** reuse the resolver's `branch`, `worktree`, and `task_file`. Do not invoke branch creation, worktree setup, orphan cleanup, or workspace rebuilding.
   - Inform the user of the resolved ownership and path. For an owner, say `Branch "<branch>" created with worktree at <worktree-path>.`; for a child, say `Task NNN joined parent task <parent> at <worktree-path>.` In both cases, remind them to open the root workspace with `code <workspace-path>` when it changed.

4. **Research map verification** — check whether `.smaqit/references/project-research.md` exists:
   - If **absent** → invoke `smaqit.project-research [task-id]` before proceeding. Surface the resulting map in-context. Do not continue to Step 4a until the map is written.
   - If **present** → proceed without refreshing. The existing map is sufficient. Surface it in-context (render the table) so the implementing agent has documentation topology available.

4a. **Issue triage** — invoke `smaqit.utils.triage-issues` with the current task ID:
   - Skill reads the research map, extracts third-party tools, and searches GitHub for known open issues.
   - After triage returns, write/overwrite `## Known Issues Triage` in the task file using the format from `skills/smaqit.utils.triage-issues/references/TRIAGE_BLOCK.md`.
   - **If blocking issues found** → STOP. Do not continue to Step 5. Present findings and await user direction (proceed, reframe scope, or mark as Blocked).
   - **If advisory or clear** → continue to Step 5. Advisory findings are visible in-context but do not require approval.
   - **If triage exits cleanly** (skip flag, no tools, gh unavailable, registry missing) → continue to Step 5 silently.
   - If triage write-back fails, report a warning and continue (non-blocking).

5. **Determine effective mode** from the resolver result.
   - Owners use the requested mode or Assisted by default.
   - Children inherit the active parent mode. A supplied conflicting child mode is an error, not an override.
6. **Update the resolved task file status** to "In Progress"
7. **Store the effective mode in the resolved task file** as metadata field:
   ```markdown
   **Mode:** Autonomous | Assisted
   ```
8. **Update the resolved worktree's PLANNING.md** to reflect "In Progress" status. Child state remains branch-local until the parent merge.
9. **If a persistent, cross-session memory/notes capability is available in this environment**, use it to record task state (best-effort — `PLANNING.md` and the task file remain the source of truth regardless):
   - `subject`: `"task state"`
   - `fact`: `"[NNN] [Title] — In Progress ([Assisted|Autonomous], started YYYY-MM-DD)"` (≤ 200 chars)
   - `citations`: path to the task file (e.g., `.smaqit/tasks/NNN_task_title.md`)
   - `reason`: `"Ensures in-progress task and mode are visible in any branch, supporting parallel agent workflows"`
10. **Load workflow rules** by reading [references/RULES.md](references/RULES.md) from the primary checkout when the target worktree is sparse.
11. **Begin implementation** in the task worktree following task requirements

## Task File Format

See [.smaqit/templates/task.template.md](.smaqit/templates/task.template.md) for the canonical task file structure.

This skill adds the effective **Mode** field (`Autonomous` or `Assisted`) and the **Started** field (set to today's date) when starting a task. A child also retains its declared **Parent** field and never receives a child-specific branch or worktree.

## Critical Rules

⚠️ **Read [references/RULES.md](references/RULES.md) for complete workflow enforcement rules**

**For Assisted Mode:**
- Agent MUST NOT complete the task autonomously
- Agent MUST stop after implementation and hand back to user
- Only user can invoke `/task.complete [id]`

**For Autonomous Mode:**
- Agent MUST verify all acceptance criteria before completing
- Agent invokes `task-complete` after verification
- Agent should document completion rationale

## Examples

### Starting an Assisted Task

```
User: /task.start 003
Agent: [resolves task 003 as an owner, creates its branch/worktree, sets mode to Assisted, updates status]
Agent: [implements the task]
Agent: "Task 003 implementation complete. Please review and run /task.complete 003 when satisfied."
```

### Starting an Autonomous Task

```
User: /task.start 005 --autonomous
Agent: [resolves task 005 as an owner, sets mode to Autonomous, updates status]
Agent: [implements the task]
Agent: [verifies criteria]
Agent: [invokes task-complete 005]
Agent: "Task 005 completed autonomously. All criteria verified."
```

### Starting a Child Task

```
User: /task.start 021
Agent: [resolves Parent: 020 as In Progress in its registered worktree]
Agent: [sets task 021 In Progress in the parent worktree and inherits the parent mode]
Agent: "Task 021 joined parent Task 020 at <worktree-path>; no child branch or worktree was created."
```
