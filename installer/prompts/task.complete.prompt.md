---
name: task.complete
description: Mark a task as completed with verification
---

# Task Complete

Mark a task as done with the format: `task.complete [id]`

## Steps

1. Read the task file to review acceptance criteria
2. **Verify all criteria are met** - Do NOT complete if any criteria remain unfinished
3. Check off completed acceptance criteria (`- [x]`)
4. Move task from Active table to appropriate destination in `PLANNING.md`:
   - **Completed** if successfully finished
   - **Abandoned** if superseded, no longer relevant, or incorrect approach (include reason)
5. Update individual task file status appropriately

## Requirements

- **CRITICAL:** All acceptance criteria MUST be verified as complete (for Completed tasks)
- Do NOT mark as Completed if criteria remain unfinished
- Use Abandoned (not Completed) for tasks being superseded or discontinued
- Update both the individual task file AND the PLANNING.md file
- For Abandoned tasks, document the reason in PLANNING.md

## Central Planning File

**Remember:** `docs/tasks/PLANNING.md` contains three sections (Active, Completed, Abandoned) and must be updated when completing or abandoning tasks.
