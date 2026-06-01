---
name: smaqit.task-plan
description: Plans a specific task [id] before implementation. Reads the task file, scores complexity, resolves design gaps via iterative Q&A, and produces an approved execution plan at `/memories/session/plan.md`. Invoke when a task has unresolved Design Decisions, empty or stale Implementation Steps, or more than 7 Acceptance Criteria.
metadata:
  version: "1.0.0"
---

# Task Plan

## Steps

### Phase 1 — Task Assessment (always runs)

1. Read `.smaqit/tasks/NNN_*.md` for the given task ID. Extract: Description, Acceptance Criteria, Implementation Steps, Design Decisions, Notes, dependencies, and any existing Findings. If the task file is not found, report the error and ask the user to verify the task ID. Do not proceed.

2. Score complexity:

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

3. Build a gap list: label each identified gap and classify as **Blocking** (must resolve before plan) or **Advisory** (can proceed with assumption).

4. Present the complexity verdict and gap list to the user.
   - **Trivial verdict:** Recommend `task.start [id]` directly. Offer to produce a full plan on request. Stop here unless the user requests a full plan.
   - **Complex verdict:** Present the gap list and continue to Phase 2.

### Phase 2 — Discovery (complex tasks only)

5. Identify 1–3 concern areas from the gap list. Typical examples: existing patterns the task must follow, external service API behaviour the task depends on, or test infrastructure patterns the task must replicate.

6. Launch one Explore subagent per concern area (in parallel when independent). Each subagent prompt must specify:
   - The exact concern area to investigate
   - Thoroughness level: `quick`, `medium`, or `thorough`
   - What to return: specific files, types, function names, patterns, or API endpoints — not general summaries

7. Update the in-memory plan draft with findings from each subagent. Note any concerns that returned no useful context.

### Phase 3 — Alignment (if blocking gaps remain after Discovery)

8. Use `vscode_askQuestions` iteratively to resolve blocking gaps. Present one logical cluster per invocation, each question paired with a recommended option and rationale. If user answers reveal scope changes, loop back to Phase 2 with updated subagent queries.

9. For advisory gaps the user declines to clarify, document an explicit assumption in the plan draft.

### Phase 4 — Design

10. Draft the execution plan using the following structure:

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

11. Save the plan to `/memories/session/plan.md` using the `memory` tool (create or overwrite).

12. **Show the full plan to the user.** The memory file is for persistence only — do not substitute it for presenting the plan in chat.

### Phase 5 — Refinement

13. Await user feedback and iterate:
    - **Changes requested** → revise plan, re-save to `/memories/session/plan.md`, re-show updated plan
    - **Questions asked** → clarify inline; use `vscode_askQuestions` if follow-up questions are needed
    - **Alternatives wanted** → loop back to Phase 2 with a new Explore subagent targeting the alternative
    - **Explicit approval given** → instruct user to run `task.start [id]` to begin implementation

## Output

- `/memories/session/plan.md` — approved execution plan; session-scoped, never committed to git
- Complexity verdict and gap list — surfaced in chat, not persisted
- Optional: suggestions for improving `## Implementation Steps` in the task file, presented as recommendations only; user decides whether to apply them before running `task.start`

## Scope

**In scope:**
- Reading and assessing any task file by ID
- Launching Explore subagents to gather codebase context
- Iterative Q&A to resolve design decisions and gaps
- Writing and refining an execution plan

**Out of scope:**
- Does not implement code or modify source files
- Does not modify task files, PLANNING.md, or any project files
- Does not run tests, builds, or services
- Precedes `task.start` — does not replace it
- Does not validate acceptance criteria — that is `task.complete`'s responsibility

## Examples

### Example 1 — Complex task

**Input:** `task.plan 007`

- Task 007: all Design Decisions are TBD, task is a spike, key architectural choice unresolved
- Verdict: Complex — 2 blocking gaps (deduplication strategy, session-boundary trigger)
- Phase 2: 2 Explore subagents in parallel — (a) external service API dedup/reprocess endpoints; (b) existing path patterns and session lifecycle signals in the codebase
- Phase 3: Q&A on dedup strategy (reprocess vs delete+reinsert) and trigger mechanism (disconnect event vs token budget)
- Phase 4: Plan written covering new path design, TraverseRule, dedup flow, trigger wiring, test structure
- Plan shown and approved → user runs `task.start 007`

### Example 2 — Trivial task

**Input:** `task.plan 012`

- Task 012: 3 ACs, clear steps, no TBD, all dependencies resolved
- Verdict: Trivial — all steps defined, no ambiguity
- Output: "This task looks straightforward. You can go directly to `task.start 012`. Want a full plan anyway?"
- User declines → skill ends

## Gotchas

- **Never call file-editing tools.** The only write tool is `memory` for `/memories/session/plan.md`. Any other write is a violation of this skill's contract.
- **Complexity verdict is a recommendation, not a gate.** The user can always override and request a full plan for a trivial task, or skip planning for a complex one.
- **All-TBD Design Decisions require full Discovery + Alignment before drafting the plan.** Skipping this is the root cause of wasted implementation on spike tasks.
- **Explore subagents must receive an explicit thoroughness level and exact concern area.** Vague prompts ("look at the codebase") return low-value context. Always specify what to find and what to return.
- **Plan is session-scoped.** `/memories/session/plan.md` is cleared when the session ends. Warn the user if they are resuming a partially planned task in a new session.
- **Show the plan in chat — do not just mention the file.** The memory file is for persistence and handoff, not a substitute for presenting the plan.
- **Do not assume Implementation Steps in the task file are current.** Task files are written speculatively at creation time; Discovery may reveal stale steps that reference removed abstractions.

## Completion

- [ ] Task file read and complexity verdict delivered to user
- [ ] All blocking gaps resolved via Q&A or documented as explicit assumptions
- [ ] Execution plan written to `/memories/session/plan.md`
- [ ] Full plan shown to user in chat
- [ ] User has explicitly approved the plan
- [ ] User instructed to run `task.start [id]`

## Failure Handling

| Situation | Action |
|-----------|--------|
| Required input not provided | Request the missing information before proceeding |
| Gathered input is ambiguous | Flag the ambiguity and ask for clarification |
| Subagent invocation fails | Report the failure with context; do not silently retry |
| Output artifact already exists | Confirm with user before overwriting |
| Task file not found | Report error; ask user to verify task ID; do not proceed |
| Task has no ACs and no Implementation Steps | Flag as incomplete spec; use Q&A to elicit a minimum viable spec before planning; do not produce a plan against an empty task |
| Explore subagent returns no useful context | Note the gap in the plan as an unresolved unknown; do not retry with the same query |
| User declines all clarifying questions | Proceed with documented assumptions; mark each assumption explicitly in the Decisions section |
| `/memories/session/` write fails | Warn user; present full plan in chat only |
| User approves trivial task without requesting full plan | Confirm `task.start [id]` is the right next step; do not produce an unnecessary plan |
