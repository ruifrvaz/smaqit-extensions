---
name: test-start
description: Start testing session with focused context. Use when beginning test workflows with the user-testing agent.
metadata:
  version: "0.1.0"
agent: smaqit.user-testing
---

# Test Start

Start a testing session with minimal, focused context. Loads project test entrypoints and (optionally) a specific test task only.

## Steps

Execute these steps **IN ORDER**:

### 1. Load Test Entry Points (Parallel)

Read the project files that define how tests are run (whichever exist):

- `README.md`
- `CONTRIBUTING.md` and/or `TESTING.md`
- `Makefile`
- `package.json` (scripts)
- `pyproject.toml` / `tox.ini` / `pytest.ini`
- `go.mod` (then infer `go test ./...`)

**Critical:** Read complete files without truncation.

### 2. Load Specific Test Task

**User must specify:** Test task number (e.g., "059")

Read the complete test task file:
- `.smaqit/tasks/{TASK_NUMBER}_*.md`

If the task file does not exist, instruct the user to create it using `/task.create` (or create it yourself) before proceeding.

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
- ❌ History files (`.smaqit/history/*.md`) - Not needed for test execution
- ❌ Task planning (`.smaqit/tasks/PLANNING.md`) - Not needed during test
- ❌ Other task files - Only the specific test task is loaded
- ❌ Previous test reports - Each test is independent

## What This DOES Load

**Minimal focused context:**
- ✅ Test entrypoints (project-specific) - How to run the test suite
- ✅ Specific test task (optional) - If provided, follow its workflow and criteria

## Critical Requirements

**READ COMPLETE FILES:** Do NOT truncate test entrypoint files or the test task file.

**MODE:** You are now in test execution mode. Follow the test task workflow and your agent directives for execution philosophy, coordination patterns, and report generation.

## Success Criteria

Test start is successful when:
- [ ] Test entrypoint files read completely
- [ ] Specific test task file read completely (if provided)
- [ ] Test type and objectives understood
- [ ] Issue list and validation points identified
- [ ] Critical checkpoints mapped to workflow phases
- [ ] Evidence requirements clear
- [ ] Pass/fail criteria understood
- [ ] Ready state confirmed to user
