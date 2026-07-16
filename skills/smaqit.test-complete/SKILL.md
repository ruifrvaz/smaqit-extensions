---
name: smaqit.test-complete
description: Use this skill when finalizing a testing session — verify the playbook's pass/fail criteria against collected execution evidence, generate a standardized test report at `.smaqit/user-testing/YYYY-MM-DD_test-report.md`, and present the result. Use when the user invokes `test.complete`, asks to finalize or wrap up a testing session, or requests a test report. Mirrors `smaqit.task-complete`: the agent executes tests, the user invokes this skill to produce the report.
metadata:
  version: "1.0.0"
---

# Test Complete

Finalize a testing session and produce a standardized test report.

## Steps

### 1. Gather execution evidence

Collect from the testing session context (provided by the testing agent or user):

- Test playbook file path (e.g., `.smaqit/user-testing/tests/NNN_*.md`)
- Which playbook steps were executed and their pass/fail results
- Command outputs captured during execution
- Any failures or unexpected behavior observed

If any of the above is missing, ask the user before proceeding.

### 2. Verify playbook criteria

Read the playbook file. For each checkbox step (`- [ ]`):

- Executed and passed → mark as `- [x]`
- Skipped (e.g., live-service E2E not applicable) → leave as `- [ ]` and append a `<!-- skipped: <reason> -->` comment
- Executed and failed → mark as `- [x]` and record the failure detail

Determine the overall verdict:

- **PASS** — all required checkboxes passed, all commands exited 0, live-service responses matched expected behavior
- **FAIL** — any required checkbox failed or any unexpected failure occurred

### 3. Load report template

Read `references/report-template.md` from this skill's directory. Use it as the skeleton — fill its `{placeholders}` with the evidence from Steps 1–2. Never inline the template in the skill body.

### 4. Write report

Write the completed report to `.smaqit/user-testing/YYYY-MM-DD_test-report.md` using today's date.

Required sections (populated from the template):

- **Date, Repository, Branch, Commit, OS/Arch, Duration** — from session context
- **Scope** — playbook file reference and commands executed
- **Checklist** — verified pass/fail per playbook step
- **Execution Log** — timestamped steps from execution evidence
- **Results** — overall PASS/FAIL with summary
- **Pain Points** — blockers, issues, UX friction, performance observations
- **Recommendations** — concrete improvements based on findings

If a report already exists for today's date, append a `_N` suffix (e.g., `2026-06-09_test-report_2.md`). Inform the user of the disambiguation.

### 5. Present results

Display to the user:

- Report file path
- Overall verdict (PASS / FAIL)
- Summary: number of steps passed vs. failed
- Critical pain points (if any)
- Suggested next actions

## Output

- `.smaqit/user-testing/YYYY-MM-DD_test-report.md` — completed test report

## Scope

**In scope:**

- Verifying playbook pass/fail criteria against collected execution evidence
- Generating standardized test reports from `references/report-template.md`
- Presenting results to the user

**Out of scope:**

- Executing tests — handled by `smaqit.user-testing`
- Creating playbooks — handled by `smaqit.test-create`
- Starting test sessions — handled by `smaqit.test-start`
- Modifying product code

## Examples

**Trigger:** `test.complete` after a testing session for playbook 066.

**Agent actions:**
1. Gathers evidence: playbook 066 executed, Steps 1–10 all passed, full `dotnet test` output captured
2. Reads playbook; verifies all 10 step checkboxes
3. Determines verdict: PASS
4. Loads `references/report-template.md`
5. Writes `.smaqit/user-testing/2026-06-09_test-report.md`
6. Presents: "Report saved. Verdict: PASS. 10/10 steps passing."

**Output:** Report at `.smaqit/user-testing/2026-06-09_test-report.md`. Verdict: PASS.

## Gotchas

- **Report date uses the current date, not the playbook creation date.** The playbook may have been authored on a different day.
- **Evidence must come from the execution session, not inferred.** If a command output was not captured, mark that step as "unverified" — do not guess.
- **Pain points are observations, not root cause analysis.** Report what happened: "`dotnet test` exited with code 1" not "The test failed because the service wasn't running."
- **Report filename uniqueness:** if today's report already exists, disambiguate with `_2`, `_3`, etc.
- **The report template lives in `references/report-template.md`** — read it before writing; never inline it.

## Completion

- [ ] Execution evidence gathered (playbook path, step results, command outputs, failures)
- [ ] Playbook criteria verified — all checkboxes assessed
- [ ] Report template loaded from `references/report-template.md`
- [ ] Complete report written to `.smaqit/user-testing/YYYY-MM-DD_test-report.md`
- [ ] All required report sections present
- [ ] Overall verdict determined (PASS or FAIL)
- [ ] Results presented to user

## Failure Handling

| Situation | Action |
|-----------|--------|
| Required input not provided | Request the missing information before proceeding |
| Gathered input is ambiguous | Flag the ambiguity and ask for clarification |
| Execution evidence missing or incomplete | Ask user to provide the missing details; do not proceed without them |
| Playbook file not found at the provided path | Ask user to confirm the playbook path; if genuinely missing, generate a minimal report from available evidence |
| Report template (`references/report-template.md`) not found | Use the hardcoded minimal structure from Step 4; report the missing template to the user |
| Report already exists for today | Append `_N` suffix; inform user of the disambiguation |
| Evidence contradicts playbook — step claimed passed but evidence shows failure | Flag the discrepancy; mark overall verdict as FAIL; record in pain points |
| Report write fails (disk full, permissions) | Log the error, attempt a simplified report at an alternate path, notify user |
| Output artifact already exists | Confirm with user before overwriting (only applies to non-date-disambiguated paths) |
