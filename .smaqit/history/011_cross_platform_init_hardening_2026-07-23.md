# Cross-Platform Init Hardening

**Date:** 2026-07-23  
**Session focus:** Codex compatibility, installer/update resilience, cross-platform project initialization, and releases  
**Tasks completed:** 015 — Synchronize Project Instructions in Project Init  
**Tasks referenced:** 013 — Platform-Aware Agent Frontmatter and Skill Content

## Actions Taken

- Loaded the project context and assessed how Codex compatibility should fit the existing Copilot and Claude Code generation architecture.
- Added Codex as a third installer target: custom agents compile to `.codex/agents/*.toml`, skills install to `.agents/skills/`, and root `agents/`/`skills/` remain canonical sources.
- Added Codex dogfooding mirrors, platform substitution checks, and a disposable local-installer smoke test, then published v1.6.0.
- Confirmed and fixed the self-update stale-embed defect by making the replaced executable launch a fresh process for project reinitialization, then published v1.6.1.
- Diagnosed WSL2 SSH-agent inheritance, demonstrated command-scoped GCR access that permits a desktop unlock prompt, assessed key-exposure risk, and broadened recovery guidance across WSL2/WSLg, Ubuntu/GNOME, XFCE, GnuPG, and OpenSSH.
- Reproduced an accidental installation under `areaoffice-poc/scripts`, identified invocation from the nested directory as the cause, and made bare `init`, `update`, and `uninstall` resolve the enclosing Git root or nearest `.smaqit` ancestor.
- Planned, created, started, implemented, verified, and completed Task 015. `smaqit.project-init` now inferentially reads all existing project-instruction sources and synchronizes them around canonical root `AGENTS.md`.
- Exercised project initialization in isolated model-driven fixtures covering fresh creation, populated-file migration, Copilot symlink conversion, conflict safety, and a hash-stable second run.
- Ran the local release agent for v1.7.0, organized four source commits plus a release commit, unlocked WSL2 GCR without persisting environment changes, pushed the branch and tag, and verified five published release binaries.
- Reconciled concurrent post-release work discovered during session finish: Task 015 completion and a stack-agnostic `smaqit.test-create` fix were committed separately and published as v1.7.1 without overwriting the session artifacts.

## Problems Solved

- **Missing Codex installation target:** Added generated Codex agent metadata and skill installation while preserving the repository's single-source architecture.
- **Successful update omitted new embedded files:** Replaced stale in-process reinitialization with execution by the newly installed binary image.
- **Release automation could not reach desktop SSH credentials:** Added constrained socket discovery and one command-scoped retry so existing key stores can display their normal unlock or confirmation UI.
- **Nested CLI invocation created scaffolding in `scripts/`:** Added project-root discovery with Git precedence over accidental nested `.smaqit` directories.
- **Project initialization aborted when instructions already existed:** Replaced the hard guard with model-inferred preservation, deduplication, conflict handling, and synchronized output.
- **Platform instruction files could drift:** Established `AGENTS.md` as canonical, a Claude import wrapper, and a Copilot relative symlink.
- **Release workflow queue delay:** Waited through a GitHub Actions hosted-runner degradation and verified the existing tag-triggered workflow instead of creating a duplicate manual release.

## Decisions Made

- Root `agents/` and `skills/` are authoritative; generated installer trees are ephemeral embed inputs, while `.github/`, `.codex/`, and `.agents/` are dogfooding mirrors.
- A self-update that replaces the executable must use a fresh process for embedded assets; no-replacement paths may remain in-process.
- SSH recovery may use only an already-running agent, only through a command-scoped `SSH_AUTH_SOCK`, and only for the exact authorized Git operation. It must never persist the socket, manipulate identities, or broaden access.
- Implicit CLI commands prefer the enclosing Git root, then the nearest `.smaqit` ancestor; an explicit target remains exact.
- Project instructions are synchronized through inference rather than a deterministic text merger. Existing explicit rules outrank inferred facts, and irreconcilable conflicts require user direction before writing.
- `AGENTS.md` is the canonical instruction source. `CLAUDE.md` imports it with `@AGENTS.md` and retains Claude-only additions; `.github/copilot-instructions.md` links to `../AGENTS.md` after its prior unique content is preserved.
- The known Claude Code ancestor-import limitation was accepted with a project-root launch warning rather than abandoning the single-source topology.

## Files Modified

- **Installer and generation:** `.gitignore`, root `Makefile`, `installer/Makefile`, `installer/main.go`, `installer/main_test.go`, `scripts/generate-targets.py`, and `scripts/smoke-test-installer.sh`.
- **Release automation:** `agents/smaqit.release.local.agent.md`, `agents/smaqit.release.pr.agent.md`, `.smaqit/definitions/agents/*.frontmatter.yaml`, `skills/smaqit.release-git-local/SKILL.md`, `skills/smaqit.release-git-pr/SKILL.md`, and their generated platform mirrors.
- **Project initialization and context skills:** `skills/smaqit.project-init/SKILL.md`, `skills/smaqit.project-diagnose/SKILL.md`, `skills/smaqit.project-recap/**`, `skills/smaqit.project-research/**`, `skills/smaqit.session-start/SKILL.md`, `.smaqit/templates/copilot-instructions.template.md`, and installer template copies.
- **Platform outputs:** `.github/agents/*`, `.github/skills/*`, `.codex/agents/*`, and the complete `.agents/skills/*` Codex dogfooding tree.
- **Continuous integration:** `.github/workflows/test-integration.yml` and `.github/workflows/test-sync.yml`.
- **Documentation and state:** `README.md`, `CHANGELOG.md`, `.smaqit/compendium.md`, `.smaqit/references/project-research.md`, `.smaqit/tasks/015_synchronize_project_instructions_in_project_init.md`, `.smaqit/tasks/PLANNING.md`, and session history entries 009–011.

## Next Steps

- Commit the compendium refresh and this history entry; Task 015 completion is already committed in v1.7.1.
- Decide whether the task-refresh candidates for Codex installation, self-update re-execution, SSH recovery, implicit project-root detection, and the stack-agnostic test-create fix should receive retroactive completed tasks.
- Monitor upstream Claude Code ancestor-import behavior and remove or revise the root-launch warning when the limitation is resolved.
- Continue the existing backlog: Tasks 002, 007, and 010 remain Not Started.

## Session Metrics

- **Duration:** 2026-07-21 through 2026-07-23 (3 calendar days)
- **Releases published:** 4 (`v1.6.0`, `v1.6.1`, `v1.7.0`, `v1.7.1`)
- **Commits across the release arc:** 17
- **Changed paths from v1.5.0 to v1.7.1:** 106
- **Tasks completed:** 1 (Task 015)
- **Installed platform coverage:** 3 agents and 28 skills across Copilot, Claude Code, and Codex
- **v1.7.0 release assets:** 5 platform binaries
- **Validation:** generation checks, installer unit tests, full smoke tests, Go vet, ShellCheck, whitespace checks, and model-mediated project-init fixtures
