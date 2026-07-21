# Session Recap Table Template

**Version:** 0.2.0  
**Purpose:** Define the strict output format for session step reviews

This template defines the exact table format for session recaps. Populate each column based on the current session conversation.

---

## Table Format

| Step | Status | Notes |
|------|--------|-------|
| 1. [Step description] | ✅ Done | [One-liner note] |
| 2. [Step description] | ⏳ Pending | [One-liner note] |
| 3. [Step description] | 🚫 Blocked | [One-liner note] |
| 4. [Step description] | 🗑️ Abandoned | [One-liner note] |

---

## Column Definitions

- **Step** — Sequential step number (1, 2, 3 …) followed by a short description of the step, decision, or action item.
- **Status** — Current status of the step, using the emoji indicator:
  - ✅ Done — completed during this session
  - ⏳ Pending — not yet started or still in progress
  - 🚫 Blocked — cannot proceed due to a dependency or blocker
  - 🗑️ Abandoned — dropped or superseded
- **Notes** — One short phrase with context, outcome, or reason. Use `-` if not applicable.

---

## Rendering Rules

- Output the table as the primary response body. A single brief intro line and a single brief closing line are acceptable.
- Rows are ordered chronologically by step number.
- Each row represents one unit of work (step, decision, action item, or deliverable).
- Every significant session action MUST appear in the table — do not omit steps.
- Use `-` to fill empty cells. Never leave a cell blank.
- Do NOT add or remove columns. Strictly 3 columns only.
