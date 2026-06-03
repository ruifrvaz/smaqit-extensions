---
name: smaqit.task-refresh
description: Use when a session is ending and you need to identify work committed during the session that has no corresponding smaqit task. Scans session commits and modified files, cross-references against PLANNING.md active tasks, and surfaces candidates for retroactive task creation. Invoke as part of or immediately after smaqit.session-finish to prevent committed fixes, features, or infrastructure changes from going untracked.
metadata:
  version: "1.0.0"
---

# smaqit.task-refresh

## Steps

1. **Identify session commits.** Run:
   ```
   git log --oneline --no-merges --since="<session-start-date>" --format="%H %s"
   ```
   Use today's date if session start time is unknown.

2. **Map modified files per commit.** For each commit SHA from step 1, run:
   ```
   git show --name-only --format="" <sha>
   ```

3. **Load active tasks.** Read `.smaqit/tasks/PLANNING.md` — extract all tasks that were active or completed during this session (In Progress and Done tables).

4. **Identify unattached work.** Cross-reference commit messages and file paths against active tasks. Flag commits or file groups that:
   - Touch files not covered by any active task
   - Carry semantic prefixes `fix:`, `feat:`, `deploy:`, `infra:` but no corresponding task
   - Were described in the session history as resolved but never opened as a task

5. **Surface candidates.** For each flagged item, present:
   - Proposed retroactive task title
   - Task type (`fix` / `feat` / `infra`)
   - Affected files
   - Proposed acceptance criteria
   - Prompt: "Should I create a retroactive task for this work?"

6. **On user confirmation.** For each approved candidate, invoke `smaqit.task-create` then immediately invoke `smaqit.task-complete` — the work is already done. Do not leave retroactive tasks in an open state.

## Output

- Unattached work candidates listed with proposed task details
- Retroactive tasks created and immediately closed (if user confirms)
- PLANNING.md updated with completed tasks in the Done table

## Scope

- Does NOT create tasks for every commit — only substantive work (fixes, features, infrastructure changes) with no task coverage.
- Does NOT create tasks for documentation-only commits, version bumps, or reformatting.
- Does NOT auto-create tasks without explicit user confirmation.

## Examples

**Trigger:** Session ends; commits include `fix(deploy): set demo_mode default to true` and `fix(provision): add TF_VAR_github_token` with no active tasks covering either.

**Output:** Two candidates surfaced. User confirms both. Tasks created retroactively with status Completed. PLANNING.md updated.

## Gotchas

- `git log --since` is date-based. If session commits span midnight, use a broader date range or specify the exact session start time.
- Retroactive tasks must be created AND completed in the same operation — never leave them open.
- Focus on semantic prefixes `fix:`, `feat:`, `deploy:`, `infra:` and meaningful changes to source, deployment, or infrastructure files. Commits like `chore: update README` legitimately need no task.
- If `smaqit.task-create` or `smaqit.task-complete` fails, report the failure with context — do not block session-finish from completing.

## Completion

- [ ] Session commits identified
- [ ] Modified files per commit mapped
- [ ] PLANNING.md active tasks loaded
- [ ] Unattached work candidates identified (or "No candidates found" reported)
- [ ] User consulted for each candidate
- [ ] Approved retroactive tasks created and immediately completed

## Failure Handling

| Situation | Action |
|-----------|--------|
| No commits in today's session | Skip scan; report "No commits in this session" |
| PLANNING.md does not exist | Skip task cross-reference; flag all substantial commits as candidates |
| User declines all candidates | Report "No retroactive tasks created" and finish |
| `task-create` or `task-complete` fails | Report failure with context; do not block session-finish |
