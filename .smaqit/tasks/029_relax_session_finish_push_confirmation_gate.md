# Relax Session-Finish Push Confirmation Gate

**Status:** In Progress
**Created:** 2026-08-14
**Started:** 2026-08-14
**Mode:** Assisted

## Description

Session-finish's Step 7 currently stops for explicit confirmation in Assisted mode before every routine commit and push, even when the diff is fully known and self-authored and the push is a clean fast-forward. Fix is subtractive: delete the restrictive Assisted/Autonomous confirmation-branching sentences from Step 7's commit and push bullets rather than writing new conditional logic — the bullet's own action verb ("commit", "push") already says what to do once none of the failure-handling conditions have triggered. Every existing hard-stop condition (detached HEAD, conflicts, unexpected rejection, diverged history, auth failure, foreign changes) stays exactly as strict as today, in both modes, completely unchanged.

## Issue Triage Context

**Mode:** Skip
**Technologies:** None
**Platforms/Environments:** None
**Features/Integrations:** session-finish main-branch finalization
**Versions/Constraints:** None

## Design Decisions

- **Subtractive fix:** remove the restrictive **Assisted:**/**Autonomous:** mode-branching confirmation sentences from Step 7's two bullets entirely. Do not replace them with new prescriptive "use best judgment" logic or any other new conditional prose — once the situation is on the already-defined "straightforward" branch (i.e., none of the failure-handling table's conditions matched), the bullet's own plain action verb (commit / push) is the complete instruction, for both modes.
- **Failure-handling table untouched:** all existing hard-stop conditions remain unchanged in wording and behavior, in both modes — this task touches only the two confirmation sentences on the routine-case branch, nothing else in Step 7 or elsewhere in the skill.
- **Release approvals out of scope:** release-workflow approval gates (version numbers, tags, embedded version constants) are explicitly untouched.
- **Accepted consequence:** Mode (Assisted/Autonomous) is referenced only in Step 7 today, so after this fix session-finish behaves identically in both modes for every case except the shared hard-stops. The `--autonomous` flag becomes a documented no-op for this specific skill; it still matters for `task-start`/`task-complete`.

## Implementation Steps

1. In Step 7's commit bullet, delete the sentence "**Assisted:** list the files and stop for explicit confirmation before committing. **Autonomous:** commit directly." Replace with nothing more than what's needed for the bullet to read as a single unconditional instruction to stage the known paths and commit.
2. In Step 7's push bullet, delete the sentence "**Assisted:** report the commits ready to push and stop for explicit confirmation. **Autonomous:** `git push origin main` directly." Replace with nothing more than what's needed for the bullet to read as a single unconditional instruction to push.
3. Update the `## Usage` block's Assisted-mode comment ("stops for confirmation before commit/push") so it no longer claims a routine confirmation stop that no longer exists — state plainly that it stops only on the failure-handling conditions.
4. Leave the failure-handling table, Steps 0-6, and Requirements completely untouched — verify with a diff review before finishing.
5. Bump `smaqit.session-finish`'s SKILL.md version and add a concise `CHANGELOG.md` entry describing the subtractive fix.
6. Run `make smoke-test`.

## Known Issues Triage

[Populated by smaqit.task-start via smaqit.utils.triage-issues. Do not edit manually.]

## Acceptance Criteria

- [ ] Step 7's commit and push bullets no longer contain any Assisted/Autonomous mode-branching confirmation language; each reads as one unconditional action once the routine-case branch is reached, in both modes.
- [ ] No new conditional or "use best judgment"-style prose was added — the fix is a deletion, verifiable via a smaller line count in Step 7 and a diff that is majority removals.
- [ ] Every failure-handling table row is byte-identical to before this change.
- [ ] The `## Usage` block accurately describes the new behavior.
- [ ] `make smoke-test` passes.

## Findings

[Populated by smaqit.task-complete. Do not fill in manually before task is complete.]

**Implementation approach:**
- TBD

**Decisions made:**
- TBD

**Blockers encountered:**
- TBD

**Follow-up identified:**
- TBD

## Files to Create / Modify

| File | Action |
|------|--------|
| `skills/smaqit.session-finish/SKILL.md` | Modify |
| `CHANGELOG.md` | Modify |

## Notes

Small, deliberately narrow hotfix — see `[[feedback_session_finish_push_autonomy]]` memory for the user's rationale.
