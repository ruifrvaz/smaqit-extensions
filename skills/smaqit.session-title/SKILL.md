---
name: smaqit.session-title
description: Generate a succinct title for the current session based on work accomplished. Use when finishing sessions to create history file titles.
metadata:
  version: "0.4.0"
---

# Session Title

Generate a concise, descriptive title for the current session based on the work accomplished.

## Steps

0. **Read the full session from the transcript**
   - Derive the transcript path: take `{{VSCODE_TARGET_SESSION_LOG}}`, replace `debug-logs` with `transcripts`, and append `.jsonl`
   - Run `wc -l <path>` in the terminal to check size
   - If **< 500 lines**: read the file directly using the `read_file` tool
   - If **≥ 500 lines**: run `python3 <skill-dir>/scripts/recap.py <transcript-path>` via terminal, where `<skill-dir>` is the directory containing this SKILL.md (derivable from the skill listing path). Use the script output as the session arc source instead of the raw file.
   - The session begins at the first user message — this is always the `session.start` invocation and is the guaranteed anchor
   - Build the complete session arc from that anchor to the current turn before generating the title

1. **Review the session arc loaded in Step 0** to identify:
   - Primary focus/goal of the session
   - Key deliverables or outcomes
   - Major decisions or insights
   - Problems solved

2. **Generate title** following these rules:
   - **2-5 words maximum** (brevity is critical)
   - **Title case** (e.g., "Agent Instructions Compilation Architecture")
   - **Focus on outcome** (what was achieved, not just what was done)
   - **Use technical precision** (use the project's terminology when applicable)
   - **Avoid generic terms** (avoid "Update", "Fix", "Refactor" alone)
   - **No task identifiers** (no "Task 062" or "B002")

3. **Validate title** against history files:
   - Check `.smaqit/history/` for similar titles to avoid duplication
   - Ensure title is unique and specific

4. **Get session number**:
   - Infer the last sequential number by inspecting existing filenames in `.smaqit/history/`.
   - If no history files exist yet, use `001` as the next session number.

5. **Output session number and title** in this format with no additional text:
   ```
   038: Agent Instructions Compilation Architecture
   ```

## Title Patterns

**Good examples:**
- "Agent Instructions Compilation Architecture" (specific technical outcome)
- "Framework Split Evolution" (clear transformation)
- "Documentation Architecture Refinement" (focused improvement)
- "Phase First Workflow" (new pattern established)
- "Stateful Specifications" (feature added)

**Avoid:**
- "Update Agent Files" (too generic)
- "Fix Structure Issues" (problem-focused, not outcome-focused)
- "Refactor Code" (no specificity)
- "Task 062 Implementation" (task identifier)
- "Various Improvements" (not specific)

## Requirements

- Title must be **2-5 words**
- Title must describe **outcome, not action**
- Title must be **unique** compared to existing history files
- Title must use **proper technical terminology** from the project domain
