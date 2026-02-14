---
name: smaqit.task-start
description: Start working on a task. Supports autonomous mode (AI completes) or assisted mode (user approval required). Use when beginning work on tasks to set proper workflow.
metadata:
  version: "0.2.0"
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
2. **Determine mode** from command arguments (default: assisted)
3. **Update task status** to "In Progress"
4. **Store mode in task file** as metadata field:
   ```markdown
   **Mode:** Autonomous | Assisted
   ```
5. **Update PLANNING.md** to reflect "In Progress" status
6. **Load workflow rules** by reading [references/RULES.md](references/RULES.md)
7. **Begin implementation** following task requirements

## Task File Format with Mode

```markdown
# [Task Title]

**Status:** In Progress
**Mode:** Assisted
**Created:** YYYY-MM-DD
**Started:** YYYY-MM-DD

## Description
[Task description]

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2

## Notes
[Additional context]
```

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
