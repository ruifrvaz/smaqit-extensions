# Relax Session-Finish Push Confirmation Gate

**Status:** PR Open
**Created:** 2026-08-14
**Started:** 2026-08-14
**Mode:** Assisted
**PR:** #125

## Description

Session-finish's Step 7 currently stops for explicit confirmation in Assisted mode before every routine commit and push, even when the diff is fully known and self-authored and the push is a clean fast-forward. Fix is subtractive: delete the restrictive Assisted/Autonomous confirmation-branching sentences from Step 7's commit and push bullets rather than writing new conditional logic — the bullet's own action verb ("commit", "push") already says what to do once none of the failure-handling conditions have triggered. Every existing hard-stop condition (detached HEAD, conflicts, unexpected rejection, diverged history, auth failure, foreign changes) stays exactly as strict as today, unconditionally.

**Scope revised during implementation:** once Step 7 no longer branches on mode, Assisted vs Autonomous has zero remaining functional difference anywhere in this skill — the two flags describe identical behavior. Rather than keep `--autonomous` as a permanent documented no-op, the mode concept is dropped entirely from session-finish's interface: the `## Usage` block collapses to one invocation, and the two vestigial "in both/either mode" phrases in the failure-handling STOP bullets are removed since they no longer describe a real distinction. This is scoped to session-finish only — `task-start`/`task-complete`'s own per-task `Mode` field and workflow are a separate mechanism keyed off the task file, not this skill's invocation flag, and are completely unaffected.

## Issue Triage Context

**Mode:** Skip
**Technologies:** None
**Platforms/Environments:** None
**Features/Integrations:** session-finish main-branch finalization
**Versions/Constraints:** None

## Design Decisions

- **Subtractive fix:** remove the restrictive **Assisted:**/**Autonomous:** mode-branching confirmation sentences from Step 7's two bullets entirely. Do not replace them with new prescriptive "use best judgment" logic or any other new conditional prose — once the situation is on the already-defined "straightforward" branch (i.e., none of the failure-handling table's conditions matched), the bullet's own plain action verb (commit / push) is the complete instruction.
- **Failure-handling behavior untouched:** every hard-stop condition, and the action taken for it, remains exactly as strict and exactly as worded as today, applying unconditionally to every invocation. Only the now-meaningless mode narrative ("in both Assisted and Autonomous mode", "in either mode") is stripped from those two STOP bullets, since it no longer describes a real distinction — the underlying stop behavior itself does not change.
- **Release approvals out of scope:** release-workflow approval gates (version numbers, tags, embedded version constants) are explicitly untouched.
- **Mode dropped, not kept as a no-op:** since Step 7 no longer branches on it, Assisted vs Autonomous has zero remaining functional difference for this skill. Remove `--autonomous` and all mode language from the `## Usage` block rather than document a flag that does nothing. Scoped to session-finish only — `task-start`/`task-complete`'s own per-task `Mode` field is a separate mechanism and is unaffected.

## Implementation Steps

1. In Step 7's commit bullet, delete the sentence "**Assisted:** list the files and stop for explicit confirmation before committing. **Autonomous:** commit directly." Replace with nothing more than what's needed for the bullet to read as a single unconditional instruction to stage the known paths and commit.
2. In Step 7's push bullet, delete the sentence "**Assisted:** report the commits ready to push and stop for explicit confirmation. **Autonomous:** `git push origin main` directly." Replace with nothing more than what's needed for the bullet to read as a single unconditional instruction to push.
3. Update the `## Usage` block's Assisted-mode comment ("stops for confirmation before commit/push") so it no longer claims a routine confirmation stop that no longer exists — state plainly that it stops only on the failure-handling conditions.
4. Leave Steps 0-6 and Requirements completely untouched — verify with a diff review before finishing.
5. Collapse the `## Usage` block to a single invocation line with no `--autonomous` flag.
6. Strip "in both Assisted and Autonomous mode" / "in either mode" from the failure-handling section's two STOP bullets, leaving the stop conditions and actions themselves byte-identical otherwise.
7. Bump `smaqit.session-finish`'s SKILL.md version.
8. Run `make smoke-test`.

## Known Issues Triage

[Populated by smaqit.task-start via smaqit.utils.triage-issues. Do not edit manually.]

## Acceptance Criteria

- [x] Step 7's commit and push bullets no longer contain any Assisted/Autonomous mode-branching confirmation language; each reads as one unconditional action once the routine-case branch is reached.
- [x] No new conditional or "use best judgment"-style prose was added anywhere — every change is a deletion or a narrative-only rewording, verifiable via a diff that is majority removals.
- [x] The failure-handling section's hard-stop conditions and actions are unchanged in substance; only the vestigial "in both/either mode" phrasing is removed from its two STOP bullets.
- [x] The `## Usage` block documents a single invocation with no mode flag.
- [x] No other skill or script in the repo references `session.finish --autonomous` (verified by search) before the flag is removed.
- [x] `make smoke-test` passes.

## Findings

**Implementation approach:**
- Deleted the two Assisted/Autonomous confirmation-branching sentences from Step 7's commit and push bullets, leaving each as a single unconditional action verb.
- Widened scope at the user's explicit direction: removed the mode concept entirely from the skill rather than leave `--autonomous` as a no-op — collapsed `## Usage` to one line and stripped the vestigial "in both/either mode" phrasing from the two failure-handling STOP bullets, without changing the stop conditions or actions themselves.
- Bumped `smaqit.session-finish` SKILL.md version 0.10.0 → 0.10.1.

**Decisions made:**
- Skipped a manual `CHANGELOG.md` entry: `task-complete` Phase 1 now generates the pending-annotated entry itself (task 027's mechanism), confirmed by reading the installed `task-complete` SKILL.md directly rather than trusting the task file's original pre-027-aware instruction.
- Confirmed via repo-wide search that no other skill or script parses `session.finish --autonomous` before removing it, so dropping the flag entirely (rather than keeping it as documented no-op) is safe.
- Kept the failure-handling table's actual conditions and actions byte-identical in substance; only the mode-narrative wrapper text around them was removed.

**Blockers encountered:**
- None.

**Follow-up identified:**
- None — `task-start`/`task-complete`'s own per-task `Mode` field is a separate mechanism, unaffected and out of scope here.

## Files to Create / Modify

| File | Action |
|------|--------|
| `skills/smaqit.session-finish/SKILL.md` | Modify |

## Notes

Small, deliberately narrow hotfix — see `[[feedback_session_finish_push_autonomy]]` memory for the user's rationale.

**CHANGELOG.md dropped from Files to Create/Modify:** the original plan assumed a manually-authored entry, written pre-task-027. Under task 027's now-current mechanism, `task-complete` Phase 1 computes and pushes the release's `CHANGELOG.md` entry itself (`(pending vX.Y.Z · PR #NNN)`, via `release-analysis` + `release-prepare-files`); a hand-written entry added during implementation would sit uncommitted-then-committed as an orphaned duplicate, never annotated or promoted. Confirmed by reading the installed `task-complete` SKILL.md directly rather than assuming.

**Scope widened mid-implementation** (user request, same review round as the original fix): removing the mode branch from Step 7 left `--autonomous` fully inert for this skill — no behavioral difference remained anywhere in it. Rather than leave a no-op flag documented, the mode concept is removed from session-finish's interface entirely. Confirmed no other skill or script depends on the flag before removing it.
