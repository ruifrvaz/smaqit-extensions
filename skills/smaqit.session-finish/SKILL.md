---
name: smaqit.session-finish
description: End session by documenting the entire conversation. Use at session completion to create history entries.
metadata:
  version: "0.8.1"
---

# Session Finish

End a session by documenting the **entire session** (not just recent activity).

## Steps

0. **Read the full session from the transcript**
   - Derive the transcript path: take `{{VSCODE_TARGET_SESSION_LOG}}`, replace `debug-logs` with `transcripts`, and append `.jsonl`
   - Run `wc -l <path>` in the terminal to check size
   - If **< 500 lines**: read the file directly using the `read_file` tool
   - If **≥ 500 lines**: run `python3 <skill-dir>/scripts/recap.py <transcript-path>` via terminal, where `<skill-dir>` is the directory containing this SKILL.md (derivable from the skill listing path). Use the script output as the session arc source instead of the raw file.
   - The session begins at the first user message — this is always the `session.start` invocation and is the guaranteed anchor for "earliest action in this session"
   - Build the complete session arc from that anchor to the current turn: all topics discussed, decisions made, and files modified
   - Do not proceed to Step 1 until you can enumerate the full arc from `session.start` to now

1. **Create history file** if session qualifies as significant
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

2. **Store session context in memory** using the `memory` tool with `type: workspace` (call both in parallel):
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

3. **Refresh research map** (best-effort — do not let failure block session completion)
   1. Check whether `.smaqit/references/project-research.md` exists.
   2. **Does not exist** → invoke `smaqit.project-research` to build it for the first time, then continue to Step 4.
   3. **Exists** → read the `**Refreshed:**` date from the map header.
   4. Compute the age of the map in days (current date minus the `Refreshed:` date).
   5. Check whether any project manifest file (`go.mod`, `package.json`, `requirements.txt`, `pyproject.toml`, `*.csproj`, `pom.xml`, `Cargo.toml`, `Gemfile`, `composer.json`, `build.gradle`) has a modification timestamp **newer** than the map's `Refreshed:` date.
   6. **Map is stale** (age ≥ 7 days OR any manifest is newer) → invoke `smaqit.project-research` to rebuild.
   7. **Map is current** → report "Research map is current (last updated: YYYY-MM-DD)" and skip rebuild.
   8. If any error occurs during this step, log a brief warning and continue to Step 4 — research refresh is best-effort.

4. **Update this history file** as the session reference for next chat

4. **Update the project compendium** (after history file is written):
   - Read `references/COMPENDIUM_FORMAT.md` from the `smaqit.project-compendium` skill before writing any entries.
   - Scan the session transcript for user questions — identify questions that are project-specific, non-trivial, and were answered substantively by the agent.
   - Filter out: purely navigational inputs ("what's next?", "continue", "proceed"), one-word commands, meta-session phrases ("new session", "session start", "can you recap?"), and questions whose answers are entirely generic (not project-specific).
   - For each candidate question: check `.smaqit/compendium.md` for semantically similar existing entries.
     - Similar entry found → merge or update: rewrite the answer to incorporate new information, increment Sessions, update Last Updated.
     - No similar entry found → create new entry, assign appropriate category, set Sessions = 1.
   - Write the updated compendium atomically (overwrite the file); create the file if it does not exist.
   - Report: "Compendium updated — N entries added, M entries updated." (Skip this report if no candidate questions were found.)

## Requirements

- **Do NOT create** separate RESUME or TODO files (history file serves this purpose)
- Document the complete session, not just the final activity
- Focus on decisions and rationale, not implementation details
- Always call the `memory` tool with `type: workspace` (Step 2) even when no history file was created — memory is the cross-branch context mechanism
