---
name: smaqit.task-start
description: Start working on a task. Supports autonomous mode (AI completes) or assisted mode (user approval required). Use when beginning work on tasks to set proper workflow.
metadata:
  version: "0.7.0"
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
2. **Research map verification** — check whether `.smaqit/references/project-research.md` exists:
   - If **absent** → invoke `smaqit.project-research [task-id]` before proceeding. Surface the resulting map in-context. Do not continue to Step 2a until the map is written.
   - If **present** → proceed without refreshing. The existing map is sufficient. Surface it in-context (render the table) so the implementing agent has documentation topology available.
2a. **Issue triage** — invoke `smaqit.utils.triage-issues` with the current task ID:
   - Skill reads the research map, extracts third-party tools, and searches GitHub for known open issues.
   - After triage returns, write/overwrite `## Known Issues Triage` in the task file using the format from `skills/smaqit.utils.triage-issues/references/TRIAGE_BLOCK.md`.
   - **If blocking issues found** → STOP. Do not continue to Step 3. Present findings and await user direction (proceed, reframe scope, or mark as Blocked).
   - **If advisory or clear** → continue to Step 3. Advisory findings are visible in-context but do not require approval.
   - **If triage exits cleanly** (skip flag, no tools, gh unavailable, registry missing) → continue to Step 3 silently.
   - If triage write-back fails, report a warning and continue (non-blocking).
3. **Determine mode** from command arguments (default: assisted)
4. **Update task status** to "In Progress"
5. **Store mode in task file** as metadata field:
   ```markdown
   **Mode:** Autonomous | Assisted
   ```
6. **Update PLANNING.md** to reflect "In Progress" status
7. **Store task state in memory** using the `store_memory` tool:
   - `subject`: `"task state"`
   - `fact`: `"[NNN] [Title] — In Progress ([Assisted|Autonomous], started YYYY-MM-DD)"` (≤ 200 chars)
   - `citations`: path to the task file (e.g., `.smaqit/tasks/NNN_task_title.md`)
   - `reason`: `"Ensures in-progress task and mode are visible in any branch, supporting parallel agent workflows"`
8. **Load workflow rules** by reading [references/RULES.md](references/RULES.md)
9. **Begin implementation** following task requirements

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
