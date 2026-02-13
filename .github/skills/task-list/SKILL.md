---
name: task-list
description: Show current active tasks. Use to view task overview from planning file.
metadata:
  version: "0.1.0"
---

# Task List

Show current tasks from the Active table.

## Steps

1. **Load workflow rules** by reading [references/RULES.md](references/RULES.md)
2. Read `.smaqit/tasks/PLANNING.md` only (not individual task files)
3. Show tasks from the Active table
4. **Display mode indicators** if tasks are in progress (read task files to check mode)

## Workflow Rules Context

⚠️ **Read [references/RULES.md](references/RULES.md) before working on tasks**

This loads critical workflow enforcement rules into context:
- Assisted vs Autonomous mode behavior
- Completion gate requirements
- When AI can/cannot complete tasks autonomously

## Output Format

Show tasks with status and mode indicators where applicable:

```
Active Tasks:
- [001] Fix bug in parser (Not Started)
- [003] Implement feature X (In Progress - Assisted) ⚠️ User approval required
- [005] Refactor utils (In Progress - Autonomous)
```

## Note

The central planning file `.smaqit/tasks/PLANNING.md` contains status of all tasks (sorted by ID) and is the single source of truth for task overview.

**Structure:**
- **Active** — Current work (in progress or not started)
- **Completed** — Successfully finished
- **Abandoned** — Discontinued (superseded, no longer relevant, incorrect approach)
