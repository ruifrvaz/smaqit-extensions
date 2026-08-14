---
name: smaqit.session-finish
description: End session by documenting the entire conversation. Use at session completion to create history entries.
metadata:
  version: "0.10.0"
---

# Session Finish

End a session by documenting the **entire session** (not just recent activity).

## Usage

```
session.finish                     # Assisted mode (default) - stops for confirmation before commit/push
session.finish --autonomous        # Autonomous mode - commits/pushes automatically when safe
```

## Steps

0. **Establish the full session arc**
   - If the full conversation is already available in your current context (the common case), use it directly as the session arc source — no separate transcript read is needed.
   - Otherwise, if running in an environment where session history must be read from an external transcript log:
     - Derive the transcript path: take `{{VSCODE_TARGET_SESSION_LOG}}`, replace `debug-logs` with `transcripts`, and append `.jsonl`
     - Run `wc -l <path>` in the terminal to check size
     - If **< 500 lines**: read the file directly
     - If **≥ 500 lines**: run `python3 <skill-dir>/scripts/recap.py <transcript-path>` via terminal, where `<skill-dir>` is the directory containing this SKILL.md (derivable from the skill listing path). Use the script output as the session arc source instead of the raw file.
   - The session begins at the first user message — this is always the `session.start` invocation and is the guaranteed anchor for "earliest action in this session"
   - Build the complete session arc from that anchor to the current turn: all topics discussed, decisions made, and files modified
   - Do not proceed to Step 1 until you can enumerate the full arc from `session.start` to now

1. **Check for in-progress tasks** before creating history.
   - Read `.smaqit/tasks/PLANNING.md` (skip silently if absent).
   - If any task shows status "In Progress", list them, STOP, and instruct: "Complete with `task.complete [id]` first, or say 'skip' to proceed."
   - Otherwise continue.

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

3. **If a persistent, cross-session memory/notes capability is available in this environment**, use it to record the following (best-effort — the history file written in Step 1 remains the source of truth regardless of whether this step is available or succeeds):
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

4. **Refresh research map** (best-effort — do not let failure block session completion)
   1. Check whether `.smaqit/references/project-research.md` exists.
   2. **Does not exist** → invoke `smaqit.project-research` to build it for the first time, then continue to Step 4.
   3. **Exists** → read the `**Refreshed:**` date from the map header.
   4. Compute the age of the map in days (current date minus the `Refreshed:` date).
   5. Check whether any project manifest file (`go.mod`, `package.json`, `requirements.txt`, `pyproject.toml`, `*.csproj`, `pom.xml`, `Cargo.toml`, `Gemfile`, `composer.json`, `build.gradle`) has a modification timestamp **newer** than the map's `Refreshed:` date.
   6. **Map is stale** (age ≥ 7 days OR any manifest is newer) → invoke `smaqit.project-research` to rebuild.
   7. **Map is current** → report "Research map is current (last updated: YYYY-MM-DD)" and skip rebuild.
   8. If any error occurs during this step, log a brief warning and continue to Step 6 — research refresh is best-effort.

5. **Update this history file** as the session reference for next chat

6. **Update the project compendium** (after history file is written):
   - Read `references/COMPENDIUM_FORMAT.md` from the `smaqit.project-compendium` skill before writing any entries.
   - Scan the session transcript for user questions — identify questions that are project-specific, non-trivial, and were answered substantively by the agent.
   - Filter out: purely navigational inputs ("what's next?", "continue", "proceed"), one-word commands, meta-session phrases ("new session", "session start", "can you recap?"), and questions whose answers are entirely generic (not project-specific).
   - For each candidate question: check `.smaqit/compendium.md` for semantically similar existing entries.
     - Similar entry found → merge or update: rewrite the answer to incorporate new information, following `COMPENDIUM_FORMAT.md`'s merge procedure.
     - No similar entry found → create new entry, assign appropriate category.
   - Entry structure (question heading, prose answer, `---` separator) is defined entirely by `COMPENDIUM_FORMAT.md` — do not add fields it doesn't define. It explicitly prohibits per-entry dates and session counters; do not invent a "Sessions" or "Last Updated" field.
   - Write the updated compendium atomically (overwrite the file); create the file if it does not exist.
   - Report: "Compendium updated — N entries added, M entries updated." (Skip this report if no candidate questions were found.)

7. **Finalize main branch state** — runs after Step 6 regardless of whether a history file was written this session (main can still be behind `origin/main` from a prior session). Operates only on the primary checkout and only on `main`; never touches another worktree or branch. Determine the skill install directory from this SKILL.md path; every git operation below goes through `<skill-install-dir>/scripts/finalize-main.sh`, which resolves the primary checkout from cwd via `git worktree list --porcelain` and never mutates a branch other than `main`. Do not run the underlying git commands directly — the helper is the only permitted mutation path so behavior is identical between Assisted and Autonomous mode.

   - Run `bash <skill-install-dir>/scripts/finalize-main.sh detect`. Its `state` field is one of:
     - `detached_head`, `merge_in_progress`, or `dirty_non_main` → STOP. Report the exact state and branch it returned. Take no further action, in both Assisted and Autonomous mode. Do not resolve conflicts, discard changes, or force a branch switch.
     - `clean_non_main` → run `bash <skill-install-dir>/scripts/finalize-main.sh checkout-main`. This is unconditional in both modes — it is non-destructive (the helper refuses if the tree is dirty) and mirrors `smaqit.task-complete`'s own unconditional `git checkout main`. Report the switch, then continue below as if `on_main` had been returned.
     - `on_main` with `dirty: false` → skip to the sync step.
     - `on_main` with `dirty: true` → continue to the next bullet.
   - **Stage only this run's own outputs.** Identify the exact paths this session-finish run wrote this session (the Step 2 history file; `.smaqit/compendium.md` if Step 6 updated it; `.smaqit/references/project-research.md` if Step 4 refreshed it). Never pass any other path — the helper stages only the paths given to it, so never substitute `git add -A` or a broader path for the exact list.
     - **Assisted:** list the changed files and stop, asking for explicit confirmation before committing. Do not run `commit` without it.
     - **Autonomous:** run `bash <skill-install-dir>/scripts/finalize-main.sh commit "chore: session housekeeping — <short description>" <exact paths>`.
   - **Sync with `origin/main`.** Run `bash <skill-install-dir>/scripts/finalize-main.sh sync`. Its `sync` field is one of:
     - `up_to_date` or `fast_forwarded` → done.
     - `ahead` → continue to the push step below.
     - `diverged` → STOP. Report the returned `ahead`/`behind` commit counts. Do not pull, merge, or rebase.
   - **Push when the sync step returned `ahead`.**
     - **Assisted:** report the number of commits ready to push and stop for explicit confirmation before pushing.
     - **Autonomous:** run `bash <skill-install-dir>/scripts/finalize-main.sh push`. If it fails (a race with another push), STOP and report the helper's error — do not retry, do not force-push.
   - **Never attempt, in either mode:** resolving a merge conflict, force-pushing, hard-resetting or discarding uncommitted work, rebasing, fixing an authentication/permission failure, or touching a branch or worktree other than the primary checkout's `main`. Report any of these situations to the user; do not solve them.

## Requirements

- **Do NOT create** separate RESUME or TODO files (history file serves this purpose)
- Document the complete session, not just the final activity
- Focus on decisions and rationale, not implementation details
- Always attempt Step 2 (memory) even when no history file was created, if a memory capability is available — it is the cross-branch context mechanism; the history file remains authoritative when it is not available
- `scripts/finalize-main.sh` requires Bash, git, and jq. It is the only permitted mutation path for Step 7 — never run its underlying git commands directly.

## Failure Handling

| Situation | Action |
|-----------|--------|
| `finalize-main.sh detect` returns `detached_head` | STOP. Report the detached commit; do not check out any branch automatically. |
| `finalize-main.sh detect` returns `merge_in_progress` | STOP. Report the conflicting paths; do not resolve, abort, or continue the merge/rebase. |
| `finalize-main.sh detect` returns `dirty_non_main` | STOP. Report the branch and the uncommitted changes; do not switch branches or discard anything. |
| `finalize-main.sh sync` reports a fast-forward pull failure despite `behind` with no `ahead` | STOP. Report the helper's error; do not merge or rebase. |
| `finalize-main.sh sync` returns `diverged` | STOP. Report the returned ahead/behind commit counts; do not pull, merge, or rebase. |
| `finalize-main.sh push` fails | STOP. Report the rejection; do not retry, force-push, or pull-then-retry automatically. |
| `finalize-main.sh sync`/`push` fails on fetch/push due to auth or permissions | STOP. Report the error; do not attempt credential or SSH-agent recovery. |
| Missing `git` or `jq` | STOP. Report that `finalize-main.sh` cannot run; do not fall back to raw git commands. |
| Uncommitted work found outside this run's own known output paths | Do not stage or commit it; report it and leave it untouched. |
