---
name: smaqit.task-complete
description: Mark a task as completed by updating a task's status. Verify its acceptance criteria, record state in PLANNING.md, merge its task branch, and refresh the worktree workspace.
metadata:
  version: "0.9.0"
---

# Task Complete

Mark a task as done with the format: `task.complete [id]`

## Steps

1. **Load workflow rules** by reading [references/RULES.md](references/RULES.md)
2. Resolve lifecycle ownership from the primary checkout before reading or changing task state:
   ```bash
   bash [SMAQIT_SKILLS_DIR]/smaqit.utils.worktree/scripts/9_resolve_task_lifecycle.sh \
     --task NNN --purpose complete
   ```
   - Capture `kind`, `parent`, `branch`, `worktree`, `mode`, and `task_file` from the JSON output.
   - The resolver reads parent/child state in the registered owner worktree. It blocks owner completion unless every declared child is `Completed`.
   - A child resolves to its parent's branch/worktree and must never receive a separate Git lifecycle.
3. Read the resolved task file (see [.smaqit/templates/task.template.md](.smaqit/templates/task.template.md) for the canonical task file structure) to review acceptance criteria **and effective task mode**
4. **Check task mode enforcement:**
   - **Assisted mode:** Verify this is user-invoked (not AI self-completion)
   - **Autonomous mode:** AI may self-complete after verification
5. **Write Findings (mandatory, before status updates):**
   - Confirm `## Findings` section exists in the task file
   - Populate all four categories with brief bullets:
     - `**Implementation approach:**`
     - `**Decisions made:**`
     - `**Blockers encountered:**`
     - `**Follow-up identified:**`
   - Block completion if any category is empty or still uses placeholders (`TBD`)
   - Enforce findings quality: bullets only, no URLs, concise and useful statements
6. **Verify all criteria are met** - Do NOT complete if any criteria remain unfinished
7. Check off completed acceptance criteria (`- [x]`)
8. Update the resolved task file status to "Completed" or "Abandoned" and add completion date
9. Move the task from Active to the appropriate destination in the resolved worktree's `.smaqit/tasks/PLANNING.md`:
   - **Completed** if successfully finished
   - **Abandoned** if superseded, no longer relevant, or incorrect approach (include reason)
10. **If a persistent, cross-session memory/notes capability is available in this environment**, use it to record task state (best-effort — `PLANNING.md` and the task file remain the source of truth regardless):
   - `subject`: `"task state"`
   - `fact`: `"[NNN] [Title] — [Completed|Abandoned] (YYYY-MM-DD)"` (≤ 200 chars)
   - `citations`: path to the task file (e.g., `.smaqit/tasks/NNN_task_title.md`)
   - `reason`: `"Ensures final task state is visible in any branch without reading files, supporting parallel agent workflows"`
11. **Child exit or owner merge:**
    - **Child:** Report completion and stop. Do not merge, remove a worktree, delete a branch, or rebuild the workspace. The parent owns all of those operations.
    - **Owner:** merge the resolver's `branch` into `main` after checking that its registered `worktree` is clean. Resolve the primary repository path from `git worktree list --porcelain`; do not assume the current directory is primary.
    - If the branch exists, merge it from the primary repository:
      ```bash
      git checkout main
      git merge "<branch-name>" --no-ff -m "merge: task NNN — <summary>"
      ```
    - If merge conflicts occur, STOP and report conflicts to the user for manual resolution.
    - If the branch does not exist, skip silently (already merged or task had no branch).

12. **Remove owner worktree** — remove the resolver's registered owner worktree before deleting the branch:
    - Invoke the task-completion cleanup path of `smaqit.utils.worktree`.
    - Execute its documented enumeration, removal, and workspace rebuild steps in order. Do not guess the worktree path from the branch name.
    - Never force-remove a dirty worktree.
    - If no registered worktree exists, skip removal silently.
    - Report the refreshed `.code-workspace` path.

13. **Delete owner branch** — the branch is now merged and its worktree is gone; remove it locally:
    - Safely delete the merged local branch:
      ```bash
      git branch -d "<branch-name>"
      ```
    - Use `-d` only; Git must refuse deletion if the branch is not fully merged.
    - If the branch does not exist, skip silently.

## Mode-Aware Enforcement

### Assisted Mode Tasks

**CRITICAL:** Assisted-mode tasks require user approval before completion.

**Agent behavior:**
- ⛔ **Agent MUST NOT invoke task-complete for assisted tasks**
- ✅ Agent implements the solution
- ✅ Agent provides completion summary
- ✅ Agent instructs user to run `/task.complete [id]` when ready

**Example agent response:**
> "Implementation complete. This is an assisted-mode task requiring your approval. Please review the changes and run `/task.complete 003` when satisfied."

### Autonomous Mode Tasks

**Agent behavior:**
- ✅ Agent implements the solution
- ✅ Agent verifies ALL acceptance criteria
- ✅ Agent MAY invoke task-complete autonomously
- ✅ Agent documents completion rationale

**Example agent response:**
> "All acceptance criteria verified. Task 005 completed autonomously."

## Requirements

- **CRITICAL:** All acceptance criteria MUST be verified as complete (for Completed tasks)
- **CRITICAL:** Check task mode before completing (read [references/RULES.md](references/RULES.md))
- **CRITICAL:** Findings MUST be written before status can change to Completed
- Do NOT mark as Completed if criteria remain unfinished
- Do NOT mark as Completed if Findings categories are empty or `TBD`
- Do NOT complete assisted-mode tasks without user invocation
- Child completion ends after task bookkeeping; it must not perform any Git lifecycle operation.
- Owner completion requires every declared child to be `Completed`; Blocked or Abandoned children require explicit user resolution first.
- Use Abandoned (not Completed) for tasks being superseded or discontinued
- Update both the individual task file AND the `.smaqit/tasks/PLANNING.md` file
- For Abandoned tasks, document the reason in `.smaqit/tasks/PLANNING.md`

## Findings Format Enforcement

All findings categories are mandatory and must always be present:

- `**Implementation approach:**`
- `**Decisions made:**`
- `**Blockers encountered:**`
- `**Follow-up identified:**`

Each category must have bullet points and may use `None` when nothing applies.

## Task Mode Detection

Check the task file for mode metadata:

```markdown
**Mode:** Assisted | Autonomous
```

- If mode is missing, assume **Assisted** (default)
- Mode is set by `task-start` skill

## Central Planning File

**Remember:** `.smaqit/tasks/PLANNING.md` contains three sections (Active, Completed, Abandoned) and must be updated when completing or abandoning tasks.
