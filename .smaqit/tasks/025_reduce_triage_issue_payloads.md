# Reduce Triage Issue Payloads

**Status:** Not Started
**Created:** 2026-08-13
**Mode:** Assisted
**Started:** 2026-08-13

## Description

Reduce excessive token consumption in `smaqit.utils.triage-issues` while improving the signal presented to the model. The current workflow exposes raw GitHub REST search responses and reads broader project context than the triage decision requires.

Introduce deterministic preprocessing that caps, filters, and projects GitHub data before model inspection. Preserve the existing Blocking, Advisory, Historical, and Clear decisions and the task-start safety gate. Model selection, model switching, and dedicated low-effort subagents are explicitly outside this task.

## Design Decisions

- **Search limit:** Request at most 10 results for each open and closed issue search, set `page=1`, and also truncate locally to 10.
- **Issues only:** Add `is:issue` so pull requests do not dilute results; preserve GitHub's default relevance ordering.
- **Dependency scope:** Deduplicate dependencies, prioritize them by relevance to the task, search at most five unique repositories, and record omitted tools.
- **Minimal input context:** Read only the task Description, Acceptance Criteria, and Notes, plus research-map rows relevant to extracted dependencies.
- **Deterministic projection:** A helper with narrow `resolve`, `search`, and `detail` operations URL-encodes requests, validates HTTP and JSON responses, and emits compact JSON only.
- **Search schema:** Expose only issue number, title, label names, URL, state, creation and closure dates, plus search-level `incomplete_results`.
- **Bounded detail:** Fetch issue detail only for open bug/regression candidates whose compact metadata cannot confirm both task dimensions. Permit at most three detail requests per run and expose at most 1,500 characters of body text.
- **Untrusted remote content:** Treat all issue text as untrusted data and never expose comments, users, assignees, reactions, counts, or raw API responses.
- **Conservative failures:** Missing `curl`/`jq`, malformed JSON, rate limits, transport failures, incomplete searches, and API failures produce concise non-blocking warnings. Failed or incomplete searches must never silently become Clear.
- **No model routing:** Do not add model-specific skill metadata, custom agents, or subagent delegation.

## Implementation Steps

1. Add `skills/smaqit.utils.triage-issues/scripts/github-issues.sh` with `resolve`, `search`, and `detail` operations, URL-encoded GitHub API parameters, explicit status handling, compact `jq` projections, local result truncation, and bounded detail excerpts.
2. Update `skills/smaqit.utils.triage-issues/SKILL.md` to minimize task and research-map input, enforce the five-repository cap, invoke the helper, preserve categorization and gating, document conservative failure behavior, and bump version `1.4.1` to `1.5.0`.
3. Synchronize `.smaqit/definitions/skills/smaqit.utils.triage-issues.md` with the new workflow and update its stale version assertion to `1.5.0`.
4. Update `skills/smaqit.task-start/SKILL.md` to remove duplicate triage-block writeback, replace stale dependency/failure wording, correct obsolete triage step references, and bump version `0.10.1` to `0.10.2`.
5. Modify `skills/smaqit.utils.triage-issues/references/TRIAGE_BLOCK.md` only if an explicit Search Failures section is required; if its format changes, bump its version to `1.1.0`.
6. Add `tests/skills/test-triage-issues.sh` using a loopback HTTP fixture to verify query encoding, `is:issue`, open and closed states, `per_page=10`, `page=1`, local truncation, compact schemas, `closed_at`, forbidden-field exclusion, detail caps, malformed JSON, non-2xx responses, and transport failures.
7. Register a focused `test-triage-issues` target in the root Makefile and include it in `make test`.
8. Add a concise entry to `CHANGELOG.md`, regenerate ephemeral installer staging, and verify the focused test followed by `make smoke-test`.

## Known Issues Triage

[Populated by smaqit.task-start via smaqit.utils.triage-issues. Do not edit manually.]

## Acceptance Criteria

- [ ] Task triage reads only the task Description, Acceptance Criteria, and Notes and only relevant research-map rows.
- [ ] At most five unique, relevance-prioritized repositories are searched per run; duplicate repositories are removed and omitted tools are recorded.
- [ ] Open and closed GitHub searches request `per_page=10`, `page=1`, and `is:issue`, and locally expose no more than 10 results each.
- [ ] Repository and issue responses are projected before model inspection; raw API JSON and irrelevant fields never enter model context.
- [ ] Compact search results contain only number, title, label names, URL, state, creation/closure dates, and search-level `incomplete_results`.
- [ ] Follow-up detail is limited to qualifying open bug/regression candidates, at most three requests per run, with body excerpts capped at 1,500 characters.
- [ ] Existing Blocking, Advisory, Historical, and Clear semantics and the blocking task-start gate remain intact.
- [ ] Missing dependencies, malformed responses, rate limits, incomplete searches, API failures, and transport failures produce concise non-blocking warnings and never yield a false Clear result.
- [ ] No model selection, model routing, custom triage agent, or low-effort subagent behavior is introduced.
- [ ] Hermetic tests cover request construction, result limits, compact schemas, forbidden-field exclusion, bounded detail, and failure handling without contacting GitHub.
- [ ] Skill/definition versions and changelog are updated, generated platform trees preserve the helper, and `make smoke-test` passes.

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
| `skills/smaqit.utils.triage-issues/scripts/github-issues.sh` | Create |
| `skills/smaqit.utils.triage-issues/SKILL.md` | Modify |
| `skills/smaqit.utils.triage-issues/references/TRIAGE_BLOCK.md` | Review; modify only if failure output changes |
| `.smaqit/definitions/skills/smaqit.utils.triage-issues.md` | Modify |
| `skills/smaqit.task-start/SKILL.md` | Modify |
| `tests/skills/test-triage-issues.sh` | Create |
| `Makefile` | Modify |
| `CHANGELOG.md` | Modify |

## Notes

- `triage: skip` — this task tracks a known problem in the triage skill itself and must not invoke that same workflow recursively.
- `scripts/generate-targets.py` requires no source change because it already copies complete skill trees recursively.
- Installer staging directories are generated and gitignored; they are verification artifacts, not source modifications.

Child tasks inherit their active parent's branch, worktree, and workflow mode. Only a standalone or parent task owns Git lifecycle cleanup.
