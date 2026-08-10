# Global Installer Migration

**Date:** 2026-08-10
**Session focus:** Planning, implementing, releasing, and qualifying the migration from per-project to global user-level installation for smaqit-extensions; creating propagation tasks for sibling projects
**Tasks completed:** 023 — Global User-Level Installation with Agent-Specific Adapters
**Tasks referenced:** 002, 007, 010 (untouched); smaqit 105, smaqit-adk 027 (created as propagation tasks)

## Actions Taken

- Started session with `smaqit.session-start`, loaded full project context — 3 open tasks (002, 007, 010), all Not Started.
- Planned Task 023 via `smaqit.task-plan` (Mode A): assessed complexity, resolved design gaps through Q&A with user, aligned on global paths (`~/.copilot/agents/`, `~/.claude/`, `~/.codex/agents/`, `~/.agents/skills/` for Copilot+Codex shared skills).
- Started Task 023 (Assisted mode): created branch `task/023-global-user-level-installation-with-agent-specific-adapters`, sibling worktree, ran issue triage (Clear — no upstream blocking issues).
- Implemented the core design across 16 files: new `install` subcommand with `--agent`/`--scope` flags, `resolveGlobalDir` with `COPILOT_HOME`/`CLAUDE_CONFIG_DIR`/`CODEX_HOME` overrides, retired `skills-codex/` embed, updated `generate-targets.py` SKILLS_DIR_BY_PLATFORM and retired `skills-codex/` output tree, updated update/uninstall flows, smoke test, unit tests, README, install.sh, agent source, compendium, template, and 4 skill files.
- Mid-implementation: user reported that `init` as deprecated alias for `install --scope project` was wrong — `init` should only scaffold `.smaqit/`, not re-install agents/skills into project. Fixed.
- Review caught flag-parsing bug: Go `for i, a := range args { i++; continue }` does not skip the next iteration. Replaced with `parsePositionalDir()` using explicit index-based scan. Added 6 test cases.
- Uninstall smoke-test step was silently failing: the test called `uninstall` without `--scope project`, defaulting to global scope in a temp project. Fixed smoke test to use `--scope project`.
- Post-review: audited all skills, agents, templates, scripts, Makefile, CHANGELOG, install.sh for stale per-project-path references. Fixed 6 files: `install.sh` final message, `agents/smaqit.release.pr.agent.md`, `README.md` (4 spots), `.smaqit/compendium.md` (3 entries), `skills/smaqit.project-recap/references/OUTPUT_FORMAT.md`.
- Corrected worktree/compendium/template documentation to state plainly that default global install means consumer projects have NO `.github/agents/`, `.claude/`, `.codex/`, `.agents/skills/` — not framed as harmless no-ops the sparse checkout "would" exclude.
- Completed Task 023: committed implementation, merged to main, updated task status and PLANNING.md, removed worktree, deleted branch, updated memory.

## Release Sequence

- **v1.14.0** (PR #118): Released with the full global-install feature. Post-release discovery: `init` (deprecated alias) was delegating to `install --scope project`, installing all agents/skills into project directory — the exact behavior the migration existed to eliminate. Also: `install` subcommand created three competing meanings of "install" (shell script, CLI, legacy init) — confusing UX.
- **v1.14.1** (PR #119): Fixed `init` to scaffold-only. Simplified CLI: removed user-facing `install` subcommand, `install.sh` runs `--install-global` automatically after binary download, `smaqit-extensions` no-args shows help, `smaqit-extensions init` explicitly scaffolds.
- **v1.14.2** (PR #120): Critical fix — `install.sh` referenced `$target` variable out of scope in `main()` (declared `local` inside `install_binary()`/`verify_installation()`), causing `--install-global` to silently fail with "command not found". v1.14.1s
