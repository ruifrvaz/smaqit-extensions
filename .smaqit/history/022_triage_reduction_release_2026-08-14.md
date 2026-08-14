# Triage Reduction Release

**Date:** 2026-08-14
**Session focus:** Reducing execution-token usage in upstream issue triage while preserving signal, completing the resulting task, preparing and releasing v1.16.0, and auditing the installed artifacts.
**Tasks completed:** 025 — Reduce Triage Issue Payloads
**Tasks referenced:** 002, 007, 010 (unchanged, Not Started); 026 (completed separately)

## Actions Taken

- Assessed model-selection options across Claude Code, Codex, and GitHub Copilot, then kept model routing and dedicated low-effort agents out of scope in favor of deterministic data reduction.
- Replanned Task 025 after identifying that reducing instruction text would not solve execution-token usage. Preserved detailed triage instructions and its dependency on project research.
- Added task-owned `Issue Triage Context`, deterministic extraction and fingerprinting, keyed task-map projection, and compact GitHub issue helpers. Reordered task start so the narrow projections reach triage before full task or full-map content.
- Added hermetic coverage for structured and legacy contexts, map isolation and replacement, result caps, compact response schemas, bounded detail, and transport/API failures.
- Completed Task 025, merged it to `main`, cleaned its worktree and branch, and rebuilt the workspace file.
- Prepared PR #123 for v1.16.0, reconciled the changelog, updated the installer fallback version, and verified the release build and installer smoke test. The PR merged; tag v1.16.0, GitHub Release assets, and release automation completed successfully.
- Audited the current global installation: binary, active skills, platform artifacts, and the new triage helpers match v1.16.0. Refreshed the project research map after verifying all documented project URLs.

## Problems Solved

- **Excessive triage context:** Raw issue responses and broad task/map reads were replaced with bounded, deterministic projections that retain only decision-relevant data.
- **Insufficient task signal:** A stable task schema now explicitly identifies technologies, platforms, features, constraints, and triage mode instead of requiring the triage model to infer them from prose.
- **Stale task-map use:** Task-specific research blocks are identified by task ID and context fingerprint, allowing targeted refreshes without replacing the project-level map.
- **Release changelog placement:** The Task 025 entry was moved from the already-released v1.15.0 section into v1.16.0 before the release PR was created.

## Decisions Made

- Keep full skill instructions unless redundant; reduce execution payloads rather than prompt detail.
- Keep project research as triage's authoritative upstream source. Triage consumes only its verified current-task projection.
- Do not add model-specific routing, per-skill model overrides, custom triage agents, or low-effort subagents.
- Use v1.16.0 as a MINOR release because the structured triage context and deterministic helper workflow are new user-facing capabilities.

## Files Modified

- `.smaqit/tasks/025_reduce_triage_issue_payloads.md`, `.smaqit/tasks/PLANNING.md`, and `smaqit-extensions.code-workspace` — Task 025 planning, completion state, and lifecycle workspace cleanup.
- `.smaqit/templates/task.template.md`, `skills/smaqit.task-create/assets/TASK_TEMPLATE.md`, `skills/smaqit.task-create/SKILL.md`, and `skills/smaqit.task-plan/SKILL.md` — structured Issue Triage Context template and producer contract.
- `skills/smaqit.project-research/SKILL.md`, `skills/smaqit.project-research/references/RESEARCH_MAP.md`, `skills/smaqit.project-research/scripts/task-context.sh`, and `skills/smaqit.project-research/scripts/task-map.sh` — context extraction, fingerprinting, task-map projection, and refresh rules.
- `skills/smaqit.task-start/SKILL.md`, `skills/smaqit.utils.triage-issues/SKILL.md`, `.smaqit/definitions/skills/smaqit.utils.triage-issues.md`, `skills/smaqit.utils.triage-issues/references/TRIAGE_BLOCK.md`, and `skills/smaqit.utils.triage-issues/scripts/github-issues.sh` — narrow triage ordering, compact GitHub data, and synchronized contracts.
- `tests/skills/test-triage-issues.sh`, `Makefile`, and `installer/templates/task.template.md` — focused regression coverage and generated-template parity.
- `CHANGELOG.md` and `installer/main.go` — v1.16.0 release notes and installer fallback version.
- `.smaqit/references/project-research.md`, `.smaqit/compendium.md`, and this history file — refreshed documentation topology and durable session knowledge.

## Next Steps

- Remove the obsolete `task-signal.sh` files left in the global shared and Claude triage skill directories; active v1.16.0 instructions do not reference them.
- Installed helper files are intentionally invoked through `bash`; the installer currently writes them non-executable, so direct `./script` invocation is unsupported.
- Tasks 002, 007, and 010 remain Not Started.

## Session Metrics

- **Tasks completed:** 1 (025)
- **Release shipped:** v1.16.0 through PR #123
- **Validation:** `make test`, `make smoke-test`, release-version installer smoke test, GitHub Release workflow, and global-install artifact comparison passed.
- **Key execution limits:** five repositories, ten issues per state, three detail requests, and 1,500-character detail excerpts.
