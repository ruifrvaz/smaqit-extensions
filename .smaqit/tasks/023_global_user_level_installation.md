---
status: Completed
mode: Assisted
created: "2026-08-10"
started: "2026-08-10"
completed: "2026-08-10"
---

# Global User-Level Installation with Agent-Specific Adapters

## Description

Replace the current project-only `init` command with a new `install` subcommand that defaults to user-global installation. Agents deploy to platform-specific global paths (`~/.copilot/agents/`, `~/.claude/agents/`, `~/.codex/agents/`), while skills are shared where possible (`~/.agents/skills/` for Copilot+Codex, `~/.claude/skills/` for Claude). A `--scope project` flag preserves existing per-project behavior. Environment variables (`COPILOT_HOME`, `CLAUDE_CONFIG_DIR`, `CODEX_HOME`) override default paths.

Currently, `smaqit-extensions init` installs everything into the detected project root, which means agents and skills must be reinstalled in every project. Updates to the binary also require re-initializing every project individually. Moving agents and skills to global user-level paths eliminates redundant per-project reinstalls, makes `update` a single global operation, and means `init` only scaffolds project-local state (`.smaqit/` tasks, history, templates, workflows).

## Design Decisions

- **`~/.copilot/agents/` for Copilot agents** — documented Copilot CLI path, separate from the shared `~/.agents/skills/` skill directory.
- **`skills-codex/` embed retired** — Codex and Copilot share identical skill content at `~/.agents/skills/`. Building and embedding a third identical tree is waste. The `generate-targets.py` generator stops producing the separate `skills-codex/` output tree.
- **`[SMAQIT_SKILLS_DIR]` resolves to global paths at build time** — documentation-only reference. `~/.agents/skills` is the canonical value; actual install-time path may differ via env overrides, but the doc reference is stable.
- **`init` preserved as deprecated alias** — delegates to `install --scope project` with a deprecation notice. Avoids breaking existing workflows and documentation.
- **`.smaqit/` scaffolding stays per-project** — tasks, history, templates, and the release workflow are inherently project-local. Only agents and skills move to global.
- **Skills always installed, not gated by `--agent`** — skills are shared infrastructure. A user filtering `--agent copilot` still needs the skill suite available. The `--agent` flag gates only agent files.
- **Agent conversion handled by existing `generate-targets.py` pipeline** — Claude+Copilot share Markdown/YAML frontmatter (generated from the same `agents/*.agent.md` body + per-platform frontmatter), Codex gets TOML. No new manifest format needed for this task.

## Implementation Steps

### Phase 1 — Refactor destination logic in `installer/main.go`

1. Add `resolveGlobalDir(agent string)` function respecting environment variable overrides:
   - `COPILOT_HOME` → `$HOME/.copilot`
   - `CLAUDE_CONFIG_DIR` → `$HOME/.claude`
   - `CODEX_HOME` → `$HOME/.codex`
   - Skills shared dir: `$HOME/.agents/skills` (no env override; both Copilot and Codex discover it here)

2. Split current `cmdInstall` into two paths:
   - `installGlobal(agents []string)` — copies embedded trees to global user paths. Skills always installed. Agents gated by `--agent` flag.
   - `installProject(targetDir string, agents []string)` — current `cmdInstall` behavior, gated by `--agent` flag. Still scaffolds `.smaqit/` and deploys `.github/workflows/post-merge-release.yml`.

3. Implement the new `install` subcommand with flag parsing:
   - `--agent codex|claude|copilot|all` (default: `all`)
   - `--scope user|project` (default: `user`)
   - `smaqit-extensions install` (no args) → `--agent all --scope user`

4. Update destination mapping for global installs:
   - `agents-copilot/*.agent.md` → `~/.copilot/agents/` (was `.github/agents/`)
   - `agents-claude/*.md` → `~/.claude/agents/` (unchanged path, now global)
   - `agents-codex/*.toml` → `~/.codex/agents/` (unchanged path, now global)
   - `skills/*` → `~/.agents/skills/` (was `.github/skills/`; now also serves Codex)
   - `skills-claude/*` → `~/.claude/skills/` (unchanged path, now global)

### Phase 2 — Simplify skill trees (Codex shares Copilot skills)

5. Remove `skillFilesCodex` embed directive from `installer/main.go` and its install/uninstall paths.

6. Update `scripts/generate-targets.py`:
   - `SKILLS_DIR_BY_PLATFORM`: `copilot` → `~/.agents/skills`, `codex` → `~/.agents/skills` (same value)
   - Retire `skills-codex/` output tree from the generator

7. Remove `skills-codex/` references from `installer/Makefile` prepare step.

### Phase 3 — Update remaining commands

8. `update`: refresh the global installation (not a project). After binary replacement, run `installGlobal` with `--agent all`. Still re-scaffold `.smaqit/` templates in the current directory if `.smaqit/` is present (create-if-absent for templates only).

9. `uninstall`: remove from global paths by default. Accept `--scope project` to remove from a project directory (current behavior). Accept `--agent` to selectively uninstall.

10. Keep `init` as backward-compatible alias: `smaqit-extensions init` → prints deprecation notice, delegates to `install --scope project`. `smaqit-extensions init <dir>` → `install --scope project <dir>`.

### Phase 4 — Update tests, docs, and build

11. Update `scripts/smoke-test-installer.sh`: test `install` (global, default), `install --agent copilot`, `install --scope project`, `install --agent codex --scope project`. Verify global paths resolve correctly. Assert `skills-codex/` is no longer installed separately.

12. Update `installer/main_test.go`: add tests for `resolveGlobalDir`, `--agent` filtering, `--scope` routing, and environment variable overrides.

13. Update `printHelp()` to document the new `install` subcommand and flag interface.

14. Update `README.md` "Installation" and "What Gets Installed" sections. Update `install.sh` if needed.

## Known Issues Triage

**Result:** Clear — No third-party tools with relevant blocking issues identified.

This task modifies internal smaqit-extensions installer code only (Go CLI, Python generator script, bash smoke test). The foundational platforms used (Go stdlib, Python, bash) have no open bugs or regressions that would block adding a new CLI subcommand and changing file paths.

## Acceptance Criteria

- [x] `smaqit-extensions install` (no args) installs all agents to global paths and skills to `~/.agents/skills/` and `~/.claude/skills/`
- [x] `smaqit-extensions install --agent copilot` installs only Copilot agents + skills (not Claude or Codex agents)
- [x] `smaqit-extensions install --agent all --scope project` matches current `init` behavior exactly
- [x] `COPILOT_HOME`, `CLAUDE_CONFIG_DIR`, `CODEX_HOME` environment variables override default global paths
- [x] `skills-codex/` embed is retired; Codex reads from the same `~/.agents/skills/` as Copilot
- [x] `smaqit-extensions init` prints deprecation notice and delegates to `install --scope project`
- [x] `smaqit-extensions update` refreshes global install + re-scaffolds `.smaqit/` templates if present
- [x] `smaqit-extensions uninstall` removes from global paths by default
- [x] `make smoke-test` passes with new global path assertions
- [x] `make -C installer test` passes with new unit tests for flag routing and env overrides

## Findings

**Implementation approach:**
- Added `resolveGlobalDir`, `parseAgentFilter`, `parseScope`, `parsePositionalDir` helpers to `installer/main.go`
- Split old `cmdInstall` into `installGlobal` (user-level paths) and `installProject` (`--scope project`)
- Implemented `install` subcommand; kept `init` as deprecated alias; updated `update`/`uninstall`/`checkAndReInit` flows
- Removed `skillFilesCodex` embed; Codex/Copilot share the same `skills/` tree at `~/.agents/skills/`
- Updated `generate-targets.py` SKILLS_DIR_BY_PLATFORM to global paths, retired `skills-codex/` output
- Updated smoke-test, unit tests, README, install.sh, agent source, compendium, template, and 4 skill files

**Decisions made:**
- `--agent` flag gates only agent files; skills always installed (shared infrastructure)
- `~/.copilot/agents/` for Copilot agents (documented CLI path, separate from `~/.agents/skills/`)
- `[SMAQIT_SKILLS_DIR]` resolves to global paths at build time; `skills-codex/` tree retired
- `init` deprecated alias prints warning and delegates; backward compatibility preserved
- Flag parsing uses explicit index-based scan (`parsePositionalDir`) — a `range` loop bug was caught and fixed during review (Go `for i, a := range ... { i++; continue }` does not skip the next iteration)
- Sparse-checkout documentation corrected: under default global install, consumer projects have none of `.github/agents/`, `.claude/`, `.codex/`, `.agents/skills/` — agents/skills live entirely outside the repo

**Blockers encountered:**
- Branch name mismatch between task-title slug (`...adapters`) and created branch (`...adapter`) blocked resolver — fixed by renaming branch to match title-derived slug

**Follow-up identified:**
- Root `templates/copilot-instructions.template.md` appears orphaned (last touched May 2026, not referenced by any script or skill) — candidate for removal
- Dogfooding mirrors (`.github/skills/`, `.claude/skills/`, `.agents/skills/` at repo root) still reference pre-global `[SMAQIT_SKILLS_DIR]` values — need `make sync` after merge to regenerate with updated generator output

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
| `installer/main.go` | Modify — new `install` subcommand, `resolveGlobalDir`, `installGlobal`, refactored `installProject`, `update`/`uninstall`/`printHelp`, remove `skillFilesCodex` embed |
| `installer/main_test.go` | Modify — new tests for global path resolution, `--agent`/`--scope` flags, env var overrides |
| `scripts/generate-targets.py` | Modify — updated `SKILLS_DIR_BY_PLATFORM`, retire `skills-codex/` output |
| `scripts/smoke-test-installer.sh` | Modify — test global install paths, `--agent` filtering, verify `skills-codex/` absent |
| `installer/Makefile` | Modify — remove `skills-codex/` from prepare |
| `README.md` | Modify — document `install` command, global paths, `--agent`/`--scope` flags |

## Notes

- The `[SMAQIT_SKILLS_DIR]` placeholder resolved by `generate-targets.py` changes from `.github/skills` → `~/.agents/skills` for Copilot and from `.agents/skills` → `~/.agents/skills` for Codex. Claude stays at `.claude/skills` → `~/.claude/skills` (semantically the same).
- The `install.sh` curl-pipe script likely needs no changes — it only downloads the binary to `~/.local/bin`. The user then runs `smaqit-extensions install` separately.
- Dogfooding mirrors (`.github/skills/`, `.agents/skills/`, `.claude/skills/` in the repo root) are unaffected — they serve this repository's own development, not consumer installations.
- `make sync` continues to produce the same `.github/`, `.codex/`, `.agents/`, and `.claude/` mirrors for dogfooding. The generator changes only affect what the installer embeds.
