---
name: smaqit.task-complete
description: Mark a task as completed by updating a task's status. Verify its acceptance criteria and record state in PLANNING.md. Use when marking a task as done — whether just implemented, retroactively closing completed work, or responding to a status update request. Follow the steps and mode-specific rules to ensure proper task management.
metadata:
  version: "0.4.0"
---

# Task Complete

Mark a task as done with the format: `task.complete [id]`

## Steps

1. **Load workflow rules** by reading [references/RULES.md](references/RULES.md)
2. Read the task file to review acceptance criteria **and task mode**
3. **Check task mode enforcement:**
   - **Assisted mode:** Verify this is user-invoked (not AI self-completion)
   - **Autonomous mode:** AI may self-complete after verification
4. **Verify all criteria are met** - Do NOT complete if any criteria remain unfinished
5. Check off completed acceptance criteria (`- [x]`)
6. Update task file status to "Completed" or "Abandoned" and add completion date
7. Move task from Active table to appropriate destination in `.smaqit/tasks/PLANNING.md`:
   - **Completed** if successfully finished
   - **Abandoned** if superseded, no longer relevant, or incorrect approach (include reason)
8. **Store task state in memory** using the `store_memory` tool:
   - `subject`: `"task state"`
   - `fact`: `"[NNN] [Title] — [Completed|Abandoned] (YYYY-MM-DD)"` (≤ 200 chars)
   - `citations`: path to the task file (e.g., `.smaqit/tasks/NNN_task_title.md`)
   - `reason`: `"Ensures final task state is visible in any branch without reading files, supporting parallel agent workflows"`

## Mode-Aware Enforcement

### Assisted Mode Tasks

**CRITICAL:** Assisted-mode tasks require user approval before completion.

**Agent behavior:**
- ⛔ **Agent MUST NOT invoke task-complete for assisted tasks**
- ✅ Agent implements the solution
- ✅ Agent provides completion summary
- ✅ Agent instructs user to run `/task.complete [id]` when ready

**Example agent response:**
> "Implementation complete. This is an assisted-mode task requiring your approval. Please review the changes and run `/task.complete 003` when satisfied."

### Autonomous Mode Tasks

**Agent behavior:**
- ✅ Agent implements the solution
- ✅ Agent verifies ALL acceptance criteria
- ✅ Agent MAY invoke task-complete autonomously
- ✅ Agent documents completion rationale

**Example agent response:**
> "All acceptance criteria verified. Task 005 completed autonomously."

## Requirements

- **CRITICAL:** All acceptance criteria MUST be verified as complete (for Completed tasks)
- **CRITICAL:** Check task mode before completing (read [references/RULES.md](references/RULES.md))
- Do NOT mark as Completed if criteria remain unfinished
- Do NOT complete assisted-mode tasks without user invocation
- Use Abandoned (not Completed) for tasks being superseded or discontinued
- Update both the individual task file AND the `.smaqit/tasks/PLANNING.md` file
- For Abandoned tasks, document the reason in `.smaqit/tasks/PLANNING.md`

## Task Mode Detection

Check the task file for mode metadata:

```markdown
**Mode:** Assisted | Autonomous
```

- If mode is missing, assume **Assisted** (default)
- Mode is set by `task-start` skill

## Central Planning File

**Remember:** `.smaqit/tasks/PLANNING.md` contains three sections (Active, Completed, Abandoned) and must be updated when completing or abandoning tasks.
