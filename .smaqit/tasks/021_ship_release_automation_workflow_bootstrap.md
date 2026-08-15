---
status: Completed
mode: Assisted
created: "2026-07-31"
started: "2026-07-31"
completed: "2026-07-31"
---

# Ship Release Automation Workflow Bootstrap for Consumer Projects

## Description

`smaqit-extensions init` never deploys any `.github/workflows/*.yml` to a consumer project — `installer/main.go` only embeds `agents-copilot/`, `skills/`, `templates/`, `agents-claude/`, `commands-claude/`, `skills-claude`, `agents-codex/`, and `skills-codex`. There is no `//go:embed` directive for workflows, and `install.sh` never references `.github/workflows`.

Meanwhile `agents/smaqit.release.pr.agent.md` (and its generated Copilot/Claude/Codex mirrors) describes post-merge automation as a guaranteed, unconditional outcome: "When a PR with title matching... is merged to `main`, the post-merge workflow (`.github/workflows/post-merge-release.yml`) automatically: 1. Creates and pushes git tag, 2. Builds binaries..., 3. Creates GitHub Release" and "Release completes automatically after PR merge (tag, builds, GitHub Release)." Nowhere does the agent check whether that workflow file exists in the target repo, nor does it offer to create one.

`.github/workflows/post-merge-release.yml`, `post-merge-tag.yml`, and related workflows in this repo are smaqit-extensions' own dogfooded CI (building and releasing the Go binary itself) — they are not a generic template a consumer project could reuse as-is, since they build a Go binary specific to this project. `smaqit.release-git-local` is less broken (it only says a tag push "typically triggers CI/CD release workflows"), but a consumer project still gets nothing unless they hand-author their own tag-triggered release workflow.

Net effect: a project that installs smaqit-extensions and runs `/smaqit.release.pr` gets a merged PR with a correctly formatted title and the agent reports success — but no tag, no build, and no GitHub Release is ever created, because nothing in the installed output ever produced the workflow the agent's own completion criteria assume exists.

## Design Decisions

- **Fix direction (confirmed 2026-07-31):** Ship a generic template workflow. Add a project-agnostic `.github/workflows/post-merge-release.yml` template (tag-on-merge + GitHub Release creation, no Go-binary-specific build steps) to `installer/templates/`, embedded and deployed by `init` like `copilot-instructions.template.md` already is. Detect-and-warn-only was not chosen — consumer projects should get real, working automation by default rather than just an honest warning.
- **Idempotent install behavior:** `init` creates the workflow file only when absent at the target path — it must never overwrite a project's existing custom workflow. `smaqit-extensions update` follows the same create-if-absent rule as other templates, so a project-modified copy is left untouched.

## Implementation Steps

1. Decide the fix direction (template deployment, agent honesty/detection, or both) and record the decision above before implementing.
2. If shipping a template: author a project-agnostic `.github/workflows/post-merge-release.yml`-equivalent under `installer/templates/`, add its `//go:embed` directive in `installer/main.go`, and wire deployment into the `init` command (create-if-absent, matching the existing template-file idempotency pattern).
3. Update `agents/smaqit.release.pr.agent.md` and `skills/smaqit.release-git-local/SKILL.md` (canonical sources only) so their claims about post-merge/tag-triggered automation match what is actually installed or detected — remove language that asserts guaranteed automation when nothing ships it.
4. If detection is part of the fix, add an explicit check (e.g., does a workflow file matching a tag-push or PR-merge trigger exist in `.github/workflows/`) and a clear user-facing warning step in both release agents when no such workflow is found.
5. Update `README.md` release documentation to accurately describe what `smaqit-extensions init` provides out of the box versus what the consumer project must supply itself.
6. Bump affected skill/agent versions and add a `CHANGELOG.md` entry.
7. Run `make sync` to regenerate all platform mirrors; verify `make smoke-test` still passes and installed output matches source for the new/changed template or detection logic.

## Known Issues Triage

**Triaged:** 2026-07-31
**Tools searched:** Go, GitHub Actions
**Result:** Clear

### Blocking Issues
- None.

### Advisory Issues
- None.

### Historical (Closed)
- None.

### Unresolvable Tools
- None.

## Acceptance Criteria

- [x] A consumer project that runs `smaqit-extensions init` and then a release agent either (a) receives a working, project-agnostic post-merge/tag-triggered release workflow, or (b) is explicitly warned by the agent that no such automation exists and told what to do about it
- [x] `smaqit.release.pr` and `smaqit.release-git-local` (canonical sources) no longer assert guaranteed post-merge automation unconditionally when the installer does not guarantee shipping it
- [x] If a template workflow is added, it is embedded via `installer/main.go` and deployed by `init` without overwriting an existing project workflow file
- [x] `README.md` accurately documents what release automation is installed by default versus what the consumer must configure
- [x] `CHANGELOG.md` documents the fix
- [x] `make sync` regenerates all supported platform targets with no drift; `make smoke-test` passes — `make smoke-test` verified from the task worktree; `make sync` itself deferred to the post-merge finalization step (worktree sparse checkout excludes the mirror directories it regenerates)

## Findings

**Implementation approach:**
- Added a project-agnostic `installer/workflow-templates/post-merge-release.yml` (reuses the version-extraction and tag-creation logic from this repo's own dogfooded workflow, but drops the Go-binary build matrix) and deployed it via a new create-if-absent loop in `installer/main.go`, mirroring the existing `.smaqit/templates/` idempotency pattern.
- Audited `agents/smaqit.release.pr.agent.md`, `skills/smaqit.release-git-pr/SKILL.md`, and `skills/smaqit.release-git-local/SKILL.md` for claims that assumed automation the installer never shipped; found the "builds binaries for Linux/macOS/Windows" claim was copied from this repo's own CI into generic, consumer-facing instructions — including text `release-git-pr` writes directly into consumer release PR descriptions — and corrected all instances to describe only the generic tag+release behavior actually installed.
- Extended `scripts/smoke-test-installer.sh` with a tree-parity check and an idempotency check (hand-edit the deployed workflow, re-run `init`, assert the edit survives) to directly cover the create-if-absent acceptance criterion.

**Decisions made:**
- Chose "ship a generic template workflow" over "detect-and-warn only" (user decision, 2026-07-31) — consumer projects get real automation by default rather than just an honest warning.
- Kept the new workflow template in a separate `installer/workflow-templates/` embed source rather than nesting it under `installer/templates/`, because the latter is mirrored 1:1 into both this repo's own `.smaqit/templates/` (dogfooding) and every consumer project's `.smaqit/templates/`, and is asserted byte-for-byte equal in `smoke-test-installer.sh`; the workflow's deployment target (`.github/workflows/`) and mirroring semantics are different enough to warrant its own embed and install loop rather than overloading that contract.

**Blockers encountered:**
- The task worktree's sparse checkout intentionally excludes `.github/agents/`, `.github/skills/`, `.claude/*`, `.codex/agents/`, and `.agents/skills/` (generated-mirror exclusion by design), so `make sync` could not run from within it after editing the three canonical agent/skill files. Deferred to a post-merge finalization step on the primary checkout, per the user's explicit follow-up instruction.
- `ripgrep` (`rg`) was missing from this environment, blocking `tests/skills/test-parent-task-lifecycle.sh`; installed a static binary locally to verify the suite before completing (not a change to committed files).

**Follow-up identified:**
- None beyond the deferred `make sync` finalization step tracked in this task's Notes.

## Files to Create / Modify

| File | Action |
|------|--------|
| `installer/workflow-templates/post-merge-release.yml` | Created — generic, project-agnostic template (tag + GitHub Release, no build step) |
| `installer/main.go` | Modified — new embed, create-if-absent deploy to `.github/workflows/`, printHelp/summary lines |
| `agents/smaqit.release.pr.agent.md` | Modified — removed guaranteed "builds binaries" claims; describes generic tag+release behavior |
| `skills/smaqit.release-git-pr/SKILL.md` | Modified — same alignment, including the PR-description template the agent writes into consumer PRs; version 0.3.0 → 0.3.1 |
| `skills/smaqit.release-git-local/SKILL.md` | Modified — same alignment; version 0.3.0 → 0.3.1 |
| `.smaqit/definitions/agents/smaqit.release.pr.frontmatter.yaml` | Modified — copilot metadata version 0.5.0 → 0.5.1 |
| `README.md` | Modified — "What Gets Installed", self-update, Requirements, and Releases sections |
| `scripts/smoke-test-installer.sh` | Modified — added tree-parity and create-if-absent idempotency assertions for the new workflow |
| `CHANGELOG.md` | Modified — added `[Unreleased]` entries |
| `.smaqit/tasks/PLANNING.md` | Modified — status set to In Progress |

## Notes

- **`make sync` still needs to run before/at merge.** This task worktree's sparse checkout intentionally excludes `.github/agents/`, `.github/skills/`, `.claude/*`, `.codex/agents/`, and `.agents/skills/` (see `smaqit.utils.worktree` Gotcha #12: task branches modify canonical source, not generated mirrors). Since this task edited three canonical files (`agents/smaqit.release.pr.agent.md`, `skills/smaqit.release-git-pr/SKILL.md`, `skills/smaqit.release-git-local/SKILL.md`), `make sync` must be run from the primary repo checkout (not this worktree) to refresh the tracked `.github/`, `.codex/`, and `.agents/` dogfooding mirrors before the branch is merged — otherwise CI's mirror-drift check will fail. `installer/main.go` and `installer/workflow-templates/` changes were already verified directly via `make -C installer prepare && make -C installer test` and `make smoke-test` from this worktree.
- Verified locally: `make -C installer test` (Go build + unit tests), root `make test` (worktree-layout + parent-task-lifecycle hermetic suites, after installing `ripgrep` which was missing from this environment), and `make smoke-test` (full installer smoke test, including a new idempotency check that a hand-edited workflow file survives a second `init`) all pass.

- `.github/workflows/post-merge-release.yml` in this repo builds and releases the smaqit-extensions Go binary itself — it is this repo's own dogfooded CI, not a ready-to-ship generic template, and must not be copied verbatim into the installer's deployed output.
- Discovered during session assessment on 2026-07-31 while reviewing whether release-pr/release-local work out of the box in a freshly initialized consumer project.
