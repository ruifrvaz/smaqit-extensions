---
name: smaqit.session-recap
description: Summarize session progress as a structured table of accomplished and pending steps. Invoke when the user asks for a "recap of the session", "review of the session", or "progress on the session".
metadata:
  version: "0.1.0"
---

# Session Recap

Produce a structured summary of the current session's progress.

## Triggers

Invoke this skill when the user asks for any of the following (exact phrases or close equivalents):
- "recap of the session"
- "review of the session"
- "progress on the session"

## Steps

1. **Load the output template** by reading [references/TABLE.md](references/TABLE.md)

2. **Review the full conversation** to identify:
   - All steps, decisions, and actions that have been completed
   - All steps, actions, and items that are still outstanding or not yet started

3. **Render the recap table** following the strict format defined in [references/TABLE.md](references/TABLE.md):
   - One row per unit of work (step, decision, action, or deliverable)
   - Accomplished steps first (chronological session order), then pending steps
   - Related accomplished/pending pairs may share a row

4. **Present the table** as the primary output

## Requirements

- **Strict table format:** Always use the template from [references/TABLE.md](references/TABLE.md) — do NOT invent a different layout
- **Complete coverage:** Every significant session action must appear in the table
- **No omissions:** Do not skip steps even if they seem minor
- **Concise cells:** Keep each cell to one short phrase or sentence
- **Empty cells:** Use `-` — never leave a cell blank
