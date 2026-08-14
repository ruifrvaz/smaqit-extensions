---
name: smaqit.task-complete
description: Complete a task by opening a PR for owner-task code review (Phase 1), or by verifying that PR merged and cleaning up (Phase 2, re-entrant). Verifies acceptance criteria, records state in PLANNING.md, and refreshes the worktree workspace. A task's PR is also its release.
metadata:
  version: "0.11.0"
---

# Task Complete

Mark a task as done with the format: `task.complete [id]`

An **owner** (standalone or parent) task's completion is no longer a single-shot local merge — it is PR-gated in two phases, because PR review is asynchronous and cannot be waited out inside one invocation:

- **Phase 1** (first invocation, Status `In Progress`): commit implementation, compute this task's own release version, push a pending `CHANGELOG.md` entry to `main`, push the branch, and open a code-only PR. The PR is also this task's release — merging it fires the existing tag/GitHub-Release automation. Assisted mode stops here; Autonomous mode immediately self-merges and falls straight through to Phase 2 in the same invocation.
- **Phase 2** (a later, re-entrant invocation, Status `PR Open`): verify the PR actually merged on GitHub, then clean up only — no local merge, since GitHub already performed it.

A **child** task's completion is completely unaffected by any of this: it never opens a PR, never touches `main`, and remains pure task-file bookkeeping in the shared parent worktree, exactly as before.

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
3. Read the resolved task file (see [.smaqit/templates/task.template.md](.smaqit/templates/task.template.md) for the canonical task file structure) to review acceptance criteria, effective task mode, **and current Status**.

3a. **Phase gate (owner only).** A child always continues to Step 4 regardless of Status — it never has a phase of its own.
   - **Owner, Status `PR Open`, abandoning:** the user has asked to discontinue the task rather than land its PR, or the PR was already closed unmerged on GitHub → go to the **Abandon Path** (Step 23).
   - **Owner, Status `PR Open`, otherwise:** implementation, Findings, and acceptance criteria were already finalized when Phase 1 ran. Skip Steps 5-14 — re-verifying them against a worktree Phase 1 already committed and pushed away would be meaningless — and go directly to **Phase 2, Step 15**. Step 4's mode check still applies and is repeated as Step 15.
   - **Owner, Status `In Progress` (or a child of any status):** continue to Step 4 as normal; this is the task's first completion request.

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
8. **Child exit or owner Phase 1 entry:**
   - **Child:** commit its own implementation changes in the shared parent worktree first — implementation is deliberately left uncommitted until this step (see Step 9's note), so commit it here the same way:
     ```bash
     git -C "<parent-worktree>" add -A
     git -C "<parent-worktree>" commit -m "feat: implement task NNN — <summary>"
     ```
     Skip silently if the worktree has nothing uncommitted (e.g., re-running after a partial prior completion). Then update the task file status to "Completed" or "Abandoned" (with completion date) and move the entry in `PLANNING.md`, both on the primary checkout. Commit them together:
     ```bash
     git add .smaqit/tasks/NNN_*.md .smaqit/tasks/PLANNING.md
     git commit -m "chore: complete task NNN"
     ```
     Report completion and stop. A child never merges, pushes a branch, opens a PR, removes a worktree, deletes a branch, or rebuilds the workspace — the owner owns all of that, and the child's code ships only as part of whichever PR the owner eventually opens.
   - **Owner:** do not touch status or `PLANNING.md` yet — continue to Phase 1 below. Writing a new status before the PR actually opens would misrepresent state if something in between fails.

## Phase 1 — Commit, push, open PR (owner only, Status `In Progress`)

9. **Commit implementation on the task branch.**
   - Implementation changes are deliberately left **uncommitted** in the task worktree through the entire Assisted-mode review (`task-start` never commits them — see its Step 11). This is the first point in the lifecycle where they get committed, specifically so the user reviews a normal working-tree diff rather than already-committed history in the meantime.
   - Check the registered `worktree` for uncommitted changes (`git -C "<worktree>" status --porcelain`). If anything is uncommitted, stage and commit it there:
     ```bash
     git -C "<worktree>" add -A
     git -C "<worktree>" commit -m "feat: implement task NNN — <summary>"
     ```
     Skip silently if there's nothing to commit (e.g., re-running after a partial prior completion).

10. **Compute this task's release version.** Invoke `smaqit.release-analysis` in **Task mode**, passing the resolver's `branch` as `<task-branch>` — it fetches `origin/main` fresh, computes severity/version from `<boundary-sha>..<task-branch>`, and skips any version another concurrently-pending task has already claimed. Then invoke `smaqit.release-approval` using its Pattern 4 (auto-confirm on the Task-mode suggestion — no interactive version prompt; the human approval point for a task's release is the PR review itself, not a separate version confirmation). Store the approved version as `vX.Y.Z`.

11. **Push the branch and create the PR.** The PR must exist before the pending `CHANGELOG.md` entry can be written, because that entry names this PR's number.
    ```bash
    git -C "<worktree>" push -u origin "<branch-name>"
    gh pr create --base main --head "<branch-name>" \
      --title "Prepare release vX.Y.Z" \
      --body "<summary of the task, plus the Post-Merge Automation block below>"
    ```
    - The `Prepare release vX.Y.Z` title is **mandatory** — `post-merge-release.yml` matches on it and silently skips every job if it does not match.
    - Capture the PR number from `gh pr create`'s output URL (or `gh pr view --json number -q .number`) as `<PR#>`.
    - Then invoke `smaqit.release-git-pr` for its title-verification step only (its Step 4). It no longer stages or commits `CHANGELOG.md` — see that skill's "Invocation from `smaqit.task-complete`" section — so its Steps 1-2 are skipped; only the title enforcement and PR-description documentation apply.

12. **Push the pending `CHANGELOG.md` entry directly to `main`**, now that `<PR#>` is known. Use `smaqit.release-prepare-files`' Pending Entry Mode "Write a pending entry" operation, on the **primary checkout**, not the task worktree (resolve the primary path from `git worktree list --porcelain`). Commit and push using the identical bounded fetch-rebase-retry loop documented in `smaqit.task-start`'s Step 8 — collisions here are routine under concurrency, not exceptional. A rebase conflict is never auto-resolved; abort and STOP exactly as that pattern specifies.

13. **Promote the entry on the PR's own branch**, so merging the PR turns the pending annotation into a real released version section — without this step the PR carries no `CHANGELOG.md` change at all, `post-merge-release.yml`'s release-notes extraction finds no `## [X.Y.Z]` section, and the pending annotation would linger on `main` forever.
    ```bash
    git -C "<worktree>" fetch origin main
    git -C "<worktree>" rebase origin/main
    ```
    The rebase brings Step 12's pending entry into the branch. Then apply `smaqit.release-prepare-files`' Pending Entry Mode "Promote a single pending entry" operation for this task's own `(pending vX.Y.Z · PR #<PR#>)` annotation — leaving every other task's pending entry untouched — and commit and force-push the branch:
    ```bash
    git -C "<worktree>" add CHANGELOG.md
    git -C "<worktree>" commit -m "chore: promote task NNN changelog entry to vX.Y.Z"
    git -C "<worktree>" push --force-with-lease origin "<branch-name>"
    ```
    - `--force-with-lease` (never bare `--force`) is required because the rebase rewrote the branch's history; the lease aborts the push if anyone else moved the branch in the meantime.
    - If the rebase conflicts, STOP and report — never auto-resolve. The task stays `In Progress` with its PR open for the user to sort out.

14. **Update task state to `PR Open`** on the primary checkout: set `**Status:** PR Open` and add a `**PR:** #<PR#>` field to the task file, update `PLANNING.md`'s Active Tasks row to `PR Open`, then commit and push together using the same bounded retry loop:
    ```bash
    git add .smaqit/tasks/NNN_*.md .smaqit/tasks/PLANNING.md
    git commit -m "chore: task NNN — PR #<PR#> opened"
    ```

    If a persistent, cross-session memory/notes capability is available in this environment, use it to record task state (best-effort, same as Step 19's `"task state"` subject below):
    - `subject`: `"task state"`
    - `fact`: `"[NNN] [Title] — PR Open, PR #NNN (YYYY-MM-DD)"` (≤ 200 chars)
    - `citations`: path to the task file
    - `reason`: `"Ensures in-flight PR state is visible in any branch without reading files, supporting parallel agent workflows"`

    - **Autonomous mode:** immediately self-merge — no wait, no separate invocation, no human review gate:
      ```bash
      gh pr merge <PR#> --merge
      ```
      Use the explicit merge-commit strategy (`--merge`), matching this repo's existing convention — never `--squash` or `--rebase` here, so Step 21's `git branch -D` operates on predictable history. Then continue straight into Phase 2 (Step 15) in this same invocation — do not stop, do not wait.
    - **Assisted mode:** STOP here and report the PR link. Do not merge. Do not proceed to Phase 2. Rule 2's existing gate applies to Phase 2 exactly as it always applied to full completion: the agent must never self-initiate it, whether that means performing the merge itself or just re-checking an already-merged PR — both require an explicit user request first (via `/task.complete [id]` again, or a direct chat request), never a self-initiated follow-up.

## Phase 2 — Verify merge, clean up (owner only, Status `PR Open`; re-entrant)

15. **Re-check mode enforcement** — Step 4's gate applies independently to this phase, and a request that authorized Phase 1 never carries over:
    - **Assisted mode:** verify the user explicitly requested *this* phase (a fresh `/task.complete [id]`, or a direct chat request such as "I merged it, wrap it up"). If not, STOP and report that the PR is awaiting review — never self-initiate.
    - **Autonomous mode:** continue (this phase follows the self-merge in Step 14, or a later re-invocation).

16. **Verify the PR actually merged:**
    ```bash
    gh pr view <PR#> --json state,mergedAt
    ```
    - **Not merged:** report that the PR is still open and awaiting review; make no further changes; stop. Re-running `task.complete NNN` later re-enters here.
    - **Merged:** continue.

17. **Pull `main` on the primary checkout** to bring in the merge — resolve the primary path from `git worktree list --porcelain`, never assume cwd is primary:
    ```bash
    git -C "<primary>" checkout main
    git -C "<primary>" fetch origin main
    git -C "<primary>" pull --ff-only origin main
    ```
    If this does not fast-forward cleanly, STOP and report — never force, merge, or rebase here, matching `smaqit.session-finish`'s existing policy for `main`.

18. **Update task state to Completed** on the primary checkout: set the task file status to "Completed" (with completion date), clear the `**PR:**` field, and move the entry in `PLANNING.md`. Commit them together:
    ```bash
    git add .smaqit/tasks/NNN_*.md .smaqit/tasks/PLANNING.md
    git commit -m "chore: complete task NNN"
    ```
    Push immediately using the same bounded retry loop — this is metadata, not code, so it follows the same "never defer to session-finish" rule as `task-start`'s Step 8.

19. **If a persistent, cross-session memory/notes capability is available in this environment**, use it to record task state (best-effort — `PLANNING.md` and the task file remain the source of truth regardless):
    - `subject`: `"task state"`
    - `fact`: `"[NNN] [Title] — Completed (YYYY-MM-DD)"` (≤ 200 chars)
    - `citations`: path to the task file (e.g., `.smaqit/tasks/NNN_task_title.md`)
    - `reason`: `"Ensures final task state is visible in any branch without reading files, supporting parallel agent workflows"`

20. **Remove owner worktree** — remove the resolver's registered owner worktree before deleting the branch:
    - Invoke the task-completion cleanup path of `smaqit.utils.worktree`.
    - Execute its documented enumeration, removal, and workspace rebuild steps in order. Do not guess the worktree path from the branch name.
    - Never force-remove a dirty worktree.
    - If no registered worktree exists, skip removal silently.
    - Report the refreshed `.code-workspace` path.

21. **Delete the local branch only — never the remote branch.**
    ```bash
    git branch -D "<branch-name>"
    ```
    - Use `-D` (force), not `-d`. Step 16 already confirmed `MERGED` through GitHub's own PR API — the authoritative source of truth for "this branch's work is safely in `main`" — so `-d`'s local ancestry check is redundant and actively wrong for a squash-merged PR: GitHub creates a new commit SHA that is never an ancestor of the original branch tip, so `-d` would refuse deletion even though the PR genuinely merged. Step 13's rebase also rewrites the branch's SHAs, so even a plain merge-commit merge can leave the pre-rebase local ref unmerged by `-d`'s reckoning.
    - **Never run `git push origin --delete "<branch-name>"` or any remote deletion.** The remote branch is preserved indefinitely as an audit trail of every merged/released task branch.
    - If the local branch does not exist, skip silently.

22. **Task-awareness verification** (informational, non-blocking) — on the primary checkout, confirm the task file shows `Completed`, the change is committed (`git status --short -- .smaqit/tasks/` has nothing pending for this task), and `PLANNING.md` reflects the move. Surface a warning notice if any check fails; the task is already complete by this point, so this is a sanity check, not a gate.

## Abandon Path (owner, Status `PR Open`)

Entered from Step 3a when a task is abandoned while its PR is still open — the user decides to discontinue it rather than wait for merge, or the PR was closed unmerged on GitHub. Assisted mode requires an explicit user request to abandon, exactly as Step 15 requires one for Phase 2.

23. Close the PR if it is still open (only on explicit user confirmation of abandonment; never auto-close without instruction): `gh pr close <PR#>`.
24. Delete the pending `CHANGELOG.md` entry for this task directly on `main` (same primary-checkout, bounded-retry push as Step 12) — remove the whole bullet, do not leave an orphaned annotation. **Never reuse the version it claimed**; the next task's `release-analysis` run will naturally pick the next available number.
25. Update the task file to "Abandoned" (with reason), clear the `**PR:**` field, and move the `PLANNING.md` entry, commit and push (Step 18's pattern), then run Steps 20-21 (worktree removal, local-only branch force-delete) exactly as a normal completion would.

## Mode-Aware Enforcement

### Assisted Mode Tasks

**CRITICAL:** Assisted-mode tasks require an explicit user request before *each* phase — the agent must never self-initiate either one, and a request that opened Phase 1 does not also authorize Phase 2.

**Agent behavior:**
- ⛔ **Agent MUST NOT self-initiate `task-complete` for assisted tasks, in either phase** — finishing implementation and stopping is not itself a request to complete; neither is a PR simply becoming mergeable
- ✅ Agent implements the solution, then stops and hands back to the user
- ✅ Agent provides a completion summary
- ✅ Agent runs Phase 1 (commit, push, open PR) once the user explicitly requests completion — either by running `/task.complete [id]` themselves, or by asking for it directly in chat (e.g. "you can complete task 003," "go ahead and finish this up") — then STOPS after opening the PR
- ✅ Agent runs Phase 2 (verify merge, clean up) only on a later, separate explicit request — the user merging the PR on GitHub themselves and then saying so, or asking the agent to merge it and finish

**Example agent response (before any request):**
> "Implementation complete. This is an assisted-mode task requiring your approval. Please review the changes and run `/task.complete 003`, or just tell me to go ahead, when you're satisfied."

**Example agent response (after an explicit chat request, Phase 1):**
> User: "looks good, you can complete task 003"
> Agent: [invokes `task-complete 003` — the user explicitly requested it, even though they didn't type the slash command; commits, pushes, and opens PR #47, then stops]
> Agent: "Task 003's PR #47 is open for review: <link>. This task completes once it's merged — tell me when it lands, or ask me to merge it myself, and I'll finish up."

**Example agent response (after a later, separate request, Phase 2):**
> User: "I merged it, wrap up task 003"
> Agent: [invokes `task-complete 003` again — Status is `PR Open`, so this re-enters at Phase 2; confirms the merge via `gh pr view`, cleans up the worktree and local branch]

### Autonomous Mode Tasks

**Agent behavior:**
- ✅ Agent implements the solution
- ✅ Agent verifies ALL acceptance criteria
- ✅ Agent MAY invoke task-complete autonomously — this covers both phases in one continuous run: Phase 1 opens the PR, then the agent immediately self-merges it (`gh pr merge --merge`, no human wait) and falls straight through to Phase 2 in the same invocation
- ✅ Agent documents completion rationale

**Example agent response:**
> "All acceptance criteria verified. Task 005 completed autonomously: PR #52 opened, self-merged, and cleaned up."

## Requirements

- **CRITICAL:** All acceptance criteria MUST be verified as complete (for Completed tasks)
- **CRITICAL:** Check task mode before completing (read [references/RULES.md](references/RULES.md))
- **CRITICAL:** Findings MUST be written before status can change to `PR Open` — Phase 1 is the only phase that writes them; Phase 2 never re-verifies or rewrites them
- Do NOT mark as `PR Open` (Phase 1) if criteria remain unfinished
- Do NOT mark as `PR Open` if Findings categories are empty or `TBD`
- Do NOT run either phase of an assisted-mode task without a user invocation of that specific phase
- Do NOT mark as `Completed` (Phase 2) until `gh pr view` confirms the PR actually merged — never infer merge state from anything else
- Child completion ends after task bookkeeping; it must not perform any Git lifecycle operation, open a PR, or touch `main`.
- Owner completion requires every declared child to be `Completed`; Blocked or Abandoned children require explicit user resolution first.
- Use Abandoned (not Completed) for tasks being superseded or discontinued — including a `PR Open` task whose PR the user decides to close unmerged (see Abandon Path)
- Update both the individual task file AND the `.smaqit/tasks/PLANNING.md` file
- For Abandoned tasks, document the reason in `.smaqit/tasks/PLANNING.md`
- Never delete a remote task branch; only the local branch is ever removed, and only after `gh pr view` confirms `MERGED`

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

**Remember:** `.smaqit/tasks/PLANNING.md` lives exclusively on the primary checkout, contains three sections (Active, Completed, Abandoned), and must be updated there when completing or abandoning tasks — task worktrees never hold a copy.
