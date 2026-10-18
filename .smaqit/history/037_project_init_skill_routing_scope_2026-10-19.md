# Project-Init Skill Routing Scope

**Date:** 2026-10-19
**Session focus:** Narrowed `smaqit.project-init`'s skill description so it no longer competes with smaqit's `smaqit.project-new` for "start a project" requests, and shipped it as v2.4.1.
**Tasks completed:** 044 — smaqit.project-init: Description Overlaps With smaqit.project-new (shipped v2.4.1, PR #144)
**Tasks referenced:** 028 — Benchmark Glossary Skill Invocation (unchanged)

## Actions Taken

- Ran `smaqit.session-start`.
  - Found session 036's history file and research-map edit uncommitted, and its memory entries stale.
  - Before anything could be committed, session 036's own `session-finish` committed and pushed them (`b0458a9`) and updated memory, so nothing was left to do.
  - Assessed task 044 against the code. "start" appeared only in the `description` frontmatter line. Nothing in the skill body, its references, the README, or any other source file overlapped or copied the description.
- Started task 044 (Assisted).
  - Created the branch from fetched `origin/main` with `--no-track`, plus its worktree.
  - The research map had no task 044 block, so ran a task-only `project-research` refresh. It added Claude Code, Agent Skills spec, Copilot, and Codex skill-docs rows, all 200; Codex's URL redirected and was recorded at its final address.
  - Triage was skipped (`Mode: Skip`).
- Implemented the change in the task worktree.
  - Rewrote the `description` and bumped the skill to v0.7.1.
  - Added a `### Changed` bullet under `[Unreleased]`.
- The owner revised the wording twice before release:
  - Removed the "(smaqit.project-new)" name from the closing clause.
  - Asked why the description was quoted. The proposed text contained `instruction files: synchronize`, and `: ` inside an unquoted YAML value fails to parse. The owner then reworded it to `instruction files by synchronizing` and dropped the quotes.
- Ran `task.complete 044` Phase 1.
  - Folded the owner's edit into the unpushed implementation commit.
  - Re-ran `make test` (23 suites) and the installer smoke test; both passed.
  - Release analysis found boundary `v2.4.0`, no claimed versions, and only already-pushed bookkeeping commits on `origin/main` since the boundary. It rated the change PATCH, giving v2.4.1.
  - The release-workflow preflight passed. Opened PR #144 `Prepare release v2.4.1`, then wrote and plain-pushed the `## [2.4.1]` section.
- After the owner merged PR #144, ran Phase 2.
  - Confirmed `MERGED` and merged `origin/main` into local `main`.
  - Marked the task Completed, removed the worktree, force-deleted the local branch, and rebuilt the workspace.
  - Watched `post-merge-release.yml` succeed. The v2.4.1 Release has 5 binary assets and the correct changelog section.

## Problems Solved

- **Ambiguous skill routing:** "start a new smaqit project" matched both `smaqit.project-init` (instruction files only) and `smaqit.project-new` (the full pipeline), because both are installed into the same global skill directories and `project-init` listed "start" as a trigger.
- **YAML-breaking description:** the task's proposed wording would have been invalid as an unquoted frontmatter value. It was caught before release and resolved by rewording rather than quoting.

## Decisions Made

- **No cross-skill names in descriptions:** the owner removed `smaqit.project-new` from the description to keep skill descriptions free of references to each other. It now ends with a generic exclusion, "Not for building and shipping a new project". Acceptance criterion 1 was annotated as amended rather than checked as written.
- **Unquoted descriptions:** reword to avoid `: ` instead of quoting, matching the project's other skill descriptions.
- **v2.4.1 (PATCH):** a wording-only change with no behavior change.

## Files Modified

- `skills/smaqit.project-init/SKILL.md` — v0.7.1; description scoped to instruction files (359 characters)
- `CHANGELOG.md` — `## [2.4.1] - 2026-10-19` (via PR #144)
- `.smaqit/tasks/044_*.md`, `.smaqit/tasks/PLANNING.md` — started, PR Open, completed; Findings written
- `.smaqit/references/project-research.md` — task 044 block
- `.smaqit/compendium.md` — new Skill Authoring entry on description frontmatter
- `smaqit-extensions.code-workspace` — worktree added, then removed (net unchanged)

## Next Steps

- Task 028 (glossary Bench) is the only remaining task and is Not Started.

## Session Metrics

- **Duration:** Single continuous session
- **Tasks completed:** 1 (044)
- **Releases shipped:** 1 — v2.4.1 (PATCH, PR #144), with 5 binary assets
- **Files changed in the release:** 2 (13 insertions, 2 deletions)
- **Tests:** `make test` passing (23 suites); installer smoke test passing
