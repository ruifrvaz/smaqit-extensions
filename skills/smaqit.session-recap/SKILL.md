---
name: smaqit.session-recap
description: Summarize session progress as a structured table of accomplished and pending steps. Invoke when the user asks for a "recap of the session", "review of the session", or "progress on the session".
metadata:
  version: "0.3.0"
---

# Session Recap

## Steps

0. **Read the full session from the transcript**
   - Derive the transcript path: take `{{VSCODE_TARGET_SESSION_LOG}}`, replace `debug-logs` with `transcripts`, and append `.jsonl`
   - Run `wc -l <path>` in the terminal to check size, then read the file using the `read_file` tool
   - The session begins at the first user message — this is always the `session.start` invocation and is the guaranteed anchor for the start of the session
   - Build the complete session arc from that anchor to the current turn before enumerating steps

1. **Load the output template** by reading [references/TABLE.md](references/TABLE.md)

2. **Enumerate every significant step** from the session arc loaded in Step 0 — assign each a sequential step number starting from 1

3. **Render the recap table** following the strict format defined in [references/TABLE.md](references/TABLE.md)

4. **Present the table** as the primary output

## Requirements

- **Strict table format:** Always use the template from [references/TABLE.md](references/TABLE.md) — do NOT invent a different layout
- **Complete coverage:** Every significant session action must appear in the table
- **No omissions:** Do not skip steps even if they seem minor
- **Concise cells:** Keep each cell to one short phrase or sentence
- **Empty cells:** Use `-` — never leave a cell blank
