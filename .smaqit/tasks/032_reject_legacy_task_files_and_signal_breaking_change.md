---
status: PR Open
pr: 127
mode: Assisted
created: "2026-08-15"
started: "2026-08-15"
---

# Reject Legacy Task Files and Signal the Breaking Change as v2.0.0

## Description

v1.18.0 shipped the task-file YAML frontmatter migration (task 030) with two defects found in post-merge review, and mislabeled as MINOR a change that is genuinely breaking. The fix commit was authored before the merge but never reached the PR — an authentication failure blocked the push, and PR #126 merged without it. This task lands that fix and corrects the version signal.

**Defect 1 (silent, serious).** "No legacy support" was implemented as *doesn't parse it* rather than *rejects it*. Every extractor in `9_resolve_task_lifecycle.sh` returns empty for a frontmatter-less file, and empty is indistinguishable from "legitimately absent" — so a pre-v1.18.0 **child** task resolves as `kind: owner`, `parent: null`, with a silently defaulted mode, and **exits 0**. `task-start` would hand it its own branch and worktree, and `task-complete` its own release PR. The failure profile was also inconsistent: `--purpose complete` and `--parent` errored out, but `--purpose start` — the entry point — returned a wrong answer.

**Defect 2.** Only `task_parent()` stripped surrounding quotes, so `status: "Completed"` — equally valid YAML, and consistent with the schema's own quoting of dates and parent IDs — silently failed to match the unquoted form every writer emits.

**Version correction.** v1.18.0 invalidates existing task files with no migration path; it should not have been MINOR. Since a published release cannot be retagged, v2.0.0 is where the honest major-version boundary lands — carrying the guard that makes the break explicit and safe.

## Issue Triage Context

**Mode:** Skip
**Technologies:** Bash, git
**Platforms/Environments:** Local filesystem
**Features/Integrations:** smaqit.utils.worktree lifecycle resolver, task file format
**Versions/Constraints:** Fix already authored and preserved as commit 670444d on branch `preserve/task-030-review-fixes`; must ship as v2.0.0

## Design Decisions

- **Reject, don't fall back.** `require_frontmatter()` gates all three read paths and fails with a message naming the file and the required migration. This tightens the no-legacy-support boundary rather than softening it — the original intent was to refuse the old format, and misreading it was never the intent.
- **Child-scan warns and skips** rather than aborting, matching how that loop already handles malformed siblings, so one stale sibling cannot block an unrelated owner's completion.
- **Unify extraction through `_frontmatter_value()`**, stripping optional surrounding quotes for every key, so quoted and unquoted YAML parse identically.
- **v2.0.0, not v1.18.1.** The fix alone would be a PATCH, but v1.18.0's breaking format change was mislabeled MINOR and cannot be retagged. Shipping this as the major boundary is the only remaining way to signal the break honestly.
- **Reuse the authored commit** (`670444d`) rather than reimplementing — it is already reviewed, tested, and verified to fail-without-fix.

## Implementation Steps

1. Create the task branch and cherry-pick `670444d` from `preserve/task-030-review-fixes`.
2. Verify the cherry-pick applies cleanly against post-merge `main` and that `make test` and `make -C installer smoke-test` both pass.
3. Update the in-code and in-doc version references from `v1.18.0` to `v2.0.0` where they name the migration boundary (resolver error message, `require_frontmatter` comment, compendium entries, test comments).
4. Add the `CHANGELOG.md` entry for v2.0.0 covering both fixes and stating explicitly that v1.18.0 was the same breaking format change released under a MINOR version.
5. Complete via the normal PR-gated flow; confirm the release tags and publishes.
6. Delete the `preserve/task-030-review-fixes` branch once the fix is merged.

## Known Issues Triage

Triage skipped — `**Mode:** Skip`. The change is confined to this repository's own Bash lifecycle resolver and documentation, with no third-party dependency surface.

## Acceptance Criteria

- [ ] A pre-v1.18.0 task file is rejected on all three resolver paths (`--purpose start`, `--purpose complete`, `--parent`) with a message naming the file and required migration
- [ ] An old-format child task never resolves as `kind: owner`; `--purpose start` emits no resolution and exits non-zero
- [ ] Quoted and unquoted frontmatter values parse identically for `status`, `mode`, and `parent`
- [ ] Regression tests cover both defects and fail when the fix is reverted
- [ ] Compendium and in-code version references name v2.0.0 as the migration boundary
- [ ] `CHANGELOG.md` documents v2.0.0 and states that v1.18.0 carried the same breaking change under a MINOR version
- [ ] `make test` and `make smoke-test` pass
- [ ] Released as v2.0.0; `preserve/task-030-review-fixes` deleted afterward

## Findings

[Populated by smaqit.task-complete. Do not fill in manually before task is complete.]

**Implementation approach:**
- TBD

**Decisions made:**
- TBD

**Blockers encountered:**
- TBD

**Follow-up identified:**
- TBD

## Files to Create / Modify

| File | Action |
|------|--------|
| `skills/smaqit.utils.worktree/scripts/9_resolve_task_lifecycle.sh` | Modify — `require_frontmatter()` guard, `_frontmatter_value()` quote stripping |
| `tests/skills/test-parent-task-lifecycle.sh` | Modify — regression coverage for both defects |
| `.smaqit/compendium.md` | Modify — correct stale format claims; document the guard |
| `CHANGELOG.md` | Modify — v2.0.0 entry |

## Notes

The fix is already authored, reviewed, and verified — commit `670444d`, preserved on branch `preserve/task-030-review-fixes`. Both regression tests were confirmed to fail with the guard neutered and pass with it restored.

Root cause of the escape: every existing test suite exercised only new-format task files, so the explicit no-legacy-support contract was never itself tested. The added tests close that gap. Separately, the push failure that kept the fix out of PR #126 is a reminder that a reported-but-unresolved push block should gate a merge — the PR merged while its fix was still sitting unpushed locally.
