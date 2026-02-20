# Task Create Rules

**Version:** 0.1.0  
**Purpose:** Enforce proper task creation workflow and prevent premature implementation

This document defines the rules for task creation. These rules ensure that task creation is a **planning activity** separate from implementation, and that agents do not immediately proceed to implement tasks after creating them.

---

## Task Creation is a Planning Activity

**Critical Principle:** Creating a task is a **planning** and **organization** activity, NOT an implementation activity.

**Task creation workflow:**
1. Create task file with requirements
2. Add entry to PLANNING.md
3. **STOP** - hand back to user
4. Wait for user to explicitly start the task

---

## Agent Behavior Rules

### ✅ Agent MUST

- **MUST** create the task file in `.smaqit/tasks/` directory
- **MUST** add entry to `.smaqit/tasks/PLANNING.md` with status "Not Started"
- **MUST** stop immediately after task creation
- **MUST** hand back to user after creation
- **MUST** inform user how to start the task (via `task.start [id]`)

### ⛔ Agent MUST NOT

- **MUST NOT** implement the task after creating it
- **MUST NOT** start the task automatically
- **MUST NOT** invoke `task-start` skill after creation
- **MUST NOT** ask questions about implementation details during creation
- **MUST NOT** offer implementation suggestions during creation
- **MUST NOT** proceed to coding or changes after creation

---

## Workflow Boundary

**Clear separation:**

```
task.create [title] → Create file → Update PLANNING.md → STOP
                                                          ↓
                                           User reviews and decides
                                                          ↓
                                         task.start [id] → Implementation begins
```

**The agent's job during task.create:**
- Capture requirements from user input
- Create structured task file
- Update planning file
- Return control to user

**The agent's job is NOT:**
- Implement the task
- Start working on the task
- Write code or make changes
- Ask clarifying questions about implementation

---

## Stopping Point Enforcement

**After task creation completes:**

Agent MUST respond with:
> "Task [ID] created: [Title]
> 
> Status: Not Started
> File: `.smaqit/tasks/[ID]_[title].md`
> 
> To begin work on this task, use: `task.start [ID]`"

Agent MUST NOT continue with implementation or offer to start the task.

---

## Flexible Input Handling

When user provides:
- **Title only:** Create task with title, add placeholder description
- **Title + description:** Create task with both
- **Full specification:** Create task with title, description, and criteria

**Do NOT** ask follow-up questions about implementation details. Accept whatever information is provided and create the task file accordingly.

---

## Common Pitfalls

### ❌ Pitfall 1: Implementing After Creating

**Problem:** Agent creates task then immediately starts implementing it

**Solution:** task-create MUST stop after creation. Implementation requires explicit task-start invocation.

### ❌ Pitfall 2: Asking Implementation Questions

**Problem:** Agent asks "Should I implement X?" or "Would you like me to Y?" after creating task

**Solution:** task-create is planning only. No implementation questions should be asked.

### ❌ Pitfall 3: Auto-starting Tasks

**Problem:** Agent invokes task-start immediately after task-create

**Solution:** User must explicitly start tasks. Agent cannot auto-start.

### ❌ Pitfall 4: Offering to Help

**Problem:** Agent offers suggestions or asks if user wants help with implementation

**Solution:** Simply create task and return control. Let user decide when to start.

---

## System Prompt Consideration

**Note for AI agents:**

The GitHub Copilot system prompt may instruct you to "implement instead of asking questions or offering suggestions." This directive applies to **active implementation work**, NOT to task creation.

**During task creation:**
- You are in **planning mode**, not implementation mode
- The "implement instead of asking" rule does NOT apply
- You MUST stop after creating the task
- You MUST NOT proceed to implementation

**The system prompt directive to implement applies ONLY when:**
- User has explicitly started a task with `task.start`
- User has given you an implementation instruction
- You are already working on an in-progress task

---

## Quick Reference

| Activity | Agent Creates | Agent Implements | Agent Asks Questions | User Invocation Required |
|----------|---------------|------------------|----------------------|--------------------------|
| **task.create** | ✅ Task file | ⛔ **NO** | ⛔ **NO** | `task.create [title]` |
| **task.start** | ❌ No | ✅ Yes (per mode) | ❌ No | `task.start [id]` |

**Critical Rule:** task.create → STOP → Wait for task.start
