# Add In-Progress Task Gate to Session Finish

**Status:** Completed
**Created:** 2026-07-23
**Completed:** 2026-07-23

## Description

Insert a pre-flight check in `smaqit.session-finish` that scans PLANNING.md for tasks still marked "In Progress" and blocks session completion until they're resolved or explicitly skipped.

## Acceptance Criteria

- [x] Session-finish stops and lists in-progress tasks when any exist
- [x] Session-finish proceeds normally when no tasks are in progress
- [x] Session-finish skips silently when PLANNING.md doesn't exist

## Implementation Steps

1. Add a new step in `skills/smaqit.session-finish/SKILL.md` before Step 1 (Create history file)
2. Renumber existing steps 1–4 to 2–5
3. Bump version 0.8.1 → 0.9.0

## Design Decisions

- Flag all "In Progress" tasks regardless of session (catches stale tasks too)
- Hard stop with skip escape ("say 'skip' to proceed anyway")

## Findings

**Implementation approach:** Added new Step 1 in session-finish SKILL.md before history creation; reads PLANNING.md, lists in-progress tasks, stops with skip escape; renumbered steps 1-4 to 2-6.
**Decisions made:** Flag all "In Progress" regardless of session; hard stop with user-controlled skip.
**Blockers encountered:** None.
**Follow-up identified:** None.
