---
status: In Progress
mode: Assisted
created: "2026-10-11"
started: "2026-10-11"
---

# Release PR #140 and Fix Stale README Session Docs

## Description

PR #140 (`fix/fold-session-title-into-session-finish`) folded `smaqit.session-title` into `smaqit.session-finish`, added a title-only mode, and made the installer delete the retired skill on upgrade. It merged to `main` outside the task lifecycle under a non-release PR title, so `post-merge-release.yml` never tagged it: its changes sit under `CHANGELOG.md`'s `[Unreleased]` section and are invisible to `smaqit-extensions update`, which only fetches tagged releases.

Two stale README statements remain after that change. The install section still says "29 workflow skills" for both `~/.agents/skills/` and `~/.claude/skills/`, although retiring `smaqit.session-title` left 28 (`ls skills | wc -l` and the Makefile `SKILLS` list both give 28). The `smaqit.session-finish` catalog line still advertises "Assisted by default, or `session.finish --autonomous`", a mode that was removed in v1.17.2 and does not exist in the skill.

This task fixes both README statements, and its PR is the release that ships PR #140's already-merged changes together with the fix.

## Issue Triage Context

**Mode:** Skip
**Technologies:** None
**Platforms/Environments:** None
**Features/Integrations:** None
**Versions/Constraints:** None

## Design Decisions

- **Ship PR #140 through this task's release, not a separate one:** `task-complete` Phase 1 folds every bullet already under `[Unreleased]`, including PR #140's, into this task's `## [X.Y.Z]` section, so one PR releases both.
- **Leave historical references untouched:** `CHANGELOG.md` history, `.smaqit/history/`, and older task files are records of past state. `installer/main.go`'s `retiredSkills` list is deliberate: it deletes the retired skill on install.

## Implementation Steps

1. In the task worktree's `README.md`, change "29 workflow skills" to "28 workflow skills" on both install-path lines (`~/.agents/skills/`, `~/.claude/skills/`).
2. In the same file, remove " — Assisted by default, or `session.finish --autonomous`" from the `smaqit.session-finish` catalog line.
3. Confirm `grep -n "autonomous" README.md` only matches task-start's own `--autonomous` example, and that the skill count matches `ls skills | wc -l`.
4. Run `make test`.

## Known Issues Triage

[Populated by smaqit.task-start via smaqit.utils.triage-issues. Do not edit manually.]

## Acceptance Criteria

- [ ] README install section states 28 workflow skills for both `~/.agents/skills/` and `~/.claude/skills/`, matching `ls skills | wc -l`.
- [ ] README's `smaqit.session-finish` line no longer mentions Assisted/Autonomous modes or `--autonomous`.
- [ ] `make test` passes.
- [ ] The task's release PR carries PR #140's `[Unreleased]` changelog bullets into its `## [X.Y.Z]` section, so the next tag ships them.

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
| `README.md` | Modify — skill counts and session-finish mode wording |

## Notes

Task 010's own file still lists `skills/smaqit.session-title/` in its plan. Leave it until that task is re-planned or abandoned.
