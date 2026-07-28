---
name: smaqit.task-start
description: Start working on a task by creating its task branch and worktree, updating the VS Code workspace, and setting assisted or autonomous workflow mode.
metadata:
  version: "0.8.0"
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

2. **Create task branch** — derive a branch name from the task and create it:
   - Derive the branch name from the task ID and title:
     - Take the task ID (e.g., `091`) and the task title.
     - Convert the title to kebab-case: lowercase, replace spaces and special characters with `-`.
     - Format: `task/NNN-kebab-title` (e.g., `task/091-fix-something`).
   - Create the branch from `main`:
     ```bash
     git branch "<branch-name>" main
     ```
   - If the branch already exists, reuse it rather than creating a duplicate.

3. **Create task worktree** — invoke `smaqit.utils.worktree` to set up a worktree for the new branch:
   - Execute every documented worktree skill step in order, passing the new branch name as the target selection. Do not replace, skip, merge, or streamline its scripts.
   - The skill validates prerequisites, computes the project-prefixed slug, creates or reuses the worktree, cleans safe orphans, updates the root `.code-workspace` file, and reports the result.
   - Capture the actual worktree and workspace paths returned by the skill.
   - After completion, inform the user:
     - `Branch "<branch-name>" created with worktree at <worktree-path>.`
     - `Open VS Code with \`code <workspace-path>\` to see it in the multi-root workspace.`
   - Continue implementation from the returned worktree path.

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

5. **Determine mode** from command arguments (default: assisted)
6. **Update task status** to "In Progress"
7. **Store mode in task file** as metadata field:
   ```markdown
   **Mode:** Autonomous | Assisted
   ```
8. **Update PLANNING.md** to reflect "In Progress" status
9. **If a persistent, cross-session memory/notes capability is available in this environment**, use it to record task state (best-effort — `PLANNING.md` and the task file remain the source of truth regardless):
   - `subject`: `"task state"`
   - `fact`: `"[NNN] [Title] — In Progress ([Assisted|Autonomous], started YYYY-MM-DD)"` (≤ 200 chars)
   - `citations`: path to the task file (e.g., `.smaqit/tasks/NNN_task_title.md`)
   - `reason`: `"Ensures in-progress task and mode are visible in any branch, supporting parallel agent workflows"`
10. **Load workflow rules** by reading [references/RULES.md](references/RULES.md)
11. **Begin implementation** in the task worktree following task requirements

## Task File Format

See [.smaqit/templates/task.template.md](.smaqit/templates/task.template.md) for the canonical task file structure.

This skill adds the **Mode** field (set to `Autonomous` or `Assisted`) and the **Started** field (set to today's date) when starting a task.

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
Agent: [reads task 003, sets mode to Assisted, updates status]
Agent: [implements the task]
Agent: "Task 003 implementation complete. Please review and run /task.complete 003 when satisfied."
```

### Starting an Autonomous Task

```
User: /task.start 005 --autonomous
Agent: [reads task 005, sets mode to Autonomous, updates status]
Agent: [implements the task]
Agent: [verifies criteria]
Agent: [invokes task-complete 005]
Agent: "Task 005 completed autonomously. All criteria verified."
```
