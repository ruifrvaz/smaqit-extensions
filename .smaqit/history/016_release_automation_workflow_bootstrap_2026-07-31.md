# Release Automation Workflow Bootstrap

**Date:** 2026-07-31
**Session focus:** Diagnosing and closing the release-automation out-of-the-box gap, releasing v1.11.0, and repairing a pre-existing CI failure
**Tasks completed:** 021 — Ship Release Automation Workflow Bootstrap for Consumer Projects
**Tasks referenced:** None

## Actions Taken

- Assessed whether `smaqit.release.pr`/`smaqit.release-git-local` work out of the box in a freshly initialized consumer project; confirmed the installer never deploys any `.github/workflows/*.yml` while the release agent/skills assert guaranteed post-merge tag/build/release automation.
- Created and completed Task 021: shipped a generic, project-agnostic `installer/workflow-templates/post-merge-release.yml` (tag + GitHub Release, no build step), embedded and deployed create-if-absent by `init`/`update`; corrected false "builds binaries for all platforms" claims — copied from this repo's own CI — out of `agents/smaqit.release.pr.agent.md`, `skills/smaqit.release-git-pr/SKILL.md` (including text written directly into consumer release PR descriptions), and `skills/smaqit.release-git-local/SKILL.md`.
- Ran `make sync` from the primary checkout (deferred from the task worktree, whose sparse checkout excludes the generated-mirror directories) to refresh the `.github/`, `.codex/`, and `.agents/` dogfooding mirrors, then verified with `make test` and `make smoke-test`.
- Ran a full local release via the `smaqit-release-local` subagent: promoted `[Unreleased]` to `v1.11.0` in CHANGELOG.md, bumped `installer/main.go`'s `Version` constant, committed, tagged, and pushed — including recovering a previously unpushed v1.10.0 commit.
- Diagnosed and fixed a pre-existing CI failure: `Test Integration` had been failing since the v1.10.0 push (2026-07-29) because `tests/skills/test-parent-task-lifecycle.sh` (added in task 020) needs `ripgrep`, which the workflow never installed. Added an install step and confirmed the fix with a green CI run.
- Verified the v1.11.0 tag-triggered `Release` workflow completed successfully and published the GitHub Release with all 5 platform binaries.

## Problems Solved

- Consumer projects that install smaqit-extensions and run a release agent now receive real, working post-merge tag/release automation instead of a false guarantee backed by nothing.
- Every release PR description and the release agents' own instructions no longer claim binary builds that only this repo's own dogfooded CI actually performs.
- `Test Integration` CI is green again after roughly two releases (v1.10.0, v1.11.0) of silent failure.
- Local release push to a git remote without a pre-configured SSH agent was recovered via this project's documented, narrowly-scoped desktop SSH-agent socket discovery — used once for the `main` push and once (on retry) for the tag push, both explicitly authorized by the user in-session.

## Decisions Made

- Chose to ship a generic template workflow over a detect-and-warn-only approach (user decision) — consumer projects get real automation by default.
- Kept the new workflow template in its own `installer/workflow-templates/` embed source rather than nesting it under `installer/templates/`, since the latter is asserted byte-for-byte identical to `.smaqit/templates/` in the smoke test and has different mirroring semantics than a file deployed to `.github/workflows/`.
- Deferred `make sync` to a post-merge finalization step on the primary checkout rather than attempting it inside the task worktree, consistent with the worktree skill's documented sparse-checkout exclusions.
- Approved v1.11.0 (MINOR) as the release version and explicitly authorized bumping `installer/main.go`'s `Version` constant to match.
- When the harness's security classifier flagged the SSH-agent socket discovery as a Credential Exploration pattern, surfaced that flag transparently to the user rather than silently proceeding or silently suppressing it, and only retried the push after explicit per-instance authorization.

## Files Modified

- `.smaqit/tasks/021_ship_release_automation_workflow_bootstrap.md`, `.smaqit/tasks/PLANNING.md` — created and completed Task 021.
- `installer/workflow-templates/post-merge-release.yml` (new), `installer/main.go` — generic release workflow template and its create-if-absent embed/deploy logic.
- `agents/smaqit.release.pr.agent.md`, `skills/smaqit.release-git-pr/SKILL.md`, `skills/smaqit.release-git-local/SKILL.md`, `.smaqit/definitions/agents/smaqit.release.pr.frontmatter.yaml` — removed false binary-build claims; version bumps (0.3.0→0.3.1 ×2, 0.5.0→0.5.1).
- `README.md` — documented the new installed workflow, its create-if-absent behavior, and distinguished this repo's own dogfooded release process from what consumers get.
- `scripts/smoke-test-installer.sh` — added tree-parity and create-if-absent idempotency coverage for the new workflow.
- `.github/agents/`, `.github/skills/`, `.codex/agents/`, `.agents/skills/` (generated mirrors) — refreshed via `make sync`.
- `CHANGELOG.md`, `installer/main.go` — prepared and released `v1.11.0`.
- `.github/workflows/test-integration.yml` — added a ripgrep install step, fixing the pre-existing CI failure.

## Next Steps

1. No immediate follow-up required for Task 021 or the CI fix; both are verified live on `main` and released.
2. Task 002 (cumulative changelog extraction for GitHub Release notes) remains open and related in spirit — the new generic workflow template reuses the same single-version `awk` extraction, so fixing 002 would also need to update the template.
3. Tasks 007, 010, and 017 remain open and untouched this session.

## Session Metrics

- Tasks completed: 1 (021)
- Releases published: 1 (`v1.11.0`, with 5 platform binaries)
- CI runs fixed: 1 (`Test Integration`, broken across 2 prior releases)
- Test gates passed: `make -C installer test`, root `make test`, `make smoke-test` (task worktree and post-sync on main), live CI `Test Integration` and `Release` workflows
