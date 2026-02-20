---
name: smaqit.task-create
description: Create a new task with auto-numbering. Use when creating new tasks to track work.
metadata:
  version: "0.3.0"
---

# Task Create

Create a new task with the format: `task.create [title]` or `task.create [title] - [description] - [criteria]`

⚠️ **CRITICAL:** Task creation is a **planning activity** that MUST stop after completion. Do NOT implement the task after creating it.

## Steps

1. **Load creation rules** by reading [references/RULES.md](references/RULES.md)
2. Create new task file in `.smaqit/tasks/` directory
3. Filename: `.smaqit/tasks/NNN_task_title.md` (NNN = next available number, zero-padded to 3 digits)
4. Tasks are numbered sequentially starting at 001
5. **Add entry to `.smaqit/tasks/PLANNING.md`** with status "Not Started"
6. **STOP and hand back to user** - do NOT implement or start the task

## Flexible Input Formats

- `task.create Fix RAG chunking` - Title only (prompt for details or infer from context)
- `task.create Fix RAG chunking - Chunks are too large for embedding model` - Title + description
- `task.create Fix RAG chunking - Chunks too large - Chunks under 512 tokens, Tests pass` - Full specification

## Task File Format

```markdown
# [Task Title]

**Status:** Not Started | In Progress | Completed | Blocked  
**Created:** YYYY-MM-DD

## Description
[Clear description of what needs to be done]

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2

## Notes
[Optional additional context]
```

## Critical Directives

### ✅ Agent MUST

- **MUST** create the task file with provided information
- **MUST** add entry to PLANNING.md with "Not Started" status
- **MUST** stop immediately after task creation
- **MUST** inform user how to start the task

### ⛔ Agent MUST NOT

- **MUST NOT** implement the task after creating it
- **MUST NOT** automatically invoke `task-start` skill
- **MUST NOT** ask questions about implementation details
- **MUST NOT** offer implementation suggestions
- **MUST NOT** proceed to coding or making changes

⚠️ **Read [references/RULES.md](references/RULES.md) for complete workflow enforcement rules**

## Workflow Boundary

**Task creation is separate from task implementation:**

```
task.create → Create file → Update PLANNING.md → STOP → User decides → task.start → Implementation
```

**After creating a task, respond with:**
> "Task [ID] created: [Title]
> 
> Status: Not Started
> File: `.smaqit/tasks/[ID]_[title].md`
> 
> To begin work on this task, use: `task.start [ID]`"

Then **STOP**. Do not continue with implementation.

## Central Planning File

**Remember:** `.smaqit/tasks/PLANNING.md` contains status of all tasks (sorted by ID) and is the single source of truth for task overview.
