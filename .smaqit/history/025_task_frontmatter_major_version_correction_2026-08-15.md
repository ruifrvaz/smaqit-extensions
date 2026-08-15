# Task Frontmatter Migration and Major Version Correction

**Date:** 2026-08-15
**Session focus:** Converting task file metadata from bold-markdown to YAML frontmatter and retiring `.smaqit/templates/` (task 030), then — after post-merge review found a silent data-corrupting defect in the shipped result — landing the fix and recording the format break as a major version (task 032). Two releases: v1.18.0 (defective, superseded) and v2.0.0.
**Tasks completed:** 030 — Task File YAML Frontmatter Migration; 032 — Reject Legacy Task Files and Signal the Breaking Change as v2.0.0
**Tasks created:** 031 — Fix Release-Analysis Boundary Detection for PR-Gated Releases (not started; being addressed in a parallel session)
**Tasks referenced:** 002, 007, 010, 028 (untouched, still Not Started)

## Actions Taken

- Started with `smaqit.session-start`. User reported a suspected problem with template scaffolding and `task.create`, asking for confirmation that `task.create` points at the skill's bundled asset template and that `.smaqit/templates` installs correctly without a stale task template.
- **Confirmed the first half, disproved the second.** `task-create` correctly loads `skills/smaqit.task-create/assets/TASK_TEMPLATE.md`, and `generate-targets.py`'s `copytree` carries `assets/` into both the shared and Claude staging trees. But `.smaqit/templates/task.template.md` — the file the installer actually ships into every consumer project — had been stale since task 011 split the canonical template into the skill asset, missing Design Decisions, Implementation Steps, Known Issues Triage, Findings, and Files to Create/Modify. Worse, `task-start` and `task-complete` both linked to that stale file as "the canonical task file structure."
- Ran `smaqit.task-plan` (Mode A) with two parallel Explore agents: a complete inventory of every read/write of the seven affected header fields, and a survey of the repo's existing YAML frontmatter conventions. Discovery established that only `9_resolve_task_lifecycle.sh`'s three `sed`-based extractors do real machine parsing, that no consumer depends on field order, and that the repo's only project-data frontmatter precedent (`project-research.md`) deliberately excludes dates.
- User directed two scope changes mid-plan: **no backward compatibility of any kind**, and — after asking me to explain where `## Issue Triage Context`'s `Mode: Auto | Skip` is actually used — **do not drop that field** once I showed it is live, parsed by `task-context.sh`, consumed by `triage-issues`, and was exercised by task 029 the prior session.
- Created and started task 030; implemented all five phases (schema and canonical template, four consuming skills plus three synced `RULES.md` copies, resolver rewrite, full `.smaqit/templates/` retirement across `installer/main.go`/`installer/Makefile`/root `Makefile`/smoke test/README, and a mandatory 30-file corpus backfill on the primary checkout).
- Completed task 030 Phase 1 → PR #126, "Prepare release v1.18.0". While computing the version, discovered that `release-analysis`'s boundary search cannot find the boundary for any PR-gated release, because the `Prepare release vX.Y.Z` string now exists only as a PR title, never a commit message. Overrode the boundary manually per user direction and filed task 031.
- **Post-merge review (Opus) found three defects in the shipped work**, the most serious being that "no legacy support" had been implemented as *doesn't parse* rather than *rejects*: a legacy-format child task resolved as `kind: owner`, `parent: null`, defaulted mode, and **exit 0**, which would hand it its own branch, worktree, and release PR. Also found that only `task_parent()` stripped quotes, and that the compendium carried stale format claims.
- Authored the fix with regression tests (each verified to fail with the guard reverted) — but the push failed 403 on an auth lapse. The user merged PR #126 before it landed, so **v1.18.0 shipped without the fix**.
- Confirmed the fix was absent from the release (`require_frontmatter` appears 0 times in `git show v1.18.0:...`), preserved the orphaned commit on a `preserve/` branch before any cleanup could delete it, then closed out task 030's Phase 2 properly.
- Created and completed task 032 to land the fix and record the version correction. Released v2.0.0 via PR #127, verified end-to-end against the published tag rather than against `main`.

## Problems Solved

- **Stale shipped template.** `.smaqit/templates/task.template.md` was retired entirely rather than re-synced, eliminating the two-file drift that caused the original report; the skill-bundled asset is now the single canonical template, matching the precedent already set for `AGENTS.template.md`.
- **Silent child→owner misresolution (found in review, shipped in v1.18.0, fixed in v2.0.0).** `require_frontmatter()` now gates all three resolver read paths. The failure profile had been inconsistent — `complete` and `--parent` errored while `start`, the entry point, returned a wrong answer with exit 0.
- **Quoted YAML values silently unmatched.** The schema mandates quotes on dates and parent IDs while every writer emits unquoted status/mode, and only `task_parent()` stripped them; extraction is now unified through `_frontmatter_value()`.
- **False published release notes.** The cherry-picked fix had rewritten v1.18.0's already-published changelog entry to claim rejection behavior that release does not have; the original text was restored verbatim from the tag and the entry marked superseded.
- **Mislabeled severity.** A breaking data-format change shipped as MINOR. Since published releases are immutable, v2.0.0 was cut as the next release to carry both the guard and the honest major-version boundary.
- **Pre-existing noise.** The child-scan loop no longer warns about `PLANNING.md`, which lives in that directory by design.

## Decisions Made

- **Flat frontmatter**, matching `project-research.md`'s project-data precedent rather than skill/agent `metadata:` nesting; all seven fields including dates, an explicit scoped exception to that precedent.
- **Enum text preserved verbatim** so no exact-string comparison site needed touching; `parent` quoted zero-padded, `pr` bare int, inapplicable keys omitted entirely.
- **`## Issue Triage Context`'s `Mode` left untouched** — confirmed a separate, live mechanism. Moving the header `mode` into frontmatter removed the only real ambiguity between the two same-named fields.
- **Reject rather than tolerate legacy files.** "No legacy support" means refusing the old format, not misreading it; rejection tightens the boundary the user asked for.
- **Runtime error messages made version-free** — version strings baked into error output age badly, and would already have been wrong here since the format shipped in one release and its guard in another.
- **Documentation kept historically accurate** rather than blanket-replacing v1.18.0 → v2.0.0: the format genuinely shipped in v1.18.0; only the guard is v2.0.0.
- **One rebase conflict resolved rather than aborted**, against the skill's default rule — justified because it was self-caused (the `[2.0.0]` section authored before the pending entry was pushed), involved no second party's work, and its resolution is exactly the documented promote-a-pending-entry operation. Flagged explicitly to the user.

## Files Modified

- `skills/smaqit.task-create/assets/TASK_TEMPLATE.md` — frontmatter schema added; now the sole canonical task template
- `skills/smaqit.task-create/SKILL.md`, `smaqit.task-start/SKILL.md`, `smaqit.task-complete/SKILL.md`, `smaqit.task-list/SKILL.md` — write/read frontmatter; template links repointed; versions bumped
- `skills/smaqit.task-{start,complete,list}/references/RULES.md` — field syntax updated, three copies kept byte-identical
- `skills/smaqit.utils.worktree/scripts/9_resolve_task_lifecycle.sh` — `_frontmatter_block()`, `require_frontmatter()`, `_frontmatter_value()`; `task_branch_name()` de-anchored from line 1; `PLANNING.md` skipped in child scan
- `skills/smaqit.utils.worktree/SKILL.md` — version bump
- `.smaqit/templates/task.template.md`, `.smaqit/templates/PLANNING-template.md` — deleted (directory retired)
- `installer/templates/` — deleted, including a committed stale `copilot-instructions.template.md` predating the `AGENTS.template.md` migration
- `installer/main.go` — templates embed/deploy logic removed; help text and console messaging updated
- `installer/Makefile`, root `Makefile`, `scripts/smoke-test-installer.sh`, `README.md` — templates references removed; smoke test now asserts the directory is never scaffolded
- `tests/skills/test-parent-task-lifecycle.sh` — frontmatter fixtures plus legacy-rejection and quoted-value regression coverage
- `tests/skills/test-task-complete-pr-lifecycle.sh`, `tests/skills/test-triage-issues.sh` — frontmatter fixtures; single-template assertions
- `.smaqit/tasks/*.md` — all 30 existing task files backfilled (header block only; bodies byte-identical, audited)
- `.smaqit/tasks/PLANNING.md` — notes updated to `pr:`; task 030/031/032 lifecycle
- `.smaqit/tasks/030_*.md`, `.smaqit/tasks/031_*.md`, `.smaqit/tasks/032_*.md` — created
- `.smaqit/compendium.md` — three stale claims corrected; new task-format entry
- `.smaqit/references/project-research.md` — task 030 block
- `CHANGELOG.md` — `[1.18.0]` restored verbatim and marked superseded; `[2.0.0]` added with migration guidance
- `smaqit-extensions.code-workspace` — regenerated across worktree create/remove cycles

## Next Steps

- Task 031 (release-analysis boundary detection) is **being addressed in a parallel session**. It blocked correct automated versioning twice this session; both releases had their version set manually.
- Consider gating `task-complete` on its own unlanded pushes — the exact failure that let v1.18.0 ship defective (a reported-but-unresolved push block did not prevent the merge). Recorded in task 032's findings; no task filed.
- Global install is still on the defective v1.18.0 — run `smaqit-extensions update` to pick up v2.0.0.
- Tasks 002, 007, 010, 028 remain Not Started, untouched this session.

## Session Metrics

- **Duration:** Full session, single continuous thread
- **Tasks completed:** 2 (030, 032); 1 created and handed off (031)
- **Releases shipped:** 2 — v1.18.0 (MINOR, defective, superseded) and v2.0.0 (MAJOR, corrective)
- **Task files migrated:** 30 (bodies verified byte-identical; 28 pre-existing tracked files audited, 2 benign false positives)
- **Defects found in post-merge review:** 3, one of them silent and data-corrupting
- **Regression tests added:** 2, each verified to fail with the fix reverted
- **Root cause of the escape:** every existing test suite exercised only new-format task files, so the explicit no-legacy-support contract was never itself tested
