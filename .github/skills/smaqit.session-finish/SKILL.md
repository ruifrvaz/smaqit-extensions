---
name: smaqit.session-finish
description: End session by documenting the entire conversation. Use at session completion to create history entries.
metadata:
  version: "0.4.1"
---

# Session Finish

End a session by documenting the **entire session** (not just recent activity).

## Steps

1. **Review full conversation** - All topics discussed, decisions made, files modified
   - **If a `<conversation-summary>` block is present in context**, it represents work done earlier in this same session — not background from a previous session. Treat it as the first segment of the session arc and include all work described in it in the history file.

2. **Create history file** if session qualifies as significant
   - Filename: `.smaqit/history/NNN_description_YYYY-MM-DD.md`
     - `NNN` = Next sequential number (inspect existing files; if none exist, start at `001`)
     - `description` = Brief topic description (2-4 words, lowercase with underscores)
     - `YYYY-MM-DD` = Session date
     - **Do NOT include task identifiers** (e.g., "task_014") in filename
   - Content structure:
     - **Title**: Matches filename description, converted to title case (e.g., "# Incremental Processing Assessment")
     - **Metadata**: Date, session focus, tasks completed/referenced (include task IDs here)
     - **Actions taken**: What was accomplished
     - **Problems solved**: Issues encountered and resolutions
     - **Decisions made**: Key choices and rationale
     - **Files modified**: Complete list with descriptions
     - **Next steps**: Remaining work or follow-ups
     - **Session Metrics**: Duration, tasks completed, files created/modified, key quantitative outcomes
   - Focus on **what** and **why**, not implementation details
   - Cover the **complete session arc**, not just the last activity

3. **Store session context in memory** using the `store_memory` tool (call both in parallel):
   - **Session summary** — captures what happened so any future session on any branch can pick up where this one left off:
     - `subject`: `"session history"`
     - `fact`: `"[NNN] [YYYY-MM-DD]: [2–3 sentence summary of key actions, decisions, and outcomes]"` (≤ 200 chars)
     - `citations`: path to the history file just created (e.g., `.smaqit/history/NNN_description_YYYY-MM-DD.md`)
     - `reason`: `"Provides cross-branch session context so the next session start can resume work regardless of active branch"`
   - **Next steps** — surfaces pending work immediately on next session start:
     - `subject`: `"next steps"`
     - `fact`: `"[1–3 most important pending actions or decisions]"` (≤ 200 chars)
     - `citations`: path to the history file just created
     - `reason`: `"Ensures pending work is visible in the next session regardless of active branch"`

   **Note:** Task state in memory is owned by task skills (`task-create`, `task-start`, `task-complete`). Do NOT store task lists or task status here.

4. **Update this history file** as the session reference for next chat

## Requirements

- **Do NOT create** separate RESUME or TODO files (history file serves this purpose)
- Document the complete session, not just the final activity
- Focus on decisions and rationale, not implementation details
- Always call `store_memory` (Step 3) even when no history file was created — memory is the cross-branch context mechanism
