---
name: smaqit.session-recap
description: Summarize session progress as a structured table of accomplished and pending steps. Invoke when the user asks for a "recap of the session", "review of the session", or "progress on the session".
metadata:
  version: "0.2.0"
---

# Session Recap

## Steps

1. **Load the output template** by reading [references/TABLE.md](references/TABLE.md)

2. **Review the full conversation** and enumerate every significant step, decision, or action item — assign each a sequential step number starting from 1

3. **Render the recap table** following the strict format defined in [references/TABLE.md](references/TABLE.md)

4. **Present the table** as the primary output

## Requirements

- **Strict table format:** Always use the template from [references/TABLE.md](references/TABLE.md) — do NOT invent a different layout
- **Complete coverage:** Every significant session action must appear in the table
- **No omissions:** Do not skip steps even if they seem minor
- **Concise cells:** Keep each cell to one short phrase or sentence
- **Empty cells:** Use `-` — never leave a cell blank
