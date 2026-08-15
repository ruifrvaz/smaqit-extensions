---
name: smaqit.task-list
description: Show current active tasks. Use to view task overview from planning file.
metadata:
  version: "0.5.0"
---

# Task List

Show current tasks from the Active table.

## Steps

1. **Load workflow rules** by reading [references/RULES.md](references/RULES.md)
2. Read `.smaqit/tasks/PLANNING.md` on the primary checkout for the status overview — task worktrees never hold a copy.
3. Read active task files to resolve the `mode` and optional `parent` frontmatter keys. Do not infer relationships from titles.
4. Show tasks from the Active table. If a task is a child, display its parent ID and note that it shares the parent's branch/worktree.
5. **Display mode indicators** if tasks are in progress. A child mode is inherited from its active parent; surface a missing or contradictory parent relationship as a warning.

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
- [004] Add API contract tests (In Progress - Assisted, child of 003; shared worktree)
- [005] Refactor utils (In Progress - Autonomous)
```

## Note

The central planning file `.smaqit/tasks/PLANNING.md` lives exclusively on the primary checkout and is the single source of truth for every task's overview, owner and child alike. Parent/child metadata lives in task files, so listing requires both sources.

**Structure:**
- **Active** — Current work (in progress or not started)
- **Completed** — Successfully finished
- **Abandoned** — Discontinued (superseded, no longer relevant, incorrect approach)
