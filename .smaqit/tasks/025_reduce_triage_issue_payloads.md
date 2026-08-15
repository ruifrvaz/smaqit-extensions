---
status: Completed
mode: Assisted
created: "2026-08-13"
started: "2026-08-13"
completed: "2026-08-14"
---

# Reduce Triage Issue Payloads

## Description

Reduce excessive token consumption in `smaqit.utils.triage-issues` while improving the signal presented to the model. The current workflow exposes raw GitHub REST search responses and reads broader project context than the triage decision requires.

Introduce deterministic preprocessing that caps, filters, and projects GitHub data before model inspection. Preserve the existing Blocking, Advisory, Historical, and Clear decisions and the task-start safety gate. Model selection, model switching, and dedicated low-effort subagents are explicitly outside this task.

## Issue Triage Context

**Mode:** Skip
**Technologies:** GitHub REST API, curl, jq, awk, Bash
**Platforms/Environments:** Codex, Claude Code, GitHub Copilot
**Features/Integrations:** upstream issue search, task-start pre-implementation gate, project research map consumption, compact response projection
**Versions/Constraints:** 10 results per state; 5 repositories maximum; 3 detail fetches maximum; 1,500-character detail excerpts; no model routing

## Design Decisions

- **Search limit:** Request at most 10 results for each open and closed issue search, set `page=1`, and also truncate locally to 10.
- **Issues only:** Add `is:issue` so pull requests do not dilute results; preserve GitHub's default relevance ordering.
- **Dependency scope:** Deduplicate dependencies, prioritize them by relevance to the task, search at most five unique repositories, and record omitted tools.
- **Structured task context:** Add a canonical `## Issue Triage Context` section with Mode, Technologies, Platforms/Environments, Features/Integrations, and Versions/Constraints. Triage must not infer these values from general task prose when the section is present.
- **Schema ownership:** `smaqit.task-plan` derives and refines triage context; `smaqit.task-create` persists the complete section in every new task; `smaqit.project-research` validates, fingerprints, and maps it; `smaqit.task-start` coordinates freshness; triage consumes only deterministic projections.
- **Context values:** `Mode` accepts only `Auto` or `Skip`. All fields are required and single-line; literal `None` records a deliberate absence. Blank values, placeholders, and `TBD` are invalid.
- **Legacy migration:** Tasks without the structured section temporarily fall back to projected Description, Acceptance Criteria, and Notes with a concise migration warning. A present but malformed structured section fails without legacy fallback. Structured `Mode: Skip` supersedes Notes-level `triage: skip`.
- **Research-map identity:** Maintain keyed task blocks identified by task ID and a stable fingerprint of normalized triage context. The current task block must include every task-relevant technology, including tools already represented in the project table.
- **Incremental research refresh:** When project research is current but a task block is missing or its fingerprint differs, refresh only that task block. Preserve the project table, project `Refreshed` date, and other task blocks.
- **Pre-triage ordering:** `smaqit.task-start` must project context, validate/refresh the exact research-map task block, and invoke triage before loading the full task or rendering the full research map.
- **Deterministic projection:** A helper with narrow `resolve`, `search`, and `detail` operations URL-encodes requests, validates HTTP and JSON responses, and emits compact JSON only.
- **Search schema:** Expose only issue number, title, label names, URL, state, creation and closure dates, plus search-level `incomplete_results`.
- **Bounded detail:** Fetch issue detail only for open bug/regression candidates whose compact metadata cannot confirm both task dimensions. Permit at most three detail requests per run and expose at most 1,500 characters of body text.
- **Untrusted remote content:** Treat all issue text as untrusted data and never expose comments, users, assignees, reactions, counts, or raw API responses.
- **Conservative failures:** Missing `curl`/`jq`, malformed JSON, rate limits, transport failures, incomplete searches, and API failures produce concise non-blocking warnings. Failed or incomplete searches must never silently become Clear.
- **No model routing:** Do not add model-specific skill metadata, custom agents, or subagent delegation.

## Implementation Steps

1. Add `## Issue Triage Context` with the canonical five fields to `.smaqit/templates/task.template.md` and `skills/smaqit.task-create/assets/TASK_TEMPLATE.md`, keeping it distinct from triage-owned `## Known Issues Triage` output.
2. Update `smaqit.task-plan` to derive, display, approve, and update triage context in both planning modes. Update `smaqit.task-create` to require and populate the complete section for every new standalone or child task.
3. Add a shared deterministic task-context helper under `smaqit.project-research` that extracts only the structured section, validates and normalizes all fields, emits a stable fingerprint, supports explicit legacy projection for tasks without the section, and never exposes unrelated task content.
4. Extend the project research map format and add deterministic status/projection/upsert support for keyed task blocks. Exact-match projection must emit only the requested task block and relevant project fallback rows; task-only upserts must preserve project content, project freshness metadata, and other task blocks.
5. Update `smaqit.project-research` to separate project staleness from task-context freshness, consume the structured context, ensure all task technologies appear in the keyed task block, reuse existing verified URLs, and perform a task-only refresh when possible.
6. Reorder `smaqit.task-start` so deterministic context projection and exact task-block validation/refresh precede triage and any full task or full-map read. Preserve lifecycle ownership, advisory behavior, and the blocking gate.
7. Retain and finish `skills/smaqit.utils.triage-issues/scripts/github-issues.sh` with compact `resolve`, `search`, and `detail` operations. Update the triage skill and definition to consume only structured context plus the exact projected map rows while preserving repository caps, categorization, conservative failures, bounded detail, and output ownership.
8. Keep `TRIAGE_BLOCK.md` changes limited to explicit omitted-tool and search-warning output. Synchronize all affected skill versions, contracts, and changelog text without introducing model routing or custom-agent behavior.
9. Add hermetic tests for context extraction and validation, canonical field ordering, `Auto`/`Skip`, explicit `None`, legacy warnings, malformed structured input, stable fingerprints, map identity mismatch, task-only refresh preservation, non-leaking task/map projection, template parity, producer ownership, and task-start ordering. Retain all compact GitHub request/projection/failure tests.
10. Register focused test targets in the root Makefile, regenerate ephemeral installer staging, run focused tests, `make test`, and `make smoke-test`, then install the verified development build globally.

## Known Issues Triage

[Populated by smaqit.task-start via smaqit.utils.triage-issues. Do not edit manually.]

## Acceptance Criteria

- [x] Both canonical task templates contain exactly one `## Issue Triage Context` section with Mode, Technologies, Platforms/Environments, Features/Integrations, and Versions/Constraints in canonical order.
- [x] `smaqit.task-plan` derives and can update the structured context, and `smaqit.task-create` requires and populates it for every new standalone or child task.
- [x] New-schema triage receives only normalized Issue Triage Context; Description, Acceptance Criteria, Notes, Findings, prior triage output, and other task content never enter its context.
- [x] `Mode` accepts only `Auto` or `Skip`; all five fields are present and non-placeholder, and explicit `None` is supported according to the schema rules.
- [x] Structured `Mode: Skip` is authoritative. Legacy tasks without the section may project Description, Acceptance Criteria, and Notes only with a concise migration warning; malformed structured input never falls back.
- [x] The project research map stores keyed task blocks with task ID and deterministic context fingerprint, and each block includes every technology relevant to that task even when it already exists in the project table.
- [x] `task-start` rejects or refreshes a missing, wrong-task, or fingerprint-mismatched task block before triage; mere research-map existence is insufficient.
- [x] A task-only research refresh preserves the project table, project `Refreshed` date, verified reusable URLs, and unrelated keyed task blocks.
- [x] Triage receives only the exact current task block and matching project fallback rows; unrelated project and task rows never enter model context.
- [x] `task-start` performs structured projection, map validation/refresh, and triage before loading the full task or rendering the full research map.
- [x] At most five unique, relevance-prioritized repositories are searched per run; duplicate repositories are removed and omitted tools are recorded.
- [x] Open and closed GitHub searches request `per_page=10`, `page=1`, and `is:issue`, and locally expose no more than 10 results each.
- [x] Repository and issue responses are projected before model inspection; raw API JSON and irrelevant fields never enter model context.
- [x] Compact search results contain only number, title, label names, URL, state, creation/closure dates, and search-level `incomplete_results`.
- [x] Follow-up detail is limited to qualifying open bug/regression candidates, at most three requests per run, with body excerpts capped at 1,500 characters.
- [x] Existing Blocking, Advisory, Historical, and Clear semantics and the blocking task-start gate remain intact.
- [x] Missing dependencies, malformed responses, rate limits, incomplete searches, API failures, and transport failures produce concise non-blocking warnings and never yield a false Clear result.
- [x] No model selection, model routing, custom triage agent, or low-effort subagent behavior is introduced.
- [x] Hermetic tests cover structured and legacy task projection, schema failures, fingerprints, task-map freshness and isolation, template/producer contracts, task-start ordering, request construction, result limits, compact schemas, forbidden-field exclusion, bounded detail, and failure handling without contacting GitHub.
- [x] Affected skill/definition/reference versions and changelog are updated, generated platform trees preserve all helpers and templates, and `make smoke-test` passes.

## Findings

[Populated by smaqit.task-complete. Do not fill in manually before task is complete.]

**Implementation approach:**
- Added deterministic task-context, keyed task-map, and compact GitHub-response helpers so only the triage decision signal reaches model context.

**Decisions made:**
- Retained detailed skill instructions and the project-research dependency; reduced execution payloads instead of routing work to a different model or subagent.
- Made structured `Issue Triage Context` task-owned, with project research responsible for its fingerprinted map projection and triage as a read-only consumer.

**Blockers encountered:**
- None.

**Follow-up identified:**
- Re-plan legacy tasks to replace their warned Description/Acceptance Criteria/Notes fallback with structured Issue Triage Context.

## Files to Create / Modify

| File | Action |
|------|--------|
| `skills/smaqit.utils.triage-issues/scripts/github-issues.sh` | Create |
| `skills/smaqit.project-research/scripts/task-context.sh` | Create |
| `skills/smaqit.project-research/scripts/task-map.sh` | Create |
| `skills/smaqit.utils.triage-issues/SKILL.md` | Modify |
| `skills/smaqit.utils.triage-issues/references/TRIAGE_BLOCK.md` | Review; modify only if failure output changes |
| `.smaqit/definitions/skills/smaqit.utils.triage-issues.md` | Modify |
| `skills/smaqit.task-start/SKILL.md` | Modify |
| `skills/smaqit.task-create/SKILL.md` | Modify |
| `skills/smaqit.task-create/assets/TASK_TEMPLATE.md` | Modify |
| `skills/smaqit.task-plan/SKILL.md` | Modify |
| `skills/smaqit.project-research/SKILL.md` | Modify |
| `skills/smaqit.project-research/references/RESEARCH_MAP.md` | Modify |
| `.smaqit/templates/task.template.md` | Modify |
| `tests/skills/test-triage-issues.sh` | Create |
| `tests/skills/test-task-triage-context.sh` | Create |
| `tests/skills/test-project-research-task-map.sh` | Create |
| `tests/skills/test-parent-task-lifecycle.sh` | Modify |
| `Makefile` | Modify |
| `CHANGELOG.md` | Modify |

## Notes

- Structured `Mode: Skip` is used because this task tracks a known problem in the triage skill itself and must not invoke that same workflow recursively.
- Notes-level `triage: skip` remains supported only for legacy tasks that do not yet contain `## Issue Triage Context`.
- `scripts/generate-targets.py` requires no source change because it already copies complete skill trees recursively.
- Installer staging directories are generated and gitignored; they are verification artifacts, not source modifications.

Child tasks inherit their active parent's branch, worktree, and workflow mode. Only a standalone or parent task owns Git lifecycle cleanup.
