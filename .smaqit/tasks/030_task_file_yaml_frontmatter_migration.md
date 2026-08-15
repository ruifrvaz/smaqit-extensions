---
status: Completed
mode: Assisted
created: "2026-08-15"
started: "2026-08-15"
completed: "2026-08-15"
---

# Task File YAML Frontmatter Migration

## Description

Convert task file header fields (`Status`, `Mode`, `Parent`, `PR`, `Created`, `Started`, `Completed`) from bespoke `**Field:**` bold-markdown lines to YAML frontmatter, matching this repo's own skill/agent frontmatter house style. `skills/smaqit.task-create/assets/TASK_TEMPLATE.md` becomes the sole canonical task template — it already has the correct, current section structure (Design Decisions, Implementation Steps, Known Issues Triage, Findings, Files to Create/Modify) that `.smaqit/templates/task.template.md` has lacked since task 011; the retiring file's field set gets reconciled into it. `.smaqit/templates/` is removed from the installer pipeline entirely — both `task.template.md` and the already-dead `PLANNING-template.md` — since `PLANNING.md` itself is generated from an unrelated hardcoded Go constant, not this directory.

This is a **fix-forward, no-legacy-support change**: the worktree lifecycle resolver script only understands frontmatter afterward — no fallback parsing path, no migration tooling shipped for consumer projects. This repo's own existing task corpus is fully backfilled as a mandatory implementation step. `## Issue Triage Context`'s own `Mode: Auto | Skip` field (a distinct, currently-working mechanism — used by task 029 the prior session to skip GitHub issue triage) is explicitly untouched.

## Issue Triage Context

**Mode:** Auto
**Technologies:** Bash/sed/awk, YAML frontmatter, Go (installer), Python (generate-targets.py)
**Platforms/Environments:** Claude Code, GitHub Copilot, Codex (shared skill source); local filesystem
**Features/Integrations:** Task lifecycle skills (task-create, task-start, task-complete, task-list), worktree lifecycle resolver, installer template scaffolding
**Versions/Constraints:** Must preserve existing Status/Mode enum value text for downstream exact-match comparisons; three-copy RULES.md sync must be maintained; ships as a breaking change with no legacy support

## Design Decisions

- **Flat frontmatter, not nested:** Keys (`status`, `mode`, `parent`, `pr`, `created`, `started`, `completed`) are flat, matching `.smaqit/references/project-research.md`'s project-data precedent — not skill/agent's `metadata:`-nesting convention, which is specific to build/version info.
- **All 7 fields move to frontmatter, including the 3 dates:** A scoped, deliberate exception to `project-research.md`'s own choice to keep dates in the body — made because the instruction covered the whole header block, not a partial set.
- **Enum value text preserved exactly:** `Not Started`, `In Progress`, `PR Open`, `Completed`, `Abandoned`, `Blocked`, `Assisted`, `Autonomous` keep their current text — only the outer `**Field:**` → `field:` syntax changes, avoiding touches to every exact-string comparison site (`find_active_task`, `canonical_mode`, RULES.md prose, tests).
- **Value typing:** `parent` is a quoted zero-padded string (`"020"`) to avoid YAML's leading-zero-as-octal parsing footgun; `pr` is a bare int (matches `gh pr view <number>`/`--json` output). Keys are omitted entirely when not yet applicable — no `null`, no HTML-comment placeholders.
- **`## Issue Triage Context`'s own `Mode: Auto|Skip` field is explicitly untouched:** different section, different subsystem (`task-context.sh`'s strict order-enforced parser, consumed by `smaqit.utils.triage-issues`), confirmed live and working — task 029 used `Mode: Skip` the prior session to skip GitHub issue triage for a pure git-workflow change. Moving the header `Mode` out of the body actually removes today's only naming collision between the two same-named fields.
- **No backwards compatibility:** no fallback parser in the resolver script, no migration tooling shipped for consumer projects with existing old-format task files. This repo's own task corpus is fully backfilled as a mandatory step, not optional cleanup. Ships as a documented breaking change in `CHANGELOG.md`.

## Implementation Steps

**Phase A — Schema & canonical template**
1. Define the frontmatter schema: flat keys `status`, `mode`, `parent`, `pr`, `created`, `started`, `completed`. Enum text unchanged. `parent` quoted zero-padded string (`"020"`); `pr` bare int. Keys omitted when not yet applicable.
2. Update `skills/smaqit.task-create/assets/TASK_TEMPLATE.md`: add the frontmatter block (field order: status, parent, pr, mode, created, started, completed); keep all existing body sections (Description, Issue Triage Context, Design Decisions, Implementation Steps, Known Issues Triage, Acceptance Criteria, Findings, Files to Create/Modify, Notes) unchanged.

**Phase B — Consuming skills**
3. `skills/smaqit.task-create/SKILL.md` — write `status:`/`created:`/`parent:` as frontmatter instead of bold-markdown lines.
4. `skills/smaqit.task-start/SKILL.md` — write `mode:`/`started:` as frontmatter; repoint the "Task File Format" reference link from `.smaqit/templates/task.template.md` to `smaqit.task-create`'s `assets/TASK_TEMPLATE.md` (relative sibling-skill link — all skills install as flat siblings under one root per platform).
5. `skills/smaqit.task-complete/SKILL.md` — write `status:`/`pr:`/`completed:` as frontmatter at all three transition points (PR Open / Completed / Abandoned); same template-link fix; update the "Task Mode Detection" literal example.
6. `skills/smaqit.task-list/SKILL.md` + all three byte-identical `references/RULES.md` copies (`task-list`, `task-start`, `task-complete` — kept in sync by an existing test) — update literal field-syntax mentions to frontmatter form.
7. Audit-only pass, no expected changes: `task-plan`, `task-refresh`, `session-start`, `session-finish` — confirmed none parse these 7 fields programmatically; verify no stray literal-syntax documentation needs updating.

**Phase C — Resolver script (no legacy support)**
8. Rewrite `task_status()`, `task_mode()`, `task_parent()` in `skills/smaqit.utils.worktree/scripts/9_resolve_task_lifecycle.sh` (lines 109-129) to extract from the YAML frontmatter block only (lines strictly between the first two `---` delimiters), via a shared helper, instead of match-anywhere-in-body `sed`. This structurally removes the current `Mode`-vs-`Mode` ordering hazard between the header field and `## Issue Triage Context`'s own `Mode` field.
9. Fix `task_branch_name()` (line 133): replace the hardcoded `sed -n '1s/^# //p'` (line-1-anchored) with a pattern that finds the first line starting with `# ` regardless of position, since the H1 title now sits after the frontmatter block instead of on line 1.
10. No fallback path — old-format task files are not understood by the new resolver. This is a deliberate, documented breaking change with no legacy support.

**Phase D — Retire `.smaqit/templates`**
11. Delete `.smaqit/templates/task.template.md` and `.smaqit/templates/PLANNING-template.md` (confirmed dead — unreferenced anywhere, not even the source of the `planningTemplate` Go constant); delete the now-empty `.smaqit/templates/` directory.
12. `installer/main.go` — remove the `//go:embed templates/*` directive and `templateFiles` var; remove the `templatesDir` creation and `fs.WalkDir(templateFiles, ...)` block from both `installProject()` and `scaffoldSmaqit()`; adjust `checkAndReInit`/`checkAndReInitWithBinary` console messaging (no more "re-scaffolding project templates" step) and the `--help` text line `.smaqit/templates/    - Canonical templates`.
13. `installer/Makefile` — remove the `mkdir -p templates` and `cp -r ../.smaqit/templates/* templates/` lines from the `prepare` target.
14. `scripts/smoke-test-installer.sh` — remove the `assert_tree_matches ... "smaqit templates"` line (98).
15. `README.md` — remove "templates" from the `.smaqit/` bullet (line 94) and rephrase the self-update description (line 136) to drop "re-scaffolds project templates."

**Phase E — Mandatory backfill + tests**
16. One-time conversion pass over every existing `.smaqit/tasks/NNN_*.md` file in this repo (all statuses), converting the bold-markdown header block to the new frontmatter schema while leaving every other section byte-identical. Mandatory, not optional — there is no fallback parsing path to fall back on.
17. Update `.smaqit/tasks/PLANNING.md`'s Notes section (documents the `**PR:** #NNN` field name) to reference the new `pr:` key.
18. Rewrite `tests/skills/test-parent-task-lifecycle.sh`'s fixture builder, `sed -i` mutations, and literal `assert_contains` checks to construct and check frontmatter-formatted task files instead of bold-markdown.
19. Rewrite `tests/skills/test-task-complete-pr-lifecycle.sh` the same way; also update it to check only the single canonical template (no more dual-template comparison).
20. Bump `metadata.version` on every modified skill; run `make sync && make -C installer prepare && make smoke-test` and the full `make test` suite; add a `CHANGELOG.md` entry noting this is a breaking format change with no migration path.

## Known Issues Triage
**Triaged:** 2026-08-15
**Tools searched:** golang/go
**Result:** Clear

### Blocking Issues
- None

### Advisory Issues
- None

### Historical (Closed)
- None

### Unresolvable Tools
- Bash — helper resolved an unrelated community repo (`dylanaraps/pure-bash-bible`, a cheatsheet, not an issue tracker); Bash itself has no GitHub-hosted issue tracker (upstream is GNU Savannah)
- GNU sed — helper resolved an unrelated tutorial repo (`learnbyexample/learn_gnused`); no GitHub-hosted issue tracker exists upstream
- GNU awk — helper resolved an unrelated tutorial repo (`learnbyexample/learn_gnuawk`); no GitHub-hosted issue tracker exists upstream
- YAML frontmatter — helper resolved a specific Go YAML library (`go-yaml/yaml`) rather than the YAML spec itself; not a genuine dependency of this task
- Python (generate-targets.py) — helper resolved an unrelated repo (`TheAlgorithms/Python`, algorithm examples, not CPython); this task does not modify `generate-targets.py`, so Python is not materially implicated

### Omitted Tools
- None

### Search Warnings
- None

## Acceptance Criteria

- [x] `skills/smaqit.task-create/assets/TASK_TEMPLATE.md` carries the full frontmatter schema and is the only canonical task template in the repo
- [x] `task-create`, `task-start`, `task-complete` write frontmatter fields instead of bold-markdown lines; all three `RULES.md` copies stay byte-identical and reflect the new syntax
- [x] `9_resolve_task_lifecycle.sh`'s `task_status`/`task_mode`/`task_parent`/`task_branch_name` correctly parse frontmatter-formatted task files, with no legacy/fallback parsing path
- [x] `## Issue Triage Context`'s `Mode: Auto|Skip` field and `task-context.sh` are unchanged
- [x] `.smaqit/templates/` no longer exists in this repo and is no longer scaffolded/installed into any consumer project
- [x] Every existing task file in `.smaqit/tasks/` is backfilled to the new frontmatter format
- [x] `make test` and `make smoke-test` pass

## Findings

**Implementation approach:**
- Implemented Phases A–D directly in the task worktree (schema, canonical template, four consuming skills + three synced `RULES.md` copies, resolver script rewrite with a new `_frontmatter_block()` helper, full `.smaqit/templates/` retirement across `installer/main.go`/`installer/Makefile`/root `Makefile`/`scripts/smoke-test-installer.sh`/`README.md`), then rewrote both affected hermetic test suites for frontmatter fixtures.
- Phase E's mandatory corpus backfill (30 task files) ran on the primary checkout via a one-time Python conversion script, since `.smaqit/tasks/` is sparse-excluded from every task worktree — the only path this content can ever be written through. Dry-run reviewed before applying; committed locally, left unpushed for review rather than auto-pushed like `task-start`'s routine single-field metadata commits.
- Verified end-to-end against real production data (not just hermetic fixtures): ran the rewritten resolver script directly against several real backfilled task files, confirming correct status/mode/branch-name resolution.

**Decisions made:**
- Frontmatter is flat (no `metadata:` nesting), matching `.smaqit/references/project-research.md`'s project-data precedent rather than skill/agent source-file convention.
- All 7 fields, including the 3 dates, moved to frontmatter — a scoped, explicit exception to `project-research.md`'s own choice to exclude dates, made because the instruction covered the whole header block.
- No backward-compatibility fallback in the resolver, confirmed by the user mid-session; `## Issue Triage Context`'s own `Mode: Auto|Skip` field stays untouched, also confirmed by the user after reviewing its live usage (task 029).
- `installer/templates/copilot-instructions.template.md` — discovered mid-implementation to be a genuinely *committed* stale leftover (not just local build staleness) from before the `AGENTS.template.md` migration — deleted along with the rest of the retired `installer/templates/` directory.

**Post-PR review pass (Opus):**
- Caught a serious defect in the shipped Phase 1 code: "no legacy support" had been implemented as *doesn't parse* rather than *rejects*, and the failure profile was inconsistent — `--purpose complete` and `--parent` errored, but `--purpose start` returned a wrong answer with exit 0. An old-format **child** resolved as `kind: owner`, `parent: null`, mode silently defaulted, which would have handed it its own branch, worktree, and eventually its own release PR. Root cause: every extractor returns empty for a frontmatter-less file, and empty is indistinguishable from "legitimately absent". Fixed with `require_frontmatter()` gating all three read paths; child-scan warns and skips instead.
- Second defect: only `task_parent()` stripped surrounding quotes, so `status: "Completed"` — equally valid YAML, and consistent with the schema's own quoting of dates and parent IDs — silently failed to match. Extraction unified through `_frontmatter_value()`.
- Both regressions now covered in `test-parent-task-lifecycle.sh`, and each test was confirmed to fail with the fix reverted. The gap that let these ship: every existing suite exercised only new-format files, so the explicit no-legacy contract was never itself tested.
- Compendium corrected (3 stale claims) and given an entry documenting the new format and its hard-fail behavior.
- Incidental: child-scan no longer warns on `PLANNING.md`.

**Blockers encountered:**
- First push attempt (task-start's metadata commit) failed 3/3 with a 403 permission error from the configured GitHub PAT, not a routine collision — stopped and reported per the bounded-retry loop's own "STOP on a non-conflicting repeated rejection" rule; resolved once the user fixed their token and asked to retry.
- Two test files not in the original Files-to-Modify list broke on the first `make test` run after the resolver rewrite: `tests/skills/test-triage-issues.sh` (fixture-checked the now-deleted `.smaqit/templates/task.template.md`) and root `Makefile`'s `clean` target (dead `installer/templates/` reference). Both fixed; full suite green afterward.

**Follow-up identified:**
- None blocking. `pr` frontmatter as a bare int (vs. a `"#NNN"` string) and keeping the frontmatter-fallback question closed indefinitely were both flagged as low-stakes, reversible choices during planning — no action needed unless the team wants to revisit either later.

## Files to Create / Modify

| File | Action |
|------|--------|
| `skills/smaqit.task-create/assets/TASK_TEMPLATE.md` | Modify — add frontmatter schema |
| `skills/smaqit.task-create/SKILL.md` | Modify — write frontmatter fields |
| `skills/smaqit.task-start/SKILL.md` | Modify — write frontmatter fields; repoint template link |
| `skills/smaqit.task-complete/SKILL.md` | Modify — write frontmatter fields; repoint template link |
| `skills/smaqit.task-list/SKILL.md` | Modify — update literal field-syntax mentions |
| `skills/smaqit.task-list/references/RULES.md` | Modify — update literal field-syntax mentions |
| `skills/smaqit.task-start/references/RULES.md` | Modify — update literal field-syntax mentions (kept in sync with the other two copies) |
| `skills/smaqit.task-complete/references/RULES.md` | Modify — update literal field-syntax mentions (kept in sync with the other two copies) |
| `skills/smaqit.utils.worktree/scripts/9_resolve_task_lifecycle.sh` | Modify — frontmatter-scoped parsing; fix `task_branch_name()` |
| `.smaqit/templates/task.template.md` | Delete |
| `.smaqit/templates/PLANNING-template.md` | Delete |
| `installer/main.go` | Modify — remove templates embed/deploy logic |
| `installer/Makefile` | Modify — remove templates staging step |
| `scripts/smoke-test-installer.sh` | Modify — remove templates assertion |
| `README.md` | Modify — remove templates mentions |
| `.smaqit/tasks/*.md` | Modify — backfill every existing task file to frontmatter |
| `.smaqit/tasks/PLANNING.md` | Modify — update Notes section's PR field reference |
| `tests/skills/test-parent-task-lifecycle.sh` | Modify — frontmatter fixtures/assertions |
| `tests/skills/test-task-complete-pr-lifecycle.sh` | Modify — frontmatter fixtures/assertions; single-template check |
| `tests/skills/test-triage-issues.sh` | Modify — not in original scope; found broken by the templates retirement, fixed |
| `Makefile` (root) | Modify — not in original scope; `clean` target's dead `installer/templates/` reference removed |
| `CHANGELOG.md` | Deliberately not modified — `task-complete` Phase 1 generates the pending entry itself (task 027's mechanism); a hand-written entry here would be an orphaned duplicate |

## Notes

Originated from a `smaqit.task-plan` planning session (Mode A) triggered by a user-reported discrepancy: `.smaqit/templates/task.template.md` was found to be stale (pre-dating task 011's Findings-section refactor) despite being the file installed into every consumer project via `smaqit-extensions init`/`update`, while `task-start`/`task-complete`'s own documentation linked to it as "the canonical task file structure." Discovery (two parallel Explore passes) established: only `9_resolve_task_lifecycle.sh`'s three `sed`-based extractors do real machine parsing of the affected fields; no consumer anywhere depends on field order (confirmed by real task files using inconsistent orderings today); and this repo's only other project-data frontmatter precedent (`project-research.md`) deliberately excludes dates — the decision to include dates here is a scoped, explicit exception, not a repo-wide convention change.
