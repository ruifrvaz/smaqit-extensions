# Task Workflow Rules

**Version:** 0.1.0  
**Purpose:** Enforce proper task completion gates and workflow modes

This document defines the rules for task workflow execution. These rules are loaded into context when working with tasks to ensure proper approval gates and autonomous/assisted mode behavior.

---

## Workflow Modes

### Assisted Mode (Default)

**Lifecycle:** Start → Implement → **STOP** → User Approves → User Completes

**Agent Behavior:**
- ✅ Agent reads and understands task requirements
- ✅ Agent implements the solution
- ✅ Agent tests and verifies locally
- ⛔ **Agent MUST NOT invoke `/task.complete`**
- ✅ Agent hands back to user with completion summary

**User Behavior:**
- User reviews implementation
- User tests the changes
- User invokes `/task.complete [id]` when satisfied
- User can request changes if needed

**When to Use:**
- Complex features requiring human judgment
- User-facing functionality changes
- Security-sensitive modifications
- Changes requiring domain expertise validation
- Default mode for all tasks unless explicitly specified otherwise

### Autonomous Mode

**Lifecycle:** Start → Implement → Verify → Complete

**Agent Behavior:**
- ✅ Agent reads and understands task requirements
- ✅ Agent implements the solution
- ✅ Agent verifies ALL acceptance criteria are met
- ✅ Agent invokes `/task.complete [id]` autonomously
- ✅ Agent documents completion rationale

**When to Use:**
- CI/CD pipeline tasks
- Batch operations
- Well-defined refactoring with clear criteria
- Automated workflows
- Non-critical updates with objective success metrics

---

## Enforcement Rules

### Rule 1: Mode Detection

**Location:** Task file metadata

```markdown
**Mode:** Assisted | Autonomous
```

- Set by `task-start` skill during task initiation
- Defaults to "Assisted" if not specified
- Cannot be changed mid-task (restart task to change mode)

### Rule 2: Completion Gate (Assisted Mode)

**CRITICAL ENFORCEMENT POINT**

When task mode is "Assisted":
- Agent MUST read task file before attempting completion
- Agent MUST check mode metadata
- Agent MUST NOT invoke `task-complete`
- Agent MUST explain completion is user-gated
- Agent MUST provide clear summary for user review

**Example Response:**
> "Implementation complete. This is an assisted-mode task requiring your approval. Please review the changes and run `/task.complete 003` when ready."

### Rule 3: Self-Completion (Autonomous Mode)

When task mode is "Autonomous":
- Agent MUST verify ALL acceptance criteria
- Agent MUST document verification results
- Agent MAY invoke `task-complete [id]`
- Agent SHOULD explain completion rationale

**Example Response:**
> "All acceptance criteria verified:
> ✓ Criteria 1 met
> ✓ Criteria 2 met
> Task completed autonomously."

### Rule  4: Status Transitions

Valid status flows:
```
Not Started → In Progress → Completed
Not Started → In Progress → Blocked → In Progress → Completed
Not Started → In Progress → Abandoned
```

Invalid flows:
```
Not Started → Completed  (must use task-start first)
In Progress → Not Started  (cannot regress, abandon instead)
```

---

## Implementation Checklist

For skills that interact with tasks:

### task-start
- [ ] Parse mode from arguments (`--autonomous`, `--assisted`)
- [ ] Default to assisted if not specified
- [ ] Store mode in task file metadata
- [ ] Update task status to "In Progress"
- [ ] Load RULES.md into context

### task-complete
- [ ] Read task file to get mode
- [ ] If assisted mode: check if user invoked (via instruction context)
- [ ] If autonomous mode: verify all criteria
- [ ] Update status to "Completed"
- [ ] Move from Active to Completed in PLANNING.md

### task-list
- [ ] Load RULES.md into context
- [ ] Display task mode indicators in output
- [ ] Remind agent of workflow constraints

---

## Common Pitfalls

### ❌ Pitfall 1: Auto-completing Assisted Tasks

**Problem:** Agent completes assisted-mode tasks without user approval

**Solution:** Always read task mode before attempting completion. Check RULES.md enforcement.

### ❌ Pitfall 2: Forgetting Mode Declaration

**Problem:** Task mode not set during task-start

**Solution:** task-start MUST always set mode metadata, defaulting to "Assisted"

### ❌ Pitfall 3: Ambiguous Mode Detection

**Problem:** Unclear whether task is assisted or autonomous

**Solution:** Explicitly check task file metadata. Absence of mode = Assisted (default)

---

## Quick Reference

| Mode | AI Implements | AI Completes | User Approves |
|------|---------------|--------------|---------------|
| **Assisted** | ✅ Yes | ⛔ **NO** | ✅ Required |
| **Autonomous** | ✅ Yes | ✅ Yes | ❌ Not needed |

**Default Mode:** Assisted

**Override:** Use `task.start [id] --autonomous` explicitly
