---
name: smaqit.session-finish
description: End session by documenting the entire conversation. Use at session completion to create history entries.
metadata:
  version: "0.2.0"
---

# Session Finish

End a session by documenting the **entire session** (not just recent activity).

## Steps

1. **Review full conversation** - All topics discussed, decisions made, files modified

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

3. **Update this history file** as the session reference for next chat

## Requirements

- **Do NOT create** separate RESUME or TODO files (history file serves this purpose)
- Document the complete session, not just the final activity
- Focus on decisions and rationale, not implementation details
