---
status: Completed
created: "2026-05-09"
completed: "2026-05-09"
---

# Add Findings Section to Task Workflow

## Description

Extend the smaqit task workflow to include a mandatory `## Findings` section in every task file. The Findings section captures what was actually built, what decisions were made, what blockers were encountered, and what follow-up work was identified — in brief, structured bullets. This decouples "did we meet the criteria?" (Acceptance Criteria) from "what did we actually learn and build?" (Findings).

This task touches three skills and the task template:

1. **`smaqit.task-create`** — updated to include a `## Findings` placeholder in every newly created task file
2. **`smaqit.task-complete`** — updated to prompt the agent to write the Findings section before marking a task complete; Findings are mandatory
3. **`smaqit.task-start`** — extended to: (a) surface existing Findings if re-starting a task, AND (b) call `smaqit.utils.triage-issues` as a built-in step so that triage results are recorded in the task file as a `## Known Issues Triage` block (this extends task-start's existing triage integration and adds triage findings to the task file explicitly)

Additionally, a canonical **task template** is added to `skills/smaqit.task-create/assets/TASK_TEMPLATE.md` that defines the complete, authoritative structure of a task file. All future task creation must follow this template.

**Spec note:** Per the agentskills.io specification, static resource templates belong in `assets/`, not `references/`. `references/` is for additional documentation the agent reads on demand; `assets/` is for templates and static resources. `TASK_TEMPLATE.md` is a resource the agent uses as a pattern, not a reference document — it goes in `assets/`.

## Design Decisions (confirmed)

- **Mandatory:** Findings section is mandatory for task completion. `smaqit.task-complete` must not allow completion without Findings being written.
- **Detail level:** Brief, structured bullets. No verbosity, no URLs. Can be as long as needed to capture all decisions and outcomes — just no filler text.
- **Format:** Structured (consistent bullet categories), not freeform prose.
- **`task-start` triage extension:** `smaqit.task-start` MUST call `smaqit.utils.triage-issues` (it already does via Step 2a). This task extends that integration so triage results are also written as a `## Known Issues Triage` block into the task file — not just surfaced in chat. The existing triage block format from `skills/smaqit.utils.triage-issues/references/TRIAGE_BLOCK.md` is used.
- **Findings on task-start (resume):** If a task already has a Findings section when re-started (e.g., a task was completed then reopened, or partially completed), `task-start` must surface those findings in context for continuity.

## Findings Section Format

```markdown
## Findings

**Implementation approach:**
- [What was actually built, key implementation decisions]

**Decisions made:**
- [Each significant decision with brief rationale]

**Blockers encountered:**
- [Any blockers hit during implementation and how they were resolved, or None]

**Follow-up identified:**
- [New tasks, improvements, or risks surfaced during implementation, or None]
```

Rules:
- Each category always present (do not omit a category; write "None" if nothing to report)
- Bullets only — no paragraph prose
- No URLs — reference file paths, skill names, command names instead
- No verbosity — every bullet should be a complete, useful statement in one line or two maximum
- Length: as many bullets as needed to capture all meaningful information; do not truncate

## Canonical Task Template

Create `skills/smaqit.task-create/assets/TASK_TEMPLATE.md` with the full authoritative task structure:

```markdown
# [Task Title]

**Status:** Not Started
**Created:** YYYY-MM-DD

## Description

[1-3 paragraphs describing what the task is and why it exists. Be specific enough that the task can be executed in a standalone session with no prior context.]

## Design Decisions

[Confirmed design decisions. Use bullet format: **Decision name:** rationale. Add as needed during refinement. If no decisions yet, write "TBD — to be confirmed during assessment."]

## Implementation Steps

[Numbered list of concrete steps to implement the task. Be specific enough that a fresh agent session can follow them without additional context.]

## Known Issues Triage

[Populated by smaqit.task-start via smaqit.utils.triage-issues. Do not edit manually.]

## Acceptance Criteria

- [ ] [Each criterion is a specific, verifiable statement]
- [ ] [Use checkboxes; checked off by smaqit.task-complete]

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
| [path] | [Create / Modify / Delete] |

## Notes

[Optional. Free-form context, constraints, open questions, or references that don't fit the above sections. May be left empty.]
```

## Changes to smaqit.task-create SKILL.md

- Add a step: after writing all standard sections, append the `## Findings` placeholder (with TBD bullets) and `## Known Issues Triage` placeholder (with "Populated by smaqit.task-start" note) to every new task file
- Reference the canonical `TASK_TEMPLATE.md` as the authoritative structure to follow
- Bump version

## Changes to smaqit.task-complete SKILL.md

Add a mandatory step before accepting completion:

**Step: Write Findings**
1. Confirm the task's `## Findings` section exists in the task file
2. Prompt the agent (or fill automatically based on implementation knowledge): populate each Findings category with brief structured bullets
3. Write the Findings section to the task file (overwrite the TBD placeholders)
4. Confirm each Acceptance Criteria checkbox is checked
5. Only then: update Status to Completed and set Completed date

The Findings write step must occur BEFORE status update. If Findings are not populated, task-complete must block completion and prompt for them.

- Bump version

## Changes to smaqit.task-start SKILL.md

Two extensions:

**Extension A — Surface existing Findings on resume:**
- When starting a task that already has a non-placeholder `## Findings` section (i.e., it was previously completed or partially executed), surface those findings in context
- Print: "Existing findings loaded from previous execution: [summary]"
- This helps the agent understand what was already tried/decided before re-implementing

**Extension B — Write triage results to task file:**
- `task-start` already calls `smaqit.utils.triage-issues` in Step 2a
- Extend Step 2a: after triage completes, write the triage block (using the format from `skills/smaqit.utils.triage-issues/references/TRIAGE_BLOCK.md`) to the task file under `## Known Issues Triage`
- If the section already exists (from a previous start), overwrite it with fresh triage results
- Blocking issues still halt task-start per existing behavior

- Bump version

## Acceptance Criteria

- [x] `skills/smaqit.task-create/assets/TASK_TEMPLATE.md` created with the full canonical task structure (all sections including Findings and Known Issues Triage placeholders)
- [x] `skills/smaqit.task-create/SKILL.md` updated to include `## Findings` placeholder and `## Known Issues Triage` placeholder in all newly created task files; references TASK_TEMPLATE.md; version bumped
- [x] `skills/smaqit.task-complete/SKILL.md` updated with mandatory Findings write step before status update; task-complete blocks if Findings are empty/TBD; version bumped
- [x] Findings format enforced: four categories (Implementation approach, Decisions made, Blockers encountered, Follow-up identified) always present; bullets only; no URLs; no verbosity
- [x] `skills/smaqit.task-start/SKILL.md` updated to surface existing Findings on task resume; version bumped
- [x] `skills/smaqit.task-start/SKILL.md` Step 2a extended to write triage results to task file under `## Known Issues Triage` after triage completes
- [x] Triage block written to task file follows the format defined in `skills/smaqit.utils.triage-issues/references/TRIAGE_BLOCK.md`
- [x] All modified skill files synced to `.github/` via `make sync`
- [x] Existing task files (001-004) are NOT retroactively modified — new format is forward-only
- [x] PLANNING.md updated to mark this task Completed

## Files to Create / Modify

| File | Action |
|------|--------|
| `skills/smaqit.task-create/assets/TASK_TEMPLATE.md` | Create — canonical task template |
| `skills/smaqit.task-create/SKILL.md` | Modify — add Findings + Triage placeholders; reference template; bump version |
| `skills/smaqit.task-complete/SKILL.md` | Modify — add mandatory Findings write step; bump version |
| `skills/smaqit.task-start/SKILL.md` | Modify — surface existing Findings on resume; write triage to task file; bump version |
| `.github/skills/smaqit.task-create/SKILL.md` | Synced via `make sync` |
| `.github/skills/smaqit.task-complete/SKILL.md` | Synced via `make sync` |
| `.github/skills/smaqit.task-start/SKILL.md` | Synced via `make sync` |
| `.smaqit/tasks/PLANNING.md` | Modify — mark completed |

## Notes

- The canonical `TASK_TEMPLATE.md` is the source of truth for task structure. If `smaqit.task-create` diverges from it, the template wins.
- **assets/ vs references/:** `TASK_TEMPLATE.md` lives in `assets/` (static resource pattern) not `references/` (reference documentation). The `smaqit.task-create` SKILL.md should reference it as `assets/TASK_TEMPLATE.md` and instruct the agent to load it when creating a new task.
- The Findings section is forward-only. Do not retrofit existing tasks (001-004, 005-011). The new structure applies only to tasks created after this change.
- The `## Known Issues Triage` section is written by `smaqit.task-start` — not by `smaqit.task-create`. `task-create` adds the placeholder header with the "Populated by smaqit.task-start" annotation. `task-start` overwrites it with actual triage content.
- The Findings section is written by `smaqit.task-complete` — not by `smaqit.task-create`. `task-create` adds the placeholder. `task-complete` fills it.
- Mandatory means mandatory: `task-complete` must check that Findings are non-empty and non-placeholder before proceeding. An acceptable minimum is at least one non-TBD bullet per category.
- The task-start triage write is a non-blocking extension of Step 2a. If the write fails (e.g., file not found), task-start reports a warning but does not halt.
