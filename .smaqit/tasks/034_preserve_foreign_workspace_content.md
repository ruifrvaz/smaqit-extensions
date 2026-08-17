---
status: PR Open
mode: Assisted
pr: 130
created: "2026-08-18"
started: "2026-08-18"
---

# Preserve Foreign Content When Regenerating the `.code-workspace` File

## Description

`skills/smaqit.utils.worktree/scripts/7_build_workspace.sh` — invoked by both `smaqit.task-start` (after creating a worktree) and `smaqit.task-complete` Phase 2 cleanup (after removing one) — fully overwrites the root `.code-workspace` file on every run via a from-scratch `jq -n '{folders: $folders, settings: {...}}'` rebuild. It never reads the pre-existing file, so any `folders` entry that isn't `main` or a currently-registered git worktree (e.g. a manually-added sibling repo folder such as `local-llm`), and any `settings` key beyond the hardcoded `files.exclude` block, is silently discarded on every run.

Reproduced live in the planning session for this task: a concurrent `task-complete` cleanup run for tasks 031/033 dropped both worktree folder entries in one commit (`7dd05b5`), demonstrating the same full-overwrite mechanism that would just as easily drop an unrelated manually-added folder.

Being tracked in git on `main` at all is a deliberate, documented choice (`SKILL.md` Gotcha #8: "Commit the updated workspace with other changes to keep it versioned") so any session pulling `main` sees the current set of active task worktrees — that part is not in question. Only the destructive full-overwrite behavior needs fixing.

Separately, `skills/smaqit.utils.worktree/scripts/5_create_worktrees.sh`'s sparse-checkout exclusion list excludes `.smaqit/tasks/` from task worktrees "to keep task state single-sourced on primary" but does not exclude the `.code-workspace` file itself, even though Gotcha #16 already requires every worktree script (including Step 7) to run with cwd = project root (primary checkout), never from inside a linked worktree. The workspace file therefore sits, unexcluded and serving no purpose, inside every task worktree's checkout.

## Issue Triage Context

**Mode:** Skip
**Technologies:** None
**Platforms/Environments:** None
**Features/Integrations:** None
**Versions/Constraints:** None

## Design Decisions

- **Keep the workspace file git-tracked on `main`**; fix only the destructive overwrite, not the tracking model — Gotcha #8's shared-visibility rationale (any session pulling `main` sees the current set of active task worktrees) remains valid and documented.
- **Foreign folders are appended after the managed set** on every regeneration (minor reordering if a foreign entry was originally listed before `main`) — accepted as a reasonable trade-off against the complexity of positional preservation.
- **No new Makefile target** — this extends the existing `test-worktree-layout` target (which already exercises both `5_create_worktrees.sh` and `7_build_workspace.sh`) rather than adding a new test file.
- **Already-created worktrees predating this fix** keep a stale local copy of the workspace file; not remediated automatically (would require `git sparse-checkout reapply` per worktree) — low-severity, self-resolves as worktrees cycle through normal task completion.

## Implementation Steps

1. Rewrite `skills/smaqit.utils.worktree/scripts/7_build_workspace.sh`: before writing, read the existing file's `folders` (if any) and partition off "foreign" entries — anything whose `path` isn't `.` and doesn't start with `../<project>-wt-` (the fixed slug prefix from Step 3's naming rule). Recompute the managed `folders` (main + current `git worktree list --porcelain`) exactly as today, then output `managed + foreign`. Deep-merge `settings` (`existing.settings * {"files.exclude": {...}}`) instead of overwriting it wholesale, so any extra key survives. First-run behavior (no existing file) is unchanged — `existing` defaults to `{}`, `folders`/`settings` default to `[]`/`{}`.
2. Add `'!/*.code-workspace'` to the `sparse-checkout set --no-cone` pattern list in `skills/smaqit.utils.worktree/scripts/5_create_worktrees.sh`, alongside the existing `'!.smaqit/tasks/'` line (same "primary-only, never in a worktree" rationale already documented there). Use the leading-slash-anchored, glob form (not a fixed literal filename) since the workspace file's basename is derived from the repository directory name and differs per consumer project.
3. Extend `tests/skills/test-worktree-layout.sh` (do not create a new test file): add assertions that (a) a manually-inserted foreign folder entry and a foreign `settings` key both survive a worktree add/remove cycle through `7_build_workspace.sh`, and (b) `<project>.code-workspace` does not appear inside a newly created worktree's checkout (via the file's existing `assert_missing` helper, matching how it already checks other excluded paths). Verify the new assertions fail against the pre-fix scripts before confirming they pass against the fix.
4. Update `skills/smaqit.utils.worktree/SKILL.md`: Step 7's description (document the preserve/merge behavior, not just "idempotent regeneration"), Gotcha #8 (still git-committed, now merge-based rather than destructive), Gotcha #11 (add the workspace file to the excluded-from-worktrees list, alongside `.smaqit/tasks/`). Bump `metadata.version` `1.4.0` → `1.5.0`.
5. Run `make test-worktree-layout`, then full `make test` and `make smoke-test`; confirm `tests/skills/test-parent-task-lifecycle.sh` and `tests/skills/test-task-complete-pr-lifecycle.sh` still pass unmodified — their fixtures have no foreign folders, so their exact-equality assertions (e.g. `.folders | length == 2`) are unaffected by the merge logic.

## Known Issues Triage
**Triaged:** 2026-08-18
**Result:** Skip — explicitly marked in task's Issue Triage Context (`Mode: Skip`). Internal bash/jq worktree-tooling fix with no third-party dependency surface; no search performed.

## Acceptance Criteria

- [x] `7_build_workspace.sh` preserves any pre-existing `folders` entry whose path is not `.` or a `../<project>-wt-*` worktree slug, across both a worktree-add and worktree-remove regeneration
- [x] `7_build_workspace.sh` preserves any pre-existing `settings` key beyond the managed `files.exclude` block
- [x] `5_create_worktrees.sh`'s sparse-checkout exclusion list excludes the root `*.code-workspace` file from every newly created task worktree
- [x] New regression coverage in `tests/skills/test-worktree-layout.sh` fails against the pre-fix scripts and passes after the fix
- [x] Existing worktree/workspace tests continue passing unmodified (`test-parent-task-lifecycle.sh`, `test-task-complete-pr-lifecycle.sh`)
- [x] `make test` and `make smoke-test` pass

## Findings

**Implementation approach:**
- Rewrote `7_build_workspace.sh` to read the existing workspace file first, split its `folders` into a managed set (`.` and `../<project>-wt-*` worktree slugs, fully regenerated from `git worktree list`) and a foreign set (everything else, preserved as-is), then output `managed + foreign`. `settings` is deep-merged (`existing.settings * {"files.exclude": {...}}`) instead of overwritten.
- Added `'!/*.code-workspace'` to `5_create_worktrees.sh`'s sparse-checkout pattern list, matching the existing `.smaqit/tasks/` exclusion rationale.
- Extended `tests/skills/test-worktree-layout.sh` in place (no new Makefile target): the fixture repo now commits a placeholder `.code-workspace` before any worktree exists, so sparse-exclusion regressions are actually observable; a new block injects a foreign folder + setting, removes the worktree, rebuilds, and asserts both survived while the removed worktree's own entry dropped.
- Updated `SKILL.md` Step 7, Gotcha #8, and Gotcha #11 to document the merge/preserve behavior and the new exclusion; bumped `metadata.version` `1.4.0` → `1.5.0`.

**Decisions made:**
- Verified the new test assertions fail against the pre-fix scripts and pass against the fix, in two isolated checks — reverting only `7_build_workspace.sh` (folder/setting preservation fails) and reverting only `5_create_worktrees.sh` (sparse-exclusion fails) — confirming each half of the fix is independently covered, not just the combination.
- Kept the exact scope from planning: no repositioning of foreign folders relative to managed ones beyond "managed first, foreign after," and no remediation of already-created worktrees predating the fix (both explicitly accepted trade-offs in Design Decisions).

**Blockers encountered:**
- A 403 on `git push origin main` during task-start's metadata push, resolved by the user switching their local PAT; no workaround attempted per this repo's standing instruction.

**Follow-up identified:**
- None — the task's own Notes already flagged the low-severity, self-resolving nature of pre-existing worktrees keeping a stale workspace-file copy.

## Files to Create / Modify

| File | Action |
|------|--------|
| `skills/smaqit.utils.worktree/scripts/7_build_workspace.sh` | Modify — read-then-merge instead of overwrite |
| `skills/smaqit.utils.worktree/scripts/5_create_worktrees.sh` | Modify — add `.code-workspace` sparse-checkout exclusion |
| `skills/smaqit.utils.worktree/SKILL.md` | Modify — Step 7, Gotcha #8, Gotcha #11; version `1.4.0` → `1.5.0` |
| `tests/skills/test-worktree-layout.sh` | Modify — add foreign-content-survives and sparse-exclusion assertions |

## Notes

Filed directly out of this session's assessment of a user-reported bug: a manually-added sibling repo folder (`local-llm`) disappeared from a shared `.code-workspace` file after a `task-start`/`task-complete` cycle. Root-caused to `7_build_workspace.sh`'s full-overwrite `jq -n` rebuild, live-reproduced when a concurrent session's `task-complete` cleanup for tasks 031/033 dropped both worktree entries in commit `7dd05b5`.

Child tasks inherit their active parent's branch, worktree, and workflow mode. Only a standalone or parent task owns Git lifecycle cleanup.
