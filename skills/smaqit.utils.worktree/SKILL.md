---
name: smaqit.utils.worktree
description: "Sync Git worktrees and update the VS Code multi-root workspace, or set up worktrees for task branches. For interactive sync, presents local and remote branches and asks which branches to sync. Then creates missing sibling worktrees, detects and removes safe orphans, and keeps the project workspace in sync. Also migrates VS Code chat sessions when switching from a single-folder project to the generated multi-root workspace. Use after task branch creation, task completion, workspace migration, or when worktree folders are missing from VS Code Explorer. Triggers: `worktree.sync`, `worktree.migrate-sessions`."
metadata:
  version: "1.2.1"
---

# smaqit Utils: Git Worktree Manager

## Steps

### 1. Present branch selection

When called by `smaqit.task-start` for a lifecycle-owner task, use the supplied task branch without prompting. A declared child task is resolved by Step 9 first and does not reach branch selection or worktree creation. When invoked directly as `worktree.sync`, present the full branch landscape and ask which branches should have worktrees before touching the filesystem or Git state.

Run the branch info script to gather all local and remote branches with tracking data:

```bash
bash [SMAQIT_SKILLS_DIR]/smaqit.utils.worktree/scripts/1_present_branches.sh
```

It outputs a JSON structure like:
```json
{
  "local": [
    {"name": "main", "tracking": "origin/main", "ahead": 0, "behind": 0},
    {"name": "feat/foo", "tracking": null, "ahead": null, "behind": null}
  ],
  "remote": ["origin/main", "origin/example"]
}
```

For interactive sync, compile a side-by-side comparison table from this data with columns: **Local Branch**, **Remote Branch**, **Ahead**, **Behind**. Then present it and ask:

> Which branches should have worktrees? (comma-separated list, or `all` for all non-main local branches, or `none` to skip)

**Rules:**
- `main` is never eligible (the primary repo directory covers it)
- Remote-only branches (no local ref) are not eligible
- If a selected branch already has a worktree, it will be skipped during creation
- If `none`, exit cleanly with "No branches selected — nothing to sync."

Parse the response into a list of branch names. This list, or the task branch supplied by `task-start`, feeds into Step 3 onwards.

### 2. Validate prerequisites

Run the validation script — checks that `git`, `jq` are on PATH and the current directory is a Git repository:

```bash
bash [SMAQIT_SKILLS_DIR]/smaqit.utils.worktree/scripts/2_validate_prereqs.sh
```

If the script exits non-zero, report the error message and stop.

### 3. Compute slugs for selected branches

Pass the selected branch names to the slug-computation script. It outputs a JSON mapping of `branch → slug` to stdout:

```bash
bash [SMAQIT_SKILLS_DIR]/smaqit.utils.worktree/scripts/3_compute_slugs.sh feat/hindsight demo/user-identity
```

Output example:
```json
{"feat/hindsight":"<project>-wt-feat-hindsight","demo/user-identity":"<project>-wt-demo-user-identity"}
```

Capture this JSON — it feeds into Steps 5 and 7.

Slug rules (also documented in the script):
- Replace non-alphanumeric chars (except `/`, `-`, `.`) with `-`
- Replace `/` with `-`
- Lowercase
- Prefix with the repository directory name followed by `-wt-`

### 4. Enumerate existing worktrees

Run the enumeration script — it outputs a JSON map of `branch → worktree_path` for all non-main worktrees:

```bash
bash [SMAQIT_SKILLS_DIR]/smaqit.utils.worktree/scripts/4_enumerate_worktrees.sh
```

Output example:
```json
{"demo/user-identity":"/path/to/<project>-wt-demo-user-identity"}
```

Capture this JSON — it feeds into Step 5 to avoid creating duplicate worktrees.

### 5. Create missing worktrees

Pipe the branch→slug JSON (from Step 3) into the creation script, passing the existing worktrees JSON (from Step 4) as the `--existing` argument:

```bash
echo '<branch-slug-json>' \
  | bash [SMAQIT_SKILLS_DIR]/smaqit.utils.worktree/scripts/5_create_worktrees.sh \
      --existing '<existing-json>'
```

The script outputs a JSON summary:
```json
{
  "created": {"feat/hindsight": "../<project>-wt-feat-hindsight"},
  "skipped": {},
  "errors": {}
}
```

**Sparse layout.** Task worktrees retain project-owned paths, including `.github/workflows/`. Under the default (global) installation, a project contains none of `.github/agents/`, `.github/skills/`, `.claude/agents/`, `.claude/commands/`, `.claude/skills/`, `.agents/skills/`, or `.codex/agents/` at all — agents and skills live outside the repository at `~/.copilot/`, `~/.claude/`, `~/.codex/`, and `~/.agents/skills/`. The sparse-checkout list still excludes those paths defensively, but only a project that explicitly used `install --scope project` ever populates them — this repository included, since it carries no committed dogfooding mirrors of its own. `.smaqit/tasks/` is also excluded — task state (`PLANNING.md` and individual task files) lives exclusively on the primary checkout, so no worktree ever holds a mutable copy that could diverge and conflict on merge. The rest of `.smaqit/` (templates, references, definitions, user-testing) remains available.

**Error handling** is built into the script — it logs per-branch errors and continues. If sparse configuration fails after worktree creation, the script disables sparse checkout in that worktree and reports the error, leaving a usable full checkout. Report any errors to the user after the script completes.

### 6. Detect orphan worktrees

Run the orphan detection script — it checks all registered worktrees against `git branch --list` and removes any whose branch has been deleted:

```bash
bash [SMAQIT_SKILLS_DIR]/smaqit.utils.worktree/scripts/6_detect_orphans.sh
```

Output:
```json
{"removed": {"feat/hindsight": "/path/to/wt"}, "errors": {}}
```

**Safety:** The script only removes worktrees whose branch is confirmed gone from `git branch --list`. It never removes a worktree for an existing branch and never force-removes a dirty worktree.

### 7. Build workspace file

Run the workspace build script. It reads the current Git worktree state directly (no stdin needed) and writes an existing root `.code-workspace` file or creates `<project>.code-workspace` with `main` plus all active worktrees:

```bash
bash [SMAQIT_SKILLS_DIR]/smaqit.utils.worktree/scripts/7_build_workspace.sh
```

The script is self-contained — it re-enumerates worktrees from `git worktree list` on every invocation, so the workspace file always reflects actual disk state regardless of earlier steps. Idempotent: same Git state always produces the same output.

If there are no active worktrees, the folders array contains only `main`.

### 8. Write settings (omitted — merged into Step 7)

The generated workspace excludes only build output (`bin/` and `obj/`). Do not add platform paths to workspace-level `files.exclude`: those settings apply to every workspace root and would hide installed content from `main` as well as task worktrees.

### 9. Resolve task lifecycle ownership

Run this operation from the primary checkout whenever `task.create`, `task.start`, or `task.complete` needs to determine whether a task owns Git resources or joins an active parent:

```bash
bash [SMAQIT_SKILLS_DIR]/smaqit.utils.worktree/scripts/9_resolve_task_lifecycle.sh \
  --task NNN --purpose start|complete
```

For child creation, validate the parent before writing the task file:

```bash
bash [SMAQIT_SKILLS_DIR]/smaqit.utils.worktree/scripts/9_resolve_task_lifecycle.sh \
  --parent NNN
```

The JSON result identifies `kind` (`owner` or `child`), parent task ID, branch, registered worktree, effective mode, and resolved task-file path. The script rejects invalid IDs, missing or inactive parents, self-references, nested parents, mode conflicts, and owner completion while any child is not `Completed`.

Task worktrees intentionally omit installed skill directories through sparse checkout. Do not run this script from a linked task worktree by path; run it from the primary checkout, then operate on the returned worktree path.

### 10. Report summary

Print a structured summary listing created worktrees, removed orphans, skipped entries, and any errors. Include the workspace file path and a reminder to reopen VS Code with `code <workspace-path>`.

## Additional Operations

### Migrate VS Code Chat Sessions

**Trigger:** `worktree.migrate-sessions` — one-time setup when switching from a single-folder workspace to the generated multi-root workspace. VS Code creates a new storage entry for the multi-root workspace, so existing chat sessions do not carry over automatically.

**Prerequisites:** VS Code must be closed, and `sqlite3`, jq, and Python 3 must be available. This operation must be explicitly invoked; never run it automatically from `task-start`, `task-complete`, or `worktree.sync`.

Run:

```bash
bash [SMAQIT_SKILLS_DIR]/smaqit.utils.worktree/scripts/8_migrate_sessions.sh
```

The script auto-detects the project name and workspace file from the Git repository. It migrates:

- `chatSessions/*.jsonl` — chat transcript files
- `chatEditingSessions/` — editing session directories
- `state.vscdb` keys — the chat session index and related workspace state

The script uses delta-copy and upsert behavior so repeated runs preserve sessions already present in the target workspace.

## Task Completion Cleanup

After `smaqit.task-complete` completes a lifecycle-owner task:

1. Use Step 4 to find the worktree registered for the task branch.
2. Remove it with `git worktree remove "<path>"`.
3. Delete the merged branch with `git branch -d "<branch>"`.
4. Run Step 7 to rebuild the workspace.

Do not force-remove a dirty worktree. Report the Git error and preserve the worktree and branch for user review.

For a child task, none of this cleanup runs. Child completion records criteria, findings, and status only; its parent performs the one eventual merge and cleanup after every declared child is `Completed`.

## Output

- `<project>.code-workspace`, or an existing root workspace file — multi-root VS Code workspace listing `main` + all active worktrees
- Worktree directories under `../<project>-wt-*/` (sibling to the main repo)
- Orphan worktrees removed (directory + Git worktree record)

## Requirements

- Bash
- Git
- jq 1.6 or newer
- `realpath --relative-to`
- VS Code multi-root workspace support
- Python 3 and sqlite3 for optional session migration

## Scope

**In scope:**
- Local branch scanning and worktree creation for all non-main branches
- Orphan worktree detection and removal (branch confirmed deleted from `git branch --list`)
- `.code-workspace` file generation and maintenance
- Integration with task branch creation and completion
- Parent-owned task lifecycle resolution for sequential child tasks

**Out of scope:**
- Creating or deleting Git branches (handled by `task-start`, `task-complete`, and release skills)
- Pushing/pulling worktrees to/from remotes
- Managing worktrees for remote-only branches (no local ref)
- Custom worktree directory layouts (slug scheme is fixed)
- Parallel independent editing in one shared parent worktree

## Examples

**Automatic task setup.** `task-start` creates `task/018-simple-refactor` and passes it to this skill. The skill creates `../<project>-wt-task-018-simple-refactor`, writes the root workspace with `main` plus the task worktree, and returns the worktree path.

**Child task setup.** `task-start` resolves Task 021's `Parent: 020` through Step 9. It returns Task 020's registered branch and worktree, so Task 021 updates its task state there without creating a child branch, worktree, or workspace entry.

**Interactive sync with branch selection.** User invokes `worktree.sync`. Agent gathers `git branch -vv` and `git branch -r`, builds a comparison table, and presents it. User selects `demo/user-identity` and `feat/hindsight`. Agent creates both worktrees, writes the root workspace with 3 folders (main + 2 worktrees), and reports the summary.

**Orphan cleanup after merge.** User invokes `worktree.sync` after `feat/hindsight` was merged and deleted. The branch no longer appears in `git branch --list`. Agent finds the matching worktree, removes it, updates the workspace file, and reports the removal.

## Gotchas

1. **Workspace file location.** Keep the `.code-workspace` file at the repo root.
2. **Path relativity.** The workspace file is at the repo root, so `"path": "."` points to the main repo and `"path": "../<slug>"` points to a sibling worktree.
3. **The main repo stays on `main`.** Never create a worktree for `main` — the primary repo directory IS the main worktree. Never modify the primary repo's branch during worktree creation.
4. **Slug uses `-` separators.** Branch names use `/` (e.g., `feat/hindsight`), but directory names use `-` to avoid nested directory issues.
5. **Orphan safety.** Double-check that the branch is confirmed gone from `git branch --list` before removing a worktree. Accidental removal causes data loss.
6. **Full workflow is idempotent.** Running the skill multiple times with the same branch selection produces the same result — existing worktrees are skipped, orphans are cleaned, and the workspace file is regenerated from current state. No duplicate worktrees or stale entries.
7. **Invocation behavior.** `task-start` supplies its branch automatically. Direct `worktree.sync` requires user selection before creating worktrees.
8. **The workspace file is Git-committed.** Commit the updated workspace with other changes to keep it versioned.
9. **VS Code must be reopened** with the root workspace file after it is created or updated for the new folder layout to appear.
10. **Session migration when switching workspaces.** Switching to a multi-root workspace creates a new VS Code storage entry. Invoke `worktree.migrate-sessions` explicitly if existing chat sessions should be copied.
11. **Generated mirrors and task state are excluded from task worktrees.** Sparse checkout excludes `.github/agents/`, `.github/skills/`, `.claude/agents/`, `.claude/commands/`, `.claude/skills/`, `.agents/skills/`, and `.codex/agents/` defensively, plus `.smaqit/tasks/` to keep task state single-sourced on primary. Under the default global install, a project has none of those agent/skill paths at all — they only exist for a project that ran `install --scope project`, this repository included, since it carries no committed dogfooding mirrors of its own. Project-owned paths such as `.github/workflows/` and the rest of `.smaqit/` remain available.
12. **Task branches modify canonical source, not generated mirrors.** Regenerate platform mirrors from canonical sources during the normal synchronization step.
13. **Existing unregistered directories are preserved.** Report the conflict for user review; do not remove the directory automatically.
14. **Parent tasks own Git resources.** A child task joins its active parent's registered branch/worktree and inherits its mode. Only a standalone or parent task can merge, remove a worktree, delete a branch, or rebuild the workspace.
15. **Run lifecycle resolution from primary.** Sparse task worktrees omit installed skill directories by design. Use the primary checkout's installed resolver and the JSON-returned worktree path.
16. **Steps 1–8 also require cwd = project root, not just Step 9.** Every script under `scripts/` resolves the repository root via a bare `git rev-parse --show-toplevel` (or bare `git worktree list --porcelain`) run against the invoking shell's current directory — never from the script's own install location. Under the default global install, scripts live entirely outside any project (`~/.claude/skills/...`, `~/.agents/skills/...`), so invoke every numbered step from the target project's root, exactly as Step 9 already requires of itself.

## Completion

- [ ] Branch selection supplied by task-start or confirmed by the user
- [ ] Prerequisites validated (Git, jq, Git repository)
- [ ] Selected branches enumerated
- [ ] Existing worktrees enumerated via `git worktree list --porcelain`
- [ ] Missing worktrees created for selected branches
- [ ] Orphan worktrees removed
- [ ] Root `.code-workspace` file written with all active worktrees
- [ ] Workspace settings applied (bin/obj excluded)
- [ ] Task lifecycle ownership resolved before any child creates or cleans Git resources
- [ ] Summary reported to user with reopen reminder

## Failure Handling

| Situation | Action |
|-----------|--------|
| `jq` not installed | Report that jq 1.6 or newer is required and stop |
| `git worktree add` fails for a branch | Log the specific error; continue with remaining branches |
| Sparse configuration fails after worktree creation | Disable sparse checkout in that worktree, report the error, and leave the full checkout usable |
| Worktree directory exists but is unregistered | Report the stale path and preserve it for user review |
| Workspace write fails | Report the error and intended workspace path |
| No local branches besides `main` | Report "No additional branches found — nothing to sync." Exit cleanly |
| User selects `none` or empty list | Report "No branches selected — nothing to sync." Exit cleanly |
| User selects a branch with no local ref | Inform the user that worktrees require a local branch; suggest `git checkout <branch>` first |
| Branch already checked out in another worktree | Skip and report the conflict. Do not duplicate |
| `git worktree remove` fails (dirty worktree) | Log the error and preserve the worktree for user review |
| VS Code is open during session migration | Ask the user to close it completely, then stop |
| VS Code workspace storage cannot be found | Report the searched path and stop without changing user data |
| sqlite3, jq, or Python 3 is unavailable | Report the missing migration dependency and stop |
