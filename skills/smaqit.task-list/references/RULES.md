# Task Workflow Rules

**Version:** 0.3.0  
**Purpose:** Enforce proper task completion gates and workflow modes

This document defines the rules for task workflow execution. These rules are loaded into context when working with tasks to ensure proper approval gates and autonomous/assisted mode behavior.

---

## Workflow Modes

### Assisted Mode (Default)

**Lifecycle:** Start → Implement → **STOP** → User Approves → User Completes

**Agent Behavior:**
- ✅ Agent reads and understands task requirements
- ✅ Agent implements the solution
- ✅ Agent tests and verifies locally
- ⛔ **Agent MUST NOT invoke `/task.complete`**
- ✅ Agent hands back to user with completion summary

**User Behavior:**
- User reviews implementation
- User tests the changes
- User invokes `/task.complete [id]` when satisfied
- User can request changes if needed

**When to Use:**
- Complex features requiring human judgment
- User-facing functionality changes
- Security-sensitive modifications
- Changes requiring domain expertise validation
- Default mode for all tasks unless explicitly specified otherwise

### Autonomous Mode

**Lifecycle:** Start → Implement → Verify → Complete

**Agent Behavior:**
- ✅ Agent reads and understands task requirements
- ✅ Agent implements the solution
- ✅ Agent verifies ALL acceptance criteria are met
- ✅ Agent invokes `/task.complete [id]` autonomously
- ✅ Agent documents completion rationale

**When to Use:**
- CI/CD pipeline tasks
- Batch operations
- Well-defined refactoring with clear criteria
- Automated workflows
- Non-critical updates with objective success metrics

---

## Enforcement Rules

### Rule 1: Mode Detection

**Location:** Task file frontmatter

```yaml
mode: Assisted | Autonomous
```

- Set by `task-start` skill during task initiation
- Defaults to "Assisted" if not specified
- Cannot be changed mid-task (restart task to change mode)

### Rule 2: Completion Gate (Assisted Mode)

**CRITICAL ENFORCEMENT POINT**

For an owner (standalone or parent) task, `task-complete` runs in two phases, and this gate applies to **each one independently** — an explicit request that triggered Phase 1 does not also authorize Phase 2:

- **Phase 1** (Status `In Progress`): commits implementation, computes the task's release version, pushes a pending `CHANGELOG.md` entry, pushes the branch, and opens a PR. Then STOPS.
- **Phase 2** (Status `PR Open`, re-entrant): verifies the PR merged on GitHub and cleans up. No local merge — GitHub already performed it.

When task mode is "Assisted":
- Agent MUST read task file before attempting either phase
- Agent MUST check mode metadata
- Agent MUST NOT self-initiate `task-complete` for either phase — each one always requires its own explicit user request first, whether via the literal `/task.complete [id]` command or a direct chat request ("you can complete this," "go ahead and finish it", "I merged it, wrap it up")
- Agent MUST explain that completion is user-gated when no such request has been made yet
- Agent MUST provide clear summary for user review after Phase 1 (the PR link) and after Phase 2 (cleanup confirmation)

A child task has no phases and no PR — this rule applies to it exactly as before (a single explicit request gates its one bookkeeping-only completion).

**Example Response (before any request):**
> "Implementation complete. This is an assisted-mode task requiring your approval. Please review the changes and run `/task.complete 003`, or tell me to go ahead, when ready."

**Example Response (after Phase 1 opens the PR):**
> "PR #47 opened: <link>. This task completes once it merges — tell me when it lands, or ask me to merge it myself."

### Rule 3: Self-Completion (Autonomous Mode)

When task mode is "Autonomous", for an owner task both phases run in one continuous invocation with no human wait in between:
- Agent MUST verify ALL acceptance criteria before Phase 1
- Agent MUST document verification results
- Agent MAY invoke `task-complete [id]` — Phase 1 opens the PR, the agent immediately self-merges it (`gh pr merge --merge`), and Phase 2 runs right after in the same invocation
- Agent SHOULD explain completion rationale, including the PR number and that it was self-merged

**Example Response:**
> "All acceptance criteria verified:
> ✓ Criteria 1 met
> ✓ Criteria 2 met
> Task completed autonomously: PR #52 opened, self-merged, cleaned up."

### Rule  4: Status Transitions

Valid status flows:
```
Not Started → In Progress → Completed                          (child; or an owner with no committed code changes)
Not Started → In Progress → PR Open → Completed                 (owner: Phase 1 opens the PR, Phase 2 confirms merge)
Not Started → In Progress → Blocked → In Progress → Completed
Not Started → In Progress → Abandoned
Not Started → In Progress → PR Open → Abandoned                 (PR closed unmerged — see Rule 6)
```

`PR Open` is owner-only and records a `pr: NNN` key alongside `status`. A child task never enters it — it never opens a PR.

Invalid flows:
```
Not Started → Completed  (must use task-start first)
In Progress → Not Started  (cannot regress, abandon instead)
PR Open → In Progress  (cannot regress once the PR exists; abandon and start a new task instead)
```

---

### Rule 4.5: Parent-Child Lifecycle Ownership

- A task without a `parent` key owns its normal branch/worktree lifecycle.
- A child starts only when its parent is `In Progress` in a registered worktree; it inherits the parent mode and uses that branch/worktree.
- A child never creates a branch or worktree, and never performs merge, cleanup, branch deletion, workspace rebuild, or PR — it never enters Phase 1/Phase 2 at all. Its code ships only as part of whichever PR the parent eventually opens.
- A parent may complete only when every declared child is `Completed`. Blocked and Abandoned children require explicit user resolution.
- Parent relationships are single-level in this version. Reject self-referential, nested, and cyclic declarations.

## Implementation Checklist

For skills that interact with tasks:

### task-start
- [ ] Parse mode from arguments (`--autonomous`, `--assisted`)
- [ ] Default to assisted if not specified
- [ ] Store mode in task file metadata
- [ ] Update task status to "In Progress"
- [ ] Load RULES.md into context
- [ ] Push the "In Progress" commit to `origin/main` immediately (bounded fetch-rebase-retry), not deferred to session-finish

### task-complete
- [ ] Read task file to get mode and current Status (`In Progress` vs `PR Open` selects Phase 1 vs Phase 2)
- [ ] If assisted mode: check if user invoked *this specific phase* (via instruction context)
- [ ] If autonomous mode: verify all criteria, then run both phases in one invocation with a self-merge in between
- [ ] Phase 1, in this order: commit implementation → compute release version → push branch and `gh pr create` (title `Prepare release vX.Y.Z`) → push the `(pending vX.Y.Z · PR #NNN)` CHANGELOG entry to `main` (the PR must exist first; the annotation names it) → rebase the branch and promote that entry into a `## [X.Y.Z]` section on the branch → set status to "PR Open" with its PR number
- [ ] Phase 2: re-check the mode gate for this phase, confirm `gh pr view` reports `MERGED`, pull main, update status to "Completed", clean up (worktree + local-only branch delete)
- [ ] Move from Active to Completed in PLANNING.md

### task-list
- [ ] Load RULES.md into context
- [ ] Display task mode indicators in output, including `PR Open` with its PR number when applicable
- [ ] Remind agent of workflow constraints

---

### Rule 6: PR-Gated Owner Completion

- Main's code is always merged via PR, never a direct local `git merge` — an owner task's branch and its release travel together as one PR (Phase 1 opens it; the PR title follows the same `Prepare release vX.Y.Z` convention the release skills already use, since that PR is also this task's release).
- The PR must be created **before** its pending `CHANGELOG.md` entry is written to `main`, since the `(pending vX.Y.Z · PR #NNN)` annotation names the PR. The PR branch must then carry its own commit promoting that entry into a real `## [X.Y.Z]` section — without it the merged PR contributes no changelog change, the release-notes extraction finds nothing, and the pending annotation never clears from `main`.
- `smaqit.task-start` and `smaqit.task-complete`'s pre-PR metadata commits push to `origin/main` immediately (bounded fetch-rebase-retry on collision) — never deferred to `session-finish`, so a parallel session sees current state without waiting for this session to end.
- Phase 2 confirms a merge exclusively via `gh pr view <PR#> --json state,mergedAt` — never inferred from local branch state, ancestry, or anything else.
- Local branch cleanup force-deletes (`git branch -D`) once Phase 2 confirms `MERGED`, regardless of merge strategy (handles squash merges, which git's own `-d` ancestry check cannot recognize as merged). The remote branch is **never** deleted — it is retained indefinitely as an audit trail of every merged/released task.

---

### Rule 5: Implementation Step Idempotency

**Every implementation step must be safe to run multiple times.**

Before executing any mutating command (writing files, installing packages, modifying system config, firewall rules, running installers, etc.):

1. **Check first:** Run a read or scan command to determine current state
2. **Proceed only if needed:** Skip the step entirely if the desired state is already in place
3. **Prefer idempotent forms:** Use flags like `--if-exists`, `--force`, or `--no-clobber` where available

**Examples:**

| Step | Non-idempotent risk | Safe approach |
|------|--------------------|--------------|
| Firewall rule | `ufw allow 18789` may duplicate | Check `ufw status` first; add only if rule is missing |
| Config file patch | Overwriting may lose existing keys | Read file first; patch only missing keys |
| Installer script | Re-running may reinstall/reset | Check if binary exists first; skip if present |
| `apt install` | Already idempotent | Run directly |
| `ollama pull` | Already idempotent | Run directly |

**When a step is not naturally idempotent:** Run a read/scan command first, report current state, and proceed with the mutation only if needed.

---

## Common Pitfalls

### ❌ Pitfall 1: Auto-completing Assisted Tasks

**Problem:** Agent completes assisted-mode tasks without user approval

**Solution:** Always read task mode before attempting completion. Check RULES.md enforcement.

### ❌ Pitfall 2: Forgetting Mode Declaration

**Problem:** Task mode not set during task-start

**Solution:** task-start MUST always set mode metadata, defaulting to "Assisted"

### ❌ Pitfall 3: Ambiguous Mode Detection

**Problem:** Unclear whether task is assisted or autonomous

**Solution:** Explicitly check task file metadata. Absence of mode = Assisted (default)

### ❌ Pitfall 4: Treating a `PR Open` Re-Invocation as a Fresh Completion

**Problem:** Agent re-runs Steps 4-13 (findings, criteria, commit, PR-open) against a task whose Status is already `PR Open` — findings were already written and the branch was already pushed away; there is nothing left in the worktree to re-verify.

**Solution:** Always branch on Status immediately after reading the task file (Step 3a). `PR Open` always means Phase 2 — verify the merge and clean up — never Phase 1 again.

---

## Quick Reference

| Mode | AI Implements | AI Opens PR | AI Merges PR | AI Cleans Up | User Approves |
|------|---------------|--------------|---------------|---------------|---------------|
| **Assisted** | ✅ Yes | ✅ Yes, on request (Phase 1) | ⛔ **NO** — human merges, or explicitly asks the agent to | ✅ Yes, on a separate later request (Phase 2) | ✅ Required for each phase |
| **Autonomous** | ✅ Yes | ✅ Yes | ✅ Yes, immediately (`gh pr merge --merge`) | ✅ Yes, same invocation | ❌ Not needed |

**Default Mode:** Assisted

**Override:** Use `task.start [id] --autonomous` explicitly

A task's PR is also its release — merging it (by whichever route) triggers the existing tag/GitHub-Release automation, regardless of mode.
