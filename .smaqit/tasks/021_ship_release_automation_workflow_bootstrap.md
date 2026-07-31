# Ship Release Automation Workflow Bootstrap for Consumer Projects

**Status:** Not Started
**Created:** 2026-07-31

## Description

`smaqit-extensions init` never deploys any `.github/workflows/*.yml` to a consumer project — `installer/main.go` only embeds `agents-copilot/`, `skills/`, `templates/`, `agents-claude/`, `commands-claude/`, `skills-claude`, `agents-codex/`, and `skills-codex`. There is no `//go:embed` directive for workflows, and `install.sh` never references `.github/workflows`.

Meanwhile `agents/smaqit.release.pr.agent.md` (and its generated Copilot/Claude/Codex mirrors) describes post-merge automation as a guaranteed, unconditional outcome: "When a PR with title matching... is merged to `main`, the post-merge workflow (`.github/workflows/post-merge-release.yml`) automatically: 1. Creates and pushes git tag, 2. Builds binaries..., 3. Creates GitHub Release" and "Release completes automatically after PR merge (tag, builds, GitHub Release)." Nowhere does the agent check whether that workflow file exists in the target repo, nor does it offer to create one.

`.github/workflows/post-merge-release.yml`, `post-merge-tag.yml`, and related workflows in this repo are smaqit-extensions' own dogfooded CI (building and releasing the Go binary itself) — they are not a generic template a consumer project could reuse as-is, since they build a Go binary specific to this project. `smaqit.release-git-local` is less broken (it only says a tag push "typically triggers CI/CD release workflows"), but a consumer project still gets nothing unless they hand-author their own tag-triggered release workflow.

Net effect: a project that installs smaqit-extensions and runs `/smaqit.release.pr` gets a merged PR with a correctly formatted title and the agent reports success — but no tag, no build, and no GitHub Release is ever created, because nothing in the installed output ever produced the workflow the agent's own completion criteria assume exists.

## Design Decisions

TBD — to be confirmed during assessment. Candidate directions to evaluate:

- **Ship a generic template workflow:** add a project-agnostic `.github/workflows/post-merge-release.yml` template (tag-on-merge + optional GitHub Release creation, no Go-binary-specific build steps) to `installer/templates/`, embedded and deployed by `init` like `copilot-instructions.template.md` already is.
- **Make the agents honest about what they can guarantee:** if a generic workflow template is out of scope or not always desired (e.g., projects with their own CI conventions), rewrite `smaqit.release.pr` / `smaqit.release-git-local` to detect whether a post-merge/tag-triggered workflow exists in the target repo and clearly report to the user when it does not, rather than asserting automation as guaranteed.
- **Idempotent install behavior:** if a workflow template is added, decide whether `init` creates it only when absent (never overwriting a project's existing custom workflow) and how `smaqit-extensions update` should treat a project-modified copy.

## Implementation Steps

1. Decide the fix direction (template deployment, agent honesty/detection, or both) and record the decision above before implementing.
2. If shipping a template: author a project-agnostic `.github/workflows/post-merge-release.yml`-equivalent under `installer/templates/`, add its `//go:embed` directive in `installer/main.go`, and wire deployment into the `init` command (create-if-absent, matching the existing template-file idempotency pattern).
3. Update `agents/smaqit.release.pr.agent.md` and `skills/smaqit.release-git-local/SKILL.md` (canonical sources only) so their claims about post-merge/tag-triggered automation match what is actually installed or detected — remove language that asserts guaranteed automation when nothing ships it.
4. If detection is part of the fix, add an explicit check (e.g., does a workflow file matching a tag-push or PR-merge trigger exist in `.github/workflows/`) and a clear user-facing warning step in both release agents when no such workflow is found.
5. Update `README.md` release documentation to accurately describe what `smaqit-extensions init` provides out of the box versus what the consumer project must supply itself.
6. Bump affected skill/agent versions and add a `CHANGELOG.md` entry.
7. Run `make sync` to regenerate all platform mirrors; verify `make smoke-test` still passes and installed output matches source for the new/changed template or detection logic.

## Known Issues Triage

[Populated by smaqit.task-start via smaqit.utils.triage-issues. Do not edit manually.]

## Acceptance Criteria

- [ ] A consumer project that runs `smaqit-extensions init` and then a release agent either (a) receives a working, project-agnostic post-merge/tag-triggered release workflow, or (b) is explicitly warned by the agent that no such automation exists and told what to do about it
- [ ] `smaqit.release.pr` and `smaqit.release-git-local` (canonical sources) no longer assert guaranteed post-merge automation unconditionally when the installer does not guarantee shipping it
- [ ] If a template workflow is added, it is embedded via `installer/main.go` and deployed by `init` without overwriting an existing project workflow file
- [ ] `README.md` accurately documents what release automation is installed by default versus what the consumer must configure
- [ ] `CHANGELOG.md` documents the fix
- [ ] `make sync` regenerates all supported platform targets with no drift; `make smoke-test` passes

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
| `installer/templates/` (new workflow template file) | Create — if template-deployment direction is chosen |
| `installer/main.go` | Modify — embed and deploy new template, or add detection logic |
| `agents/smaqit.release.pr.agent.md` | Modify — align automation claims with actual installed behavior |
| `skills/smaqit.release-git-local/SKILL.md` | Modify — align automation claims with actual installed behavior |
| `README.md` | Modify — document actual out-of-the-box release automation scope |
| `CHANGELOG.md` | Modify — add entry |
| Generated platform targets (`.github/`, `.claude/`, `.agents/`, `.codex/`, `installer/*`) | Regenerate with `make sync`; do not edit manually |
| `.smaqit/tasks/PLANNING.md` | Modify — mark completed |

## Notes

- `.github/workflows/post-merge-release.yml` in this repo builds and releases the smaqit-extensions Go binary itself — it is this repo's own dogfooded CI, not a ready-to-ship generic template, and must not be copied verbatim into the installer's deployed output.
- Discovered during session assessment on 2026-07-31 while reviewing whether release-pr/release-local work out of the box in a freshly initialized consumer project.
