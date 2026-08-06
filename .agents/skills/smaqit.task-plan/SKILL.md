---
name: smaqit.task-plan
description: Plans work before implementation or task creation. Given a task ID or a free-form idea, assesses complexity, resolves design gaps via discovery and Q&A, and produces an approved execution plan. Offers context-appropriate next steps: create a new task, start an existing one, or update the task file with resolved decisions.
metadata:
  version: "1.2.0"
---

# Task Plan

## Modes

The skill infers the operating mode from the user's input:

- **Mode A — Pre-create**: No task ID provided. User has an idea, feature, or problem to plan. Produces an execution plan with the exact task fields it will create, and asks for a single approval covering both before invoking `task.create`.
- **Mode B — Pre-start / Update**: A task ID is provided and the task file exists. Reads the task, fills design gaps, produces a plan, then offers three next steps: start the task, update the task file in place, or keep the plan for a future session.

## Steps

### Phase 0 — Mode Detection (always runs)

1. Determine the operating mode:
   - **Mode A**: No task ID in the user's input. If a description was not provided, elicit one before proceeding. Set the working context to the user-provided description.
   - **Mode B**: A task ID is present. Proceed to Phase 1.

### Phase 1 — Task Assessment (Mode B only)

2. Read `.smaqit/tasks/NNN_*.md` for the given task ID. Extract: Description, Acceptance Criteria, Implementation Steps, Design Decisions, Notes, dependencies, and any existing Findings. If the task file is not found, report the error and ask the user to verify the task ID. Do not proceed.

3. Score complexity:

   **Trivial** — ALL of the following must be true:
   - ≤3 Acceptance Criteria
   - All Implementation Steps populated (no empty list, no placeholder text)
   - No `TBD` in Design Decisions section
   - All stated dependencies resolved (Completed status in PLANNING.md)

   **Complex** — ANY of the following is true:
   - Design Decisions contain `TBD` or are absent
   - Implementation Steps are empty, stale, or contain placeholder text
   - Task is a spike or research task
   - Task touches >2 independent source areas
   - Unresolved or unclear dependencies
   - >7 Acceptance Criteria
   - ACs contain unconstrained language ("appropriate", "works", "reasonable") with no measurable threshold

4. Build a gap list: label each identified gap and classify as **Blocking** (must resolve before plan) or **Advisory** (can proceed with assumption).

5. Present the complexity verdict and gap list to the user.
   - **Trivial verdict:** Offer to produce a full plan if needed; otherwise recommend proceeding to `task.start [id]` directly. Stop here unless the user requests a full plan.
   - **Complex verdict:** Present the gap list and continue to Phase 2.

### Phase 2 — Discovery

6. Identify 1–3 concern areas. For Mode A, derive from the user description. For Mode B, derive from the gap list. Typical concern areas: existing module implementations the task must follow, external service or API behaviour the task depends on, or test infrastructure patterns the task must replicate.

7. Launch one Explore subagent per concern area (in parallel when independent). Each subagent prompt must specify:
   - The exact concern area to investigate
   - Thoroughness level: `quick`, `medium`, or `thorough`
   - What to return: specific files, types, function names, patterns, or API endpoints — not general summaries

8. Update the in-memory plan draft with findings from each subagent. Note any concerns that returned no useful context.

### Phase 3 — Alignment (if blocking gaps remain after Discovery)

9. Ask the user clarifying questions iteratively to resolve blocking gaps. Present one logical cluster per interaction, each question paired with a recommended option and rationale. If user answers reveal scope changes, loop back to Phase 2 with updated subagent queries.

10. For advisory gaps the user declines to clarify, document an explicit assumption in the plan draft.

### Phase 4 — Design

11. Draft the execution plan using the following structure:

    ```
    ## Plan: {Title — 2–10 words}

    {TL;DR — what, why, and recommended approach. 2–4 sentences.}

    **Steps**
    1. {Step — note "depends on N" or "parallel with step N" when applicable}
    2. {For 5+ steps, group into named phases, each independently verifiable}

    **Relevant files**
    - `{full/path/to/file}` — {what to modify or reuse; name specific functions, types, or patterns}

    **Verification**
    1. {Specific test commands or checks — not generic statements}

    **Decisions**
    - {Design decisions, assumptions, explicit scope inclusions and exclusions}

    **Further Considerations** (optional, 1–3 items)
    1. {Clarifying point with trade-off or recommendation}
    ```

    Rules for the plan body: no code blocks — describe changes using symbol names and file links; every file in Relevant Files must be verified to exist via Discovery or prior codebase knowledge; Decisions must capture all choices made in Phase 3 Q&A.

12. If a session-scoped memory/scratch-storage capability is available in this environment, save the plan to `/memories/session/plan.md` there (create or overwrite) as a durability backup. This step is optional — skip it silently if no such capability exists.

13. **Show the full plan to the user.** This is the authoritative record regardless of whether Step 12 was available or succeeded — do not substitute the memory file for presenting the plan in chat.
    - **Mode A:** append the pre-populated task fields directly beneath the plan, in the same message:
      ```
      Title: {derived from plan title}
      Description: {1–3 sentence summary from TL;DR}
      Acceptance Criteria:
        - {AC derived from plan}
      Implementation Steps:
        - {Step derived from plan}
      Design Decisions:
        - {resolved decision from Phase 3}
      ```
      These are exactly what Step 15 passes to `task.create` on approval. Showing them here means the single approval in Step 14 covers both the plan and the fields, instead of asking twice over nearly the same content.

### Phase 5 — Refinement and Next Steps

14. Await user feedback and iterate:
    - **Changes requested** → revise plan (and Mode A's fields, if they changed), re-save to `/memories/session/plan.md` if that capability is available, re-show updated plan
    - **Questions asked** → clarify inline; ask the user follow-up questions if needed
    - **Alternatives wanted** → loop back to Phase 2 with a new Explore subagent targeting the alternative
    - **Explicit approval given** → act on context-appropriate next steps (step 15)

15. On approval, act on next steps based on mode:

    **Mode A:** invoke `task.create` immediately with the fields already shown and approved in Step 13. Do not re-present them or ask for a second confirmation — that would just repeat the approval the user already gave.

    **Mode B:**
    Offer three options:
    1. **Start now** — run `task.start [id]` to begin implementation
    2. **Update task file** — apply resolved Implementation Steps, Design Decisions, and any corrected ACs back to the task file (step 16)
    3. **Keep for later** — plan remains shown in this session's chat, and in `/memories/session/plan.md` if that capability was available; nothing else to do

16. **Task file update (Mode B, option 2):**
    - Present a field-by-field summary of proposed changes: current value → new value for each field being updated
    - Require explicit user confirmation before writing
    - Write only the fields that have changed: Implementation Steps, Design Decisions, and ACs if the plan reveals they are incorrect or incomplete
    - Never touch PLANNING.md or any other file

## Output

- `/memories/session/plan.md` — approved execution plan, if a session-scoped memory capability is available; session-scoped, never committed to git. The plan shown in chat (always produced) is authoritative regardless.
- Complexity verdict and gap list (Mode B) — surfaced in chat, not persisted
- Mode A: pre-populated task fields shown alongside the plan and approved together, before `task.create` is invoked
- Mode B option 2: task file updated with confirmed field changes

## Scope

**In scope:**
- Reading and assessing any task file by ID (Mode B)
- Accepting a free-form description to plan a potential new task (Mode A)
- Launching Explore subagents to gather codebase context
- Iterative Q&A to resolve design decisions and gaps
- Writing and refining an execution plan
- Updating Implementation Steps, Design Decisions, and ACs in the task file after explicit user confirmation (Mode B option 2)

**Out of scope:**
- Does not implement code or modify source files
- Does not modify PLANNING.md or any project file other than the specific task file (Mode B option 2 only)
- Does not run tests, builds, or services
- Precedes `task.start` — does not replace it
- Does not validate acceptance criteria — that is `task.complete`'s responsibility

## Examples

### Example 1 — Mode A (pre-create from idea)

**Input:** `task.plan` (no ID), user describes: "I want to add an email notification when a task is marked complete"

- No task ID — Mode A
- Phase 2: Explore subagents — (a) existing notification or event patterns in the codebase; (b) task completion workflow and trigger points
- Phase 3: Q&A on delivery mechanism (SMTP vs webhook) and failure handling
- Phase 4: Plan and pre-populated task fields shown together in one message
- User approves once → `task.create` invoked immediately with Title, Description, ACs, Implementation Steps, and resolved Design Decisions

### Example 2 — Mode B (pre-start, complex task)

**Input:** `task.plan 007`

- Task 007: all Design Decisions are TBD, task is a spike, implementation approach unresolved
- Verdict: Complex — 3 blocking gaps
- Phase 2: 2 Explore subagents in parallel — (a) external service API the task depends on; (b) existing module patterns and lifecycle signals
- Phase 3: Q&A on key design decisions
- Phase 4: Plan written and approved
- Next steps offered: user selects option 2 (update task file); proposed changes shown field-by-field; confirmed; task file updated

### Example 3 — Mode B (trivial task)

**Input:** `task.plan 012`

- Task 012: 3 ACs, clear steps, no TBD, all dependencies resolved
- Verdict: Trivial — all steps defined, no ambiguity
- Output: "This task looks straightforward. Proceed to `task.start 012`, or request a full plan."
- User declines full plan → skill ends

## Gotchas

- **Write targets are strictly bounded.** Mode A: optional memory capability for plan + `task.create` (after confirmation). Mode B: optional memory capability for plan + specific task file (after confirmation, option 2 only). Never write to PLANNING.md, source files, or any other file.
- **Complexity verdict is a recommendation, not a gate.** The user can always override and request a full plan for a trivial task, or skip planning for a complex one.
- **All-TBD Design Decisions require full Discovery + Alignment before drafting the plan.** Skipping this is the root cause of wasted implementation on spike tasks.
- **Explore subagents must receive an explicit thoroughness level and exact concern area.** Vague prompts ("look at the codebase") return low-value context. Always specify what to find and what to return.
- **Plan is session-scoped.** If saved, `/memories/session/plan.md` is cleared when the session ends. Warn the user if they are resuming a partially planned task in a new session.
- **Show the plan in chat — do not just mention the file.** The memory file, when available, is for persistence and handoff, not a substitute for presenting the plan.
- **Do not assume Implementation Steps in the task file are current.** Task files are written speculatively at creation time; Discovery may reveal stale steps that reference removed abstractions.
- **Task file update requires field-by-field confirmation.** Never batch-replace the entire task file. Present exactly what will change and require explicit approval before writing.
- **Mode A asks for approval exactly once.** The plan and the derived task-create fields are shown together in Step 13; approving either is approving both. Do not add a second confirmation before invoking `task.create` in Step 15 — the fields are mechanically derived from the plan the user already approved, so re-asking adds a round-trip with no new decision in it.

## Completion

- [ ] Mode detected (A or B)
- [ ] Task file read and complexity verdict delivered (Mode B) OR description elicited (Mode A)
- [ ] All blocking gaps resolved via Q&A or documented as explicit assumptions
- [ ] Execution plan written to `/memories/session/plan.md`, if a memory capability is available
- [ ] Full plan shown to user in chat
- [ ] User has explicitly approved the plan
- [ ] Appropriate next steps offered and actioned per mode

## Failure Handling

| Situation | Action |
|-----------|--------|
| Required input not provided | Request the missing information before proceeding |
| Gathered input is ambiguous | Flag the ambiguity and ask for clarification |
| Subagent invocation fails | Report the failure with context; do not silently retry |
| Output artifact already exists | Confirm with user before overwriting |
| Task file not found (Mode B) | Report error; ask user to verify task ID; do not proceed |
| Task file not found (Mode A) | Expected — proceed with user-provided description |
| Task has no ACs and no Implementation Steps | Flag as incomplete spec; use Q&A to elicit a minimum viable spec before planning; do not produce a plan against an empty task |
| Explore subagent returns no useful context | Note the gap in the plan as an unresolved unknown; do not retry with the same query |
| User declines all clarifying questions | Proceed with documented assumptions; mark each assumption explicitly in the Decisions section |
| Memory capability unavailable, or `/memories/session/` write fails | Skip silently (unavailable) or warn (write failure); present full plan in chat only either way |
| User approves trivial task without requesting full plan | Confirm `task.start [id]` is the right next step; do not produce an unnecessary plan |
| Mode A idea too vague to plan | Ask for more detail before launching Discovery; do not proceed with an underspecified description |
| User confirms task file update | Write only changed fields; confirm completion; do not modify any other section |
