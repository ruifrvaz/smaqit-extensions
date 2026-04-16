# Session Recap Table Template

**Version:** 0.1.0  
**Purpose:** Define the strict output format for session step reviews

This template defines the exact table format for session recaps. Populate each column based on the current session conversation.

---

## Table Format

| Steps Accomplished | Steps Pending | Notes / Outcome |
|--------------------|---------------|-----------------|
| [Step or decision completed] | [Step or action still outstanding] | [Brief result or context] |
| … | … | … |

---

## Column Definitions

- **Steps Accomplished** — Steps, decisions, or work items completed during the session. Use `-` if there is no accomplished step for this row.
- **Steps Pending** — Steps, action items, or work still outstanding. Use `-` if there is no pending step for this row.
- **Notes / Outcome** — Brief context, result, or rationale for the step (one short phrase). Use `-` if not applicable.

---

## Rendering Rules

- Output the table as the primary response body. A single brief intro line and a single brief closing line are acceptable.
- Rows are ordered chronologically: accomplished steps first (in session order), followed by pending steps.
- If an accomplished step and a pending step are directly related, they may appear in the same row.
- Each row represents one unit of work (step, decision, action item, or deliverable).
- Every significant session action MUST appear in the table — do not omit steps.
- Use `-` to fill empty cells. Never leave a cell blank.
- Do NOT add or remove columns. Strictly 3 columns only.
