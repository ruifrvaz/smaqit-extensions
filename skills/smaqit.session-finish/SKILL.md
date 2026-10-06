---
name: smaqit.session-finish
description: End session by documenting the entire conversation and giving it a numbered title (`NNN: Title`). Use at session completion to create history entries — including when the user asks to "finish and title" the session. Also answers a request for just the session title ("session title") in title-only mode, without the history and bookkeeping flow.
metadata:
  version: "0.11.0"
---

# Session Finish

End a session by documenting the **entire session** (not just recent activity).

## Usage

```
session.finish                     # Documents the session, then finalizes main's git state; stops only on the failure-handling conditions below
session.title                      # Title-only mode: outputs the session's `NNN: Title` and stops
```

## Modes

This skill owns the session title — there is no separate title skill — so a title is never produced
by a second skill that could end the turn before the history file is written.

- **Full mode (default):** every step below, in order. Any request to finish, close, wrap up or
  document the session runs this mode — including "finish and title", "session finish and session
  title", or any request that combines finishing with a title. The title comes from Step 2 and is
  reported at the end; never stop after producing it.
- **Title-only mode:** the user asks only for the session's title or number ("session title",
  "title this session", "what's this session's number?") and does not ask to finish. Run Step 0
  and Step 2 only, output exactly the `NNN: Title` line, and stop. Write no history file, no memory,
  no research map, no compendium, and touch no git state. If the request is ambiguous between the
  two, use Full mode.

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

2. **Determine the session number and title** (both modes)
   - **Number:** the next sequential `NNN` after the highest-numbered file in `.smaqit/history/`
     (zero-padded to 3 digits); `001` if there are none.
   - **Title**, from the full session arc of Step 0:
     - **2-5 words**, **Title Case**
     - describes the **outcome**, not the activity (avoid bare "Update", "Fix", "Refactor",
       "Various Improvements")
     - uses the project's own technical terminology
     - **no task identifiers** ("Task 062", "B002")
     - **unique**: compare against the titles of existing `.smaqit/history/` files and pick a more
       specific one if it would duplicate
   - Good: "Agent Instructions Compilation Architecture", "Framework Split Evolution",
     "Stateful Specifications". Avoid: "Update Agent Files", "Fix Structure Issues", "Task 062
     Implementation".
   - **Title-only mode:** output exactly `NNN: Title` (e.g. `038: Agent Instructions Compilation
     Architecture`) with no other text, and stop.
   - **Full mode:** keep `NNN` and the title for Step 3 and for the final report, and continue —
     never end the turn here.

3. **Create history file** if session qualifies as significant
   - Filename: `.smaqit/history/NNN_description_YYYY-MM-DD.md`
     - `NNN` = the number from Step 2
     - `description` = the Step 2 title, lowercased, with spaces and punctuation turned into
       underscores (e.g. "Mesh-Only Internal Machine Ingress" → `mesh_only_internal_machine_ingress`),
       so the filename and the title never drift apart
     - `YYYY-MM-DD` = Session date
     - **Do NOT include task identifiers** (e.g., "task_014") in filename
   - Content structure:
     - **Title**: the Step 2 title (e.g., "# Incremental Processing Assessment")
     - **Metadata**: Date, session focus, tasks completed/referenced (include task IDs here)
     - **Actions taken**: What was accomplished
     - **Problems solved**: Issues encountered and resolutions
     - **Decisions made**: Key choices and rationale
     - **Files modified**: Complete list with descriptions
     - **Next steps**: Remaining work or follow-ups
     - **Session Metrics**: Duration, tasks completed, files created/modified, key quantitative outcomes
   - Focus on **what** and **why**, not implementation details
   - Cover the **complete session arc**, not just the last activity

4. **If a persistent, cross-session memory/notes capability is available in this environment**, use it to record the following (best-effort — the history file written in Step 3 remains the source of truth regardless of whether this step is available or succeeds):
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

5. **Refresh research map** (best-effort — do not let failure block session completion)
   1. Check whether `.smaqit/references/project-research.md` exists.
   2. **Does not exist** → invoke `smaqit.project-research` to build it for the first time, then continue to Step 6.
   3. **Exists** → read the `**Refreshed:**` date from the map header.
   4. Compute the age of the map in days (current date minus the `Refreshed:` date).
   5. Check whether any project manifest file (`go.mod`, `package.json`, `requirements.txt`, `pyproject.toml`, `*.csproj`, `pom.xml`, `Cargo.toml`, `Gemfile`, `composer.json`, `build.gradle`) has a modification timestamp **newer** than the map's `Refreshed:` date.
   6. **Map is stale** (age ≥ 7 days OR any manifest is newer) → invoke `smaqit.project-research` to rebuild.
   7. **Map is current** → report "Research map is current (last updated: YYYY-MM-DD)" and skip rebuild.
   8. If any error occurs during this step, log a brief warning and continue to Step 6 — research refresh is best-effort.

6. **Update this history file** as the session reference for next chat

7. **Update the project compendium** (after history file is written):
   - Read `references/COMPENDIUM_FORMAT.md` from the `smaqit.project-compendium` skill before writing any entries.
   - Scan the session transcript for user questions — identify questions that are project-specific, non-trivial, and were answered substantively by the agent.
   - Filter out: purely navigational inputs ("what's next?", "continue", "proceed"), one-word commands, meta-session phrases ("new session", "session start", "can you recap?"), and questions whose answers are entirely generic (not project-specific).
   - For each candidate question: check `.smaqit/compendium.md` for semantically similar existing entries.
     - Similar entry found → merge or update: rewrite the answer to incorporate new information, following `COMPENDIUM_FORMAT.md`'s merge procedure.
     - No similar entry found → create new entry, assign appropriate category.
   - Entry structure (question heading, prose answer, `---` separator) is defined entirely by `COMPENDIUM_FORMAT.md` — do not add fields it doesn't define. It explicitly prohibits per-entry dates and session counters; do not invent a "Sessions" or "Last Updated" field.
   - Write the updated compendium atomically (overwrite the file); create the file if it does not exist.
   - Report: "Compendium updated — N entries added, M entries updated." (Skip this report if no candidate questions were found.)

8. **Finalize main branch state** — runs after Step 7 regardless of whether a history file was written this session. `main` can still be behind `origin/main` from a prior session, or — since task 036 moved task-lifecycle bookkeeping commits to local `main` only, never pushed — routinely ahead with an entire session's worth of unpushed task bookkeeping. Operates only on the primary checkout and only on `main`; never touches another worktree or branch. Resolve the primary checkout path via `git worktree list --porcelain` — never assume cwd is the primary checkout.

   - **First, check for an existing bookkeeping-sync PR** left by a previous session's fallback: `gh pr list --head chore/session-bookkeeping-sync --state open`.
     - No `chore/session-bookkeeping-sync` branch exists remotely at all → skip this check entirely and proceed to the normal decision tree below (the common case on every unprotected `main`, and the common case here even on a protected one until the fallback first fires).
     - **An open PR is found** → report that it's still awaiting review and **STOP** here — do not proceed to the decision tree below, do not push anything, do not open a second PR.
     - **No open PR, but the branch exists remotely** → check whether it was merged: `gh pr list --head chore/session-bookkeeping-sync --state merged --limit 1` (or `gh pr view <PR#> --json state,mergedAt` if the number is already known). If merged, reconcile local `main`: `git fetch origin main && git merge origin/main` — never `--ff-only` here, since local `main` may have advanced further with additional session/task bookkeeping since that branch was last updated. **A genuine merge conflict is never auto-resolved:** abort it (`git merge --abort`) and STOP, reporting the conflicting paths. On a clean reconcile (fast-forward or a real merge), continue into the normal decision tree below for anything left over. If neither open nor merged (e.g. closed unmerged), report the anomaly and STOP — do not guess.
   - Check the current branch and status (`git branch --show-current`, `git status --porcelain`). If already on `main`, clean, and in sync with `origin/main`, there is nothing to do.
   - If the situation is straightforward, resolve it directly:
     - On a different branch with a clean tree → `git checkout main`.
     - Uncommitted changes on `main` from files this run itself wrote (the Step 3 history file; `.smaqit/compendium.md` if Step 7 updated it; `.smaqit/references/project-research.md` if Step 5 refreshed it) → stage exactly those paths (never `git add -A` or a broader path) and commit.
     - Behind `origin/main` with no local commits of your own → `git fetch origin main && git pull --ff-only origin main`.
     - Ahead of `origin/main` with nothing to pull → attempt `git push origin main` first, exactly as always:
       - **Succeeds** → done; nothing else to do.
       - **Rejected for protected-branch reasons** (stderr contains `GH006`, `protected branch`, or `Changes must be made through a pull request`, or an equivalent required-review/required-status-check message) → fall back to a reused sync branch instead of stopping outright:
         ```bash
         git fetch origin chore/session-bookkeeping-sync 2>/dev/null || true
         git push --force-with-lease origin main:refs/heads/chore/session-bookkeeping-sync
         ```
         The fetch (harmless no-op the first time the branch doesn't exist yet) establishes the lease baseline; the push then creates the remote branch on its first use and force-with-lease-updates it on every later one — no local branch ever needs to be created for it. If an open PR already targets that branch, the push alone updates it in place — nothing further to do. Otherwise open one:
         ```bash
         gh pr create --base main --head chore/session-bookkeeping-sync \
           --title "chore: sync session bookkeeping" \
           --body "<what this carries — history file, compendium, research map, task bookkeeping>"
         ```
         That title deliberately never matches `Prepare release vX.Y.Z`/`Release vX.Y.Z`, so merging it never triggers `post-merge-release.yml`'s tag/release automation. Report the PR link and **STOP** — never self-merge it (a required-review protected branch exists specifically to force a human review), never retry the direct push, never delete or close the branch/PR afterward — it is deliberately long-lived and reused across sessions, not a one-shot branch to clean up.
       - **Rejected for any other reason** (auth/permission failure, non-fast-forward/diverged history, or anything else not matching the protected-branch pattern above) → unchanged: fall straight into the STOP-and-report handling below. Never reclassify a 403/permission rejection as the protected-branch case — an auth failure means you lack push rights at all, which this fallback cannot fix and must not paper over.
   - **If anything doesn't resolve cleanly on the first safe attempt, or the situation is ambiguous or risky** — a detached HEAD, an in-progress merge/conflict, a dirty branch other than `main`, diverged history, an unexpected push rejection not covered by the protected-branch fallback above, an authentication failure, or anything else you're not confident is safe — **STOP.** Report exactly what you observed and take no further action. Do not guess, retry, or improvise a fix.
   - **Never attempt:** resolving a merge conflict, force-pushing `main` itself (a force-with-lease push to the dedicated `chore/session-bookkeeping-sync` branch is the one documented exception, never to `main`), hard-resetting or discarding uncommitted work, rebasing, fixing an authentication/permission failure, self-merging the bookkeeping-sync PR, or touching a branch or worktree other than the primary checkout's `main` and that one dedicated sync branch. Report any of these situations to the user; do not solve them.

## Requirements

- **Do NOT create** separate RESUME or TODO files (history file serves this purpose)
- **Full mode ends with a report whose first line is the Step 2 `NNN: Title`**, followed by what was
  written and the git outcome. Producing the title never ends Full mode early: the history file and
  every later step still run in the same turn.
- Document the complete session, not just the final activity
- Focus on decisions and rationale, not implementation details
- Always attempt Step 4 (memory) even when no history file was created, if a memory capability is available — it is the cross-branch context mechanism; the history file remains authoritative when it is not available

## Failure Handling

| Situation | Action |
|-----------|--------|
| Detached HEAD | STOP. Report the detached commit; do not check out any branch automatically. |
| An in-progress merge or conflict markers | STOP. Report the conflicting paths; do not resolve, abort, or continue the merge/rebase. |
| A non-`main` branch with a dirty tree | STOP. Report the branch and the uncommitted changes; do not switch branches or discard anything. |
| `git pull --ff-only` fails despite an apparent clean fast-forward | STOP. Report the error; do not merge or rebase. |
| Local `main` has diverged from `origin/main` | STOP. Report the ahead/behind situation; do not pull, merge, or rebase. |
| `git push origin main` is rejected for protected-branch reasons (`GH006`, "protected branch", "Changes must be made through a pull request", or equivalent) | Push/update the reused `chore/session-bookkeeping-sync` branch and open or update its PR (see Step 8), then STOP and report the PR link — never self-merge, never retry the direct push. |
| `git push` is rejected for any other reason (including a 403/permission failure) | STOP. Report the rejection; do not retry, force-push, pull-then-retry, or reclassify it as the protected-branch case above. |
| An open `chore/session-bookkeeping-sync` PR already exists | STOP. Report that it's awaiting review; do not push again or open a second PR. |
| A genuine merge conflict reconciling a merged `chore/session-bookkeeping-sync` PR back into local `main` | STOP. Abort the merge (`git merge --abort`) and report the conflicting paths; never auto-resolve. |
| Authentication/permission failure on fetch or push | STOP. Report the error; do not attempt credential or SSH-agent recovery. |
| Uncommitted work found outside this run's own known output paths | Do not stage or commit it; report it and leave it untouched. |
| Anything else that doesn't resolve cleanly on the first safe attempt | STOP. Report what you observed; do not guess or improvise a fix. |
