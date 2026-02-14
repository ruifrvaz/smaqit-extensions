---
name: smaqit.task-create
description: Create a new task with auto-numbering. Use when creating new tasks to track work.
metadata:
  version: "0.2.0"
---

# Task Create

Create a new task with the format: `task.create [title]` or `task.create [title] - [description] - [criteria]`

## Steps

1. Create new task file in `.smaqit/tasks/` directory
2. Filename: `.smaqit/tasks/NNN_task_title.md` (NNN = next available number, zero-padded to 3 digits)
3. Tasks are numbered sequentially starting at 001
4. **Add entry to `.smaqit/tasks/PLANNING.md`** with status "Not Started"

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

## Central Planning File

**Remember:** `.smaqit/tasks/PLANNING.md` contains status of all tasks (sorted by ID) and is the single source of truth for task overview.
