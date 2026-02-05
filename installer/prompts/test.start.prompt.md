---
name: test.start
description: Start testing session with focused context
agent: smaqit.user-testing
---

# Test Start

Start a testing session with minimal, focused context. Loads framework understanding and specific test task only - no history, no task planning, no wiki.

## Steps

Execute these steps **IN ORDER**:

### 1. Load Framework Foundation (Parallel)

Read these framework files to understand smaqit architecture and validation rules:

- `framework/SMAQIT.md` (core principles)
- `framework/LAYERS.md` (layer definitions)
- `framework/PHASES.md` (phase workflows)
- `framework/ARTIFACTS.md` (artifact rules and validation)
- `framework/AGENTS.md` (agent behaviors)

**Critical:** Read complete files without truncation. Framework knowledge is required for test validation.

### 2. Load Specific Test Task

**User must specify:** Test task number (e.g., "059")

Read the complete test task file:
- `docs/tasks/{TASK_NUMBER}_*.md`

This file contains:
- Test objectives
- Phase-by-phase workflow
- Validation checkpoints
- Success criteria
- Issue-specific validation points

### 3. Understand Test Context

From the test task file, identify:
- **Test type** (e2e, regression, integration, unit)
- **Issues being validated** (list of specific issues with fix references)
- **Critical checkpoints** (where failures are most likely)
- **Evidence requirements** (what to collect for report)
- **Pass/fail criteria** (what determines success)

### 4. Confirm Ready State

Present a concise summary:
- Test task loaded: {TASK_NUMBER}
- Test type: {TYPE}
- Issues to validate: {COUNT} issues
- Estimated duration: {DURATION}
- Critical checkpoints: {COUNT}

Then state: **"Ready to begin test execution. Say 'start' to proceed."**

## What This Does NOT Load

**Explicitly excluded to keep context focused:**
- ❌ History files (`docs/history/*.md`) - Not needed for test execution
- ❌ Task planning (`docs/tasks/PLANNING.md`) - Not needed during test
- ❌ Other task files - Only the specific test task is loaded
- ❌ Wiki documentation - Framework files contain execution rules
- ❌ Previous test reports - Each test is independent

## What This DOES Load

**Minimal focused context:**
- ✅ Framework files (8 files) - Required for validation understanding
- ✅ Specific test task (1 file) - Complete test workflow and criteria
- ✅ Test philosophy and validation rules from framework

## Critical Requirements

**READ COMPLETE FILES:** Do NOT truncate framework files or test task file. Complete understanding is required for proper test validation.

**MODE:** You are now in test execution mode. Follow the test task workflow and your agent directives for execution philosophy, coordination patterns, and report generation.

## Success Criteria

Test start is successful when:
- [ ] All 5 framework files read completely
- [ ] Specific test task file read completely
- [ ] Test type and objectives understood
- [ ] Issue list and validation points identified
- [ ] Critical checkpoints mapped to workflow phases
- [ ] Evidence requirements clear
- [ ] Pass/fail criteria understood
- [ ] Ready state confirmed to user
