---
status: In Progress
mode: Assisted
created: "2026-09-13"
started: "2026-09-13"
---

# Fix Project-Init Scaffolding: Drop Copilot-Instructions Symlink, Trim Boilerplate, Add Baseline Workspace

## Description

`smaqit.project-init` copies irrelevant SSH-recovery and scope-project-only boilerplate verbatim into every downstream project's `AGENTS.md`, keeps a fragile symlink-based `.github/copilot-instructions.md` when GitHub Copilot now reads root `AGENTS.md` natively across all its surfaces, and no scaffolding step ever creates a baseline `.code-workspace`. This task trims the template, drops `.github/copilot-instructions.md` entirely in favor of `AGENTS.md` as Copilot's canonical source too, and adds baseline workspace scaffolding to the Go installer.

Verified via official GitHub docs (not assumption) that VS Code Copilot Chat, the Copilot coding agent, and Copilot CLI all natively read a root `AGENTS.md`:
- https://docs.github.com/en/copilot/reference/custom-instructions-support
- https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-custom-instructions
- https://github.blog/changelog/2025-08-28-copilot-coding-agent-now-supports-agents-md-custom-instructions/

Task 015's own issue triage previously flagged the adjacent symlink risk ([claude-code#66559](https://github.com/anthropics/claude-code/issues/66559) — Claude refuses to write a symlinked file), which is part of why the symlink design is being retired rather than patched.

## Issue Triage Context

**Mode:** Auto
**Technologies:** Go, Markdown skills, GitHub Copilot custom instructions, Claude Code CLAUDE.md imports, VS Code .code-workspace
**Platforms/Environments:** GitHub Copilot (VS Code, coding agent, CLI), Claude Code, Codex, cross-platform symlink behavior (Linux/macOS/Windows)
**Features/Integrations:** Project instruction synchronization, VS Code multi-root workspace scaffolding
**Versions/Constraints:** None beyond current v2.0.6 baseline

## Design Decisions

- **Drop `.github/copilot-instructions.md` entirely, with no fallback reference anywhere:** GitHub's own docs confirm Copilot reads root `AGENTS.md` on every major surface, so the symlink (and every generic "check copilot-instructions.md" hint elsewhere in this repo) is removed outright, not conditionally retained. A project with only a hand-written `copilot-instructions.md` and no `AGENTS.md` yet simply won't be picked up by the probe skills until `AGENTS.md` exists — accepted as the clean cut.
- **Legacy migration removes the redundant file:** a pre-existing `.github/copilot-instructions.md` (regular file or symlink) has its unique content migrated into `AGENTS.md` using the same preserve-before-replace discipline the skill already uses, then the file/symlink is deleted — never left alongside `AGENTS.md`, since Copilot reads both if both exist and a stale duplicate would reintroduce two sources of truth.
- **Baseline `.code-workspace` scaffolding lives in the Go binary (`scaffoldProject`), not the `smaqit.project-init` skill:** it's deterministic and needs no LLM reasoning or git/jq dependency for the zero-worktree case, matching the existing create-if-absent precedent for `.github/workflows/post-merge-release.yml` (`installReleaseWorkflow` + `writeFileIfMissing`).
- **SSH-agent recovery and the scope-project-only path list are trimmed/conditioned, not deleted outright:** the guidance itself is still valid for a project that actually uses `smaqit.release-git-local` or `--scope project` — it just shouldn't be force-copied into every project's canonical `AGENTS.md` regardless of relevance.

## Implementation Steps

1. Trim `skills/smaqit.project-init/references/AGENTS.template.md`'s `# Scaffolding` section: remove the "Desktop Linux SSH Agent Recovery" paragraph (that guidance already lives in `agents/smaqit.release.local.agent.md` / `skills/smaqit.release-git-local/SKILL.md`, which is what actually executes it) and drop or drastically compress the 11-item scope-project-only path list (`.github/agents/`, `.claude/skills/`, `agents/`, `skills/`, `commands/`, `scripts/`, `installer/`, etc.) that never applies to a default global-install consumer project.
2. Rewrite `skills/smaqit.project-init/SKILL.md`:
   - Topology description (top of file): `AGENTS.md` (canonical) + `CLAUDE.md` (`@AGENTS.md` import plus Claude-only additions) only — remove the `.github/copilot-instructions.md` symlink bullet.
   - Step 3: keep reading `.github/copilot-instructions.md` when present, but frame it purely as legacy-migration input, not a canonical source.
   - Step 8: replace "migrate the Copilot path to the canonical symlink" with "detect and remove a legacy copilot-instructions.md" — verify its unique content is represented in `AGENTS.md`, then delete the file (or symlink) outright. No symlink is ever created.
   - Requirements section: remove/rewrite the bullets referencing "the Copilot symlink."
3. Update the 6 secondary skills' generic instruction-probe references to name `AGENTS.md` as the canonical multi-tool source (Codex, Claude Code, and GitHub Copilot), with `CLAUDE.md` mentioned separately for Claude-only additions — remove every `.github/copilot-instructions.md` mention, no fallback retained:
   - `skills/smaqit.session-start/SKILL.md:17`
   - `skills/smaqit.project-diagnose/SKILL.md:22` and `:184`
   - `skills/smaqit.project-recap/SKILL.md:27`
   - `skills/smaqit.project-recap/references/OUTPUT_FORMAT.md:212`
   - `skills/smaqit.project-research/SKILL.md:39`
   - `skills/smaqit.test-create/SKILL.md:28` and `:38`
4. Update `README.md`'s topology description and `.smaqit/compendium.md`'s "How does `smaqit.project-init` synchronize instructions across tools?" entry to describe the new two-file topology and the removal of the symlink.
5. Add a new function in `installer/main.go` (e.g. `installBaselineWorkspace(targetDir string)`), called from `scaffoldProject` alongside `installReleaseWorkflow`, reusing the existing `writeFileIfMissing` helper:
   - Skip entirely if any `*.code-workspace` file already exists at `targetDir` (maxdepth 1) — never overwrite a project's own workspace file.
   - Otherwise write `<basename(targetDir)>.code-workspace` with exactly: `{"folders":[{"name":"main","path":"."}],"settings":{"files.exclude":{"**/bin/**":true,"**/obj/**":true}}}` — this shape matches `skills/smaqit.utils.worktree/scripts/7_build_workspace.sh`'s output for the zero-worktree case, so a later `task-start` regenerating the file recognizes the existing `main` entry and `files.exclude` block cleanly.
6. Update `README.md`'s "What Gets Installed" / "Running `smaqit-extensions init`" list and `installer/main.go`'s `printHelp()` scaffolding bullets to mention the baseline workspace file.
7. Add assertions to `scripts/smoke-test-installer.sh` mirroring the existing release-workflow pattern (~line 104-109): confirm the baseline workspace file is created with the correct content on a fresh `init`, and confirm it is left untouched (idempotent) when one already exists with custom content.
8. Run `make sync`, `make test`, `make smoke-test`. Add a `CHANGELOG.md` entry describing both the topology change and the new workspace scaffolding.
9. Live-verify: run the built binary's `init` in a scratch directory and inspect the resulting `.code-workspace` (no `copilot-instructions.md` created); separately invoke the `smaqit.project-init` skill against a scratch project seeded with a legacy `.github/copilot-instructions.md` containing sentinel content, and confirm the sentinel content is migrated into `AGENTS.md` and the legacy file is deleted.

## Known Issues Triage
**Triaged:** 2026-09-13
**Tools searched:** Go, GitHub Copilot, Claude Code, Visual Studio Code
**Result:** Advisory

### Blocking Issues
None.

### Advisory Issues
- [#66559 [BUG] Claude refuses to write CLAUDE.md when it's a symlink](https://github.com/anthropics/claude-code/issues/66559) — `anthropics/claude-code` — opened 2026-06-09 — bug, documentation, has repro, api:bedrock, platform:linux, area:tools, area:security, reproduced — tangential: confirms Claude Code's known difficulty writing through a symlinked instruction file (the same risk class that motivated dropping the `.github/copilot-instructions.md` symlink here), but this task creates no new symlink and never touches `CLAUDE.md`'s own file type, so it does not block implementation.
- [#89461 [BUG] Symlinked @import is refused as external but the approval dialog never appears](https://github.com/anthropics/claude-code/issues/89461) — `anthropics/claude-code` — opened 2026-08-25 — bug, has repro, platform:linux, area:core — tangential: about a symlinked `@import` target; this task's `CLAUDE.md` imports a regular-file `AGENTS.md`, so it is unaffected but worth being aware of.

### Historical (Closed)
- [#84830 [Feature Request] Move agentic instructions from CLAUDE.md to vendor-agnostic AGENTS.md](https://github.com/anthropics/claude-code/issues/84830) — `anthropics/claude-code` — closed 2026-08-17 — corroborates the industry direction behind this task's design decision (AGENTS.md as the shared canonical file).

### Unresolvable Tools
None.

### Omitted Tools
None — 4 repositories resolved, within the 5-repository limit.

### Search Warnings
None.

## Acceptance Criteria

- [ ] `AGENTS.template.md`'s `# Scaffolding` section no longer force-injects the Desktop Linux SSH Agent Recovery paragraph or the 11-item scope-project-only path list into every downstream project's canonical `AGENTS.md`
- [ ] `smaqit.project-init`'s synchronized topology is `AGENTS.md` (canonical, read natively by Codex, Claude Code, and GitHub Copilot) + `CLAUDE.md` only — no `.github/copilot-instructions.md` symlink is ever created
- [ ] A project with a pre-existing `.github/copilot-instructions.md` (regular file or symlink) has its unique content migrated into `AGENTS.md` and the now-redundant file deleted
- [ ] `README.md` and `.smaqit/compendium.md` describe the new two-file topology, with no remaining reference to the copilot-instructions.md symlink as current behavior
- [ ] No file in the repository references `.github/copilot-instructions.md` as an instruction source — including the 6 secondary skills' probe hints — with no legacy fallback retained anywhere
- [ ] `smaqit-extensions init` (`scaffoldProject`) creates a baseline `<project-basename>.code-workspace` (main folder + bin/obj `files.exclude`) when none already exists, and never overwrites an existing one
- [ ] `make test` and `make smoke-test` pass, including new assertions for the baseline workspace file (creation + idempotency)
- [ ] `CHANGELOG.md` records both the topology change and the new workspace scaffolding

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
| `skills/smaqit.project-init/references/AGENTS.template.md` | Modify — trim Scaffolding section |
| `skills/smaqit.project-init/SKILL.md` | Modify — topology, Steps 3/8, Requirements |
| `skills/smaqit.session-start/SKILL.md` | Modify — instruction-probe reference |
| `skills/smaqit.project-diagnose/SKILL.md` | Modify — 2 instruction-probe references |
| `skills/smaqit.project-recap/SKILL.md` | Modify — instruction-probe reference |
| `skills/smaqit.project-recap/references/OUTPUT_FORMAT.md` | Modify — reference table row |
| `skills/smaqit.project-research/SKILL.md` | Modify — instruction-probe reference |
| `skills/smaqit.test-create/SKILL.md` | Modify — 2 instruction-probe references |
| `README.md` | Modify — topology section, What Gets Installed list |
| `.smaqit/compendium.md` | Modify — synchronization Q&A entry |
| `installer/main.go` | Modify — add `installBaselineWorkspace`, call from `scaffoldProject`, update `printHelp()` |
| `scripts/smoke-test-installer.sh` | Modify — new baseline-workspace assertions |
| `CHANGELOG.md` | Modify — release note |

## Notes

- Discovery already performed this session (no need to re-derive): `writeFileIfMissing` is the existing create-if-absent helper used by `installReleaseWorkflow` (`installer/main.go` ~line 257) — reuse it for the new workspace function. `7_build_workspace.sh` (`skills/smaqit.utils.worktree/scripts/`) is the authoritative reference for the exact `.code-workspace` JSON shape; it reuses an existing `*.code-workspace` file if one is present rather than assuming a fixed name.
- The 6 secondary skills' instruction-probe lists are read-only discovery hints, not the `project-init` synchronization contract itself — they need the same topology update for consistency, but are otherwise unaffected by the migration-then-delete logic in Step 8 of `project-init`.
