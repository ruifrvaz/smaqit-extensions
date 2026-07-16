# Report Template

> Canonical Markdown structure for all test reports. Load this when completing a testing session via `smaqit.test-complete`. Fill `{placeholders}` with execution evidence.

---

```markdown
# User Testing Report

**Date:** YYYY-MM-DD
**Repository:** <owner/repo or folder>
**Branch:** <branch>
**Commit:** <sha>
**OS/Arch:** <os>/<arch>
**Duration:** <start-end or minutes>

## Scope
- Test file: <TEST_NUMBER or none>
- Commands executed:
   - <command 1>
   - <command 2>

## Checklist
- [ ] Test command discovered and confirmed
- [ ] Dependencies installed (if required)
- [ ] Test suite executed
- [ ] Results captured (pass/fail + key errors)
- [ ] Evidence collected (per test file, if provided)

## Execution Log (Timestamped)
- HH:MM - <step description>
- HH:MM - <step description>

## Results
- Overall: PASS/FAIL
- Summary:
   - <high-level outcome, pass/fail counts, key metrics>

## Pain Points
- Blockers:
   - <blocker — critical issue preventing progress>
- Issues:
   - <issue — problem that affects user experience>
- UX Friction:
   - <friction — workflow awkwardness or confusion>
- Performance:
   - <performance concern — timing or resource issue>

## Recommendations
- <concrete, actionable improvement suggestion>
- <another suggestion>
```
