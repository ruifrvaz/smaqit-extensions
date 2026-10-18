---
status: In Progress
mode: Assisted
created: "2026-10-19"
started: "2026-10-19"
---

# smaqit.project-init: Description Overlaps With smaqit.project-new

## Description

smaqit v3.18.0 (smaqit task 141) renamed its full-pipeline orchestrator skill from
`smaqit.new-greenfield-project` to `smaqit.project-new`. It now sits in the same `smaqit.project-*`
namespace as this repository's `smaqit.project-init`, and both are installed into the same global
skill directories (`~/.claude/skills/`, `~/.agents/skills/`).

Claude Code, Copilot and Codex pick a skill partly by its description. `smaqit.project-init`'s
description says "Use when the user asks to **start**, initialize, reinitialize, or refresh a smaqit
project". A request such as "start a new smaqit project" or "set up this new project" therefore
matches both skills. Claude could pick `project-init`, which only syncs instruction files and creates
directories, when the user wanted the full pipeline, or the reverse.

smaqit already made its side unambiguous: `smaqit.project-new`'s description ends "Not for
scaffolding instruction files alone (smaqit.project-init)." This task makes the matching change here,
so each description says what the other skill is for.

Current description (325 characters):

> Bootstrap or refresh a smaqit project by inferentially synchronizing Codex, Claude Code, and GitHub
> Copilot project instructions around a canonical root AGENTS.md, then creating the base project
> directories (docs/, assets/, assets/raw/). Use when the user asks to start, initialize,
> reinitialize, or refresh a smaqit project.

## Issue Triage Context

**Mode:** Skip
**Technologies:** None
**Platforms/Environments:** None
**Features/Integrations:** skill description routing, smaqit.project-init, smaqit.project-new
**Versions/Constraints:** description at most 400 characters, no behavior change to the skill

## Design Decisions

- **Change the trigger wording, not the behavior.** Replace "start" in the trigger list with
  instruction-file wording, and add a closing "Not for …" clause naming `smaqit.project-new`. The
  closing clause mirrors the one in `smaqit.project-new`'s description.
- **Proposed description** (starting point, 376 characters):

  > Bootstrap or refresh a smaqit project's instruction files: synchronize Codex, Claude Code, and
  > GitHub Copilot instructions around a canonical root AGENTS.md, then create the base directories
  > (docs/, assets/, assets/raw/). Use when the user asks to initialize, reinitialize, or refresh a
  > project's instructions. Not for building and shipping a new project (smaqit.project-new).

- **Check the body as well as the description.** Any "start a project" style wording in
  `SKILL.md`, or in a `when_to_use` field if one exists, gets the same treatment.

## Implementation Steps

1. `skills/smaqit.project-init/SKILL.md`: rewrite the `description` as above and bump
   `metadata.version` (0.7.0 → 0.7.1).
2. Check the skill body and any `when_to_use` trigger phrases for "start"/"new project" wording that
   overlaps with `smaqit.project-new`; reword it the same way.
3. Run this repository's build so the installed copies regenerate, and confirm the description stays
   within 400 characters (the limit Claude Code's skill listing applies).
4. CHANGELOG entry and release.

## Known Issues Triage

[Populated by smaqit.task-start via smaqit.utils.triage-issues. Do not edit manually.]

## Acceptance Criteria

- [ ] `smaqit.project-init`'s description no longer lists "start" as a trigger. It names instruction
      files as its scope and points to `smaqit.project-new` for the full pipeline.
- [ ] The description is at most 400 characters; the skill's behavior is unchanged
- [ ] No other trigger wording in the skill overlaps with `smaqit.project-new`
- [ ] CHANGELOG updated; released

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
| skills/smaqit.project-init/SKILL.md | Modify |
| CHANGELOG.md | Modify |

## Notes

- Raised during smaqit task 141's planning (2026-10-18). smaqit's side shipped in v3.18.0.
- Triage is `Skip`: this is a wording change with no third-party dependency to search.
