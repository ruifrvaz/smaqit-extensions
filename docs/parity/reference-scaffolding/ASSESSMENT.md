# Reference Scaffolding Parity Assessment

Source: comparison implementation
Studied: 2026-07-26 · base `4fcc32b`

## What the comparison scaffolding is

This assessment covers the smaqit developer-workflow layer embedded in the comparison implementation, not its application domain. It is a Copilot-first parallel implementation containing task/session/release/test skills, task-isolated Git worktrees, a generated VS Code multi-root workspace, an agent-and-skill authoring compiler, and a larger specification-driven agent suite.

The domains are compatible: both implementations automate agent-assisted software delivery around `.smaqit` task and session state. The comparison is therefore a valid feature source, but not a safe drop-in replacement for the base project.

Key properties:

- **Inventory** — the comparison has 43 `.github/skills` and 13 `.github/agents`; the base has 28 skills and 3 agents.
- **Shared surface** — 26 skills and all 3 base agents have name-level counterparts. Only 7 shared skills are byte-identical; 19 skills and all 3 agents have drifted.
- **Comparison-only surface** — 17 skills and 10 agents, including worktree management, agent/skill compilation, specification-layer agents, input gates, and application-specific tools.
- **Distribution model** — the comparison edits installed Copilot artifacts directly. The base owns canonical `agents/` and `skills/`, then compiles Copilot, Claude Code, and Codex outputs.
- **Task isolation model** — the comparison creates `task/NNN-title` branches, sibling worktrees, and entries in `<project>.code-workspace`.

---

## Structural Mapping

| Concept | Comparison implementation | Base equivalent | Mapping quality |
|---------|----------------------|-----------------|-----------------|
| Task and session state | `.smaqit/tasks`, `PLANNING.md`, history files | Same file-based model | 1:1 |
| Task start | `smaqit.task-start` creates a branch and delegates worktree creation | `smaqit.task-start` changes task state and begins implementation in the current checkout | partial |
| Task completion | `smaqit.task-complete` attempts merge, branch deletion, orphan cleanup, and workspace regeneration | `smaqit.task-complete` verifies and records completion without Git topology management | partial |
| Worktree lifecycle | `smaqit.utils.worktree` plus eight shell scripts | None | absent |
| Editor workspace | Generated `<project>.code-workspace` containing main and active worktrees | None | absent |
| Copilot session migration | Script copies VS Code chat files and mutates `state.vscdb` | None | absent |
| Agent/skill authoring | `smaqit.create-agent`, `smaqit.create-skill`, `smaqit.L2`, compilation templates and rules | Build-time Python generator for already-authored canonical sources | partial |
| Specification workflow | Business, Functional, Stack, Infrastructure, Coverage, Development, Deployment, and Validation agents with input gates | None in this repository | absent |
| Testing adapters | Expanded browser tools and application-specific telemetry-dashboard verification | Stack-agnostic playbook discovery and generic live-service E2E | partial |
| Source/distribution architecture | Copilot artifacts maintained directly in `.github` | Canonical sources compiled into Copilot, Claude Code, and Codex targets | different |
| Project diagnosis | None | `smaqit.project-diagnose` | a-only |
| Untracked-work reconciliation | None | `smaqit.task-refresh` | a-only |

---

## Relationship Options

### Option A — Copy the comparison `.github` implementation into the base

Copy the comparison agents, skills, and scripts, then adapt names and paths after the fact.

**Pros:**

- Fastest way to expose the visible worktree commands.
- Preserves behavior familiar to the comparison workspace.

**Cons:**

- Regresses newer base behavior in project initialization, session handling, testing, release safety, tool-neutral memory handling, and multi-platform support.
- Bypasses the base's canonical-source and generation architecture.
- Imports project-specific paths, telemetry rules, and Copilot tool names.
- Imports destructive and currently broken lifecycle behavior.

**Verdict:** Reject. The two trees cannot be safely reconciled by directory copy or by choosing the higher version number.

### Option B — Selective native port into the base

Treat the comparison as a behavior prototype. Reimplement the reusable capabilities in canonical base sources, preserve all newer base contracts, compile platform-specific outputs through `scripts/generate-targets.py`, and add integration tests around temporary repositories.

**Pros:**

- Retains the base's three-platform distribution and current safeguards.
- Allows the worktree lifecycle to be redesigned around Git's actual constraints.
- Separates generic Git isolation from optional VS Code integration.
- Provides a migration path for other innovations without importing application-specific assumptions.

**Cons:**

- More work than copying files.
- Requires explicit configuration and lifecycle decisions.
- Needs end-to-end Git tests before task skills can depend on it.

**Verdict:** Recommended. This is the only path that merges value without treating either implementation as wholly authoritative.

### Option C — Optional workflow packs

Port the specification agents, input gates, compiler templates, and domain authoring tools as an optional smaqit workflow pack or plugin rather than part of the always-installed core.

**Pros:**

- Preserves the richer specification workflow for users who need it.
- Avoids expanding every installation from 3 agents to 13 agents.
- Keeps `smaqit-extensions` focused while permitting a broader smaQit authoring experience.

**Cons:**

- Requires a packaging and dependency model.
- The comparison compiler targets direct `.github` output and must be redesigned for canonical multi-platform sources.
- Some agents refer to the separate smaQit framework and CLI, so ownership boundaries need clarification.

**Verdict:** Good follow-on direction, but separate from the worktree convergence.

---

## Recommendation

**Option B — Selective native port, followed by Option C for optional workflow packs**

Make worktree-backed task execution the first convergence feature, but rebuild it as a generic, tested capability rather than importing the comparison scripts.

Rationale:

1. The feature has demonstrated practical value: the comparison currently has ten task worktrees represented in one multi-root workspace.
2. The base architecture is the stronger distribution foundation: canonical sources, generated platform variants, installer embedding, synchronization checks, and an end-to-end smoke test.
3. The comparison task lifecycle is an untested prototype. Its session history leaves end-to-end task-start → worktree → task-complete → cleanup validation as a next step.
4. Most shared comparison files are older or more product-specific than their base counterparts. Version numbers alone are misleading because development continued independently.
5. The authoring/compiler and layered specification suite are valuable, but they change product scope and should not block the smaller worktree convergence.

### Critical constraints for the worktree port

The current comparison implementation should be used as a requirements source, not copied:

1. **Completion ordering is invalid for linked worktrees.** `task-complete` checks out `main` without targeting the primary worktree, then tries to delete a branch that is still checked out by its task worktree. Git normally rejects both operations.
2. **Orphan detection does not actually test branch existence.** `git branch --list <name>` exits successfully even when it prints nothing, so the current condition cannot reliably detect a missing branch.
3. **Stale-directory cleanup is destructive.** `5_create_worktrees.sh` runs `rm -rf` on an unregistered target directory without proving it is disposable or clean.
4. **Paths depend on the caller's current directory.** Worktrees are created at `../<slug>` rather than at a path resolved from the primary repository root.
5. **Workspace generation overwrites user configuration.** It replaces the complete workspace document, drops custom settings and non-worktree folders, and selects the first workspace file when several exist.
6. **The implementation is project- and platform-bound.** Project names are hardcoded; scripts assume Bash, `jq`, GNU `realpath`, Linux VS Code storage, and Copilot-specific tools.
7. **Cross-worktree task state is underspecified.** The skills do not clearly define whether task files and `PLANNING.md` are control-plane state on `main` or branch-local state in a task worktree.
8. **Session migration touches private editor state.** It copies internal chat files and updates VS Code SQLite keys without a backup/restore contract or editor-version compatibility boundary.
9. **Several shared-skill changes are regressions.** They restore mandatory non-portable memory tools, broken relative links, Copilot-only instructions, and older project-init/test-create behavior.
10. **There are no automated worktree lifecycle tests.** Historical manual success is useful evidence, but insufficient for installer-wide adoption.
11. **The documented workspace contract and script disagree.** The skill says generated workspace settings hide smaqit scaffolding, while `7_build_workspace.sh` currently writes only `bin` and `obj` exclusions.

### Target design

- Add a generic worktree engine that resolves the primary worktree, default branch, common Git directory, and task worktree from Git itself.
- Make worktree mode explicitly configurable per project; do not silently change existing task workflows after installation.
- Keep task coordination state and implementation state deliberately separated. Every step must name whether it writes to the primary worktree or the task worktree.
- On completion: verify/commit task worktree changes, merge from the primary worktree, remove the task worktree safely, then delete the fully merged branch.
- Refuse cleanup when a worktree is dirty, locked, outside the managed naming scheme, or not proven to belong to the selected task.
- Implement `--dry-run`/preview output for creation, cleanup, and workspace changes.
- Preserve existing workspace folders, settings, and extensions; update only entries proven to correspond to managed Git worktrees.
- Keep VS Code session migration a separate experimental, opt-in, Linux/Copilot operation with backup and restore—not part of task completion.
- Use canonical `skills/` sources, version bumps, generator placeholders, `make sync`, and installer smoke coverage.

---

## Parity Roadmap

| Priority | Feature | Comparison source | Base task / component | Status | Benefit |
|----------|---------|-----------------|-----------------------|--------|---------|
| 1 | Define task isolation and control-plane contract | `.github/skills/smaqit.task-start`, `.github/skills/smaqit.task-complete` | New focused task; do not overload Task 017 | design required | Prevents planning-state and merge ambiguity |
| 2 | Generic safe worktree engine | `.github/skills/smaqit.utils.worktree` and scripts 1–7 | New canonical `skills/smaqit.utils.worktree` | redesign required | Parallel task isolation across supported agents |
| 3 | Temporary-repository integration tests | No equivalent | Installer/skill test harness | missing | Proves create, resume, complete, conflict, and dirty-tree behavior |
| 4 | Worktree-aware `task-start` | `smaqit.task-start` v0.8.0 | Merge into current base v0.7.0 semantics | partial prototype | Deterministic branch and execution location |
| 5 | Worktree-aware `task-complete` | `smaqit.task-complete` v0.7.0 | Merge into current base v0.6.0 semantics | broken prototype | Safe merge and cleanup lifecycle |
| 6 | Non-destructive VS Code workspace adapter | `7_build_workspace.sh` | Optional adapter in worktree skill | partial prototype | One Explorer view for concurrent tasks |
| 7 | Browser-capable generic user testing | User-testing agent and `test-start` telemetry extension | Agent frontmatter plus project-discovered verification adapters | partial | Better UI and observability evidence without fixed application assumptions |
| 8 | Agent/skill authoring workflow | `smaqit.create-agent`, `smaqit.create-skill`, `smaqit.L2` | Future authoring pack using canonical generators | incompatible prototype | Makes extension creation a supported workflow |
| 9 | Specification-agent suite | Ten additional smaqit agents and eight input gates | Optional plugin/workflow pack | scope decision required | Restores full specification-to-validation workflow |
| 10 | VS Code session migration | `8_migrate_sessions.sh` | Separate experimental utility | defer | Preserves chats when changing workspace identity |

---

## Project A Advantages

| Base capability | Comparison equivalent |
|-----------------|------------------|
| Canonical agent/skill sources compiled for Copilot, Claude Code, and Codex | Direct Copilot artifacts with a partial `.agents` mirror |
| Platform-aware agent metadata and skill placeholders | Copilot-specific frontmatter and tool references |
| Cross-platform `project-init` with canonical `AGENTS.md` synchronization | Older Copilot-only initializer that aborts on an existing instruction file |
| Stack-agnostic test playbook discovery | Application-specific .NET, systemd, Discord, and telemetry assumptions |
| Optional, tool-neutral persistent-memory language | Mandatory environment-specific `memory` and `store_memory` calls |
| `smaqit.project-diagnose` | None |
| `smaqit.task-refresh` | None |
| Session-finish in-progress-task gate | Older session-finish without the gate |
| Compendium current-state rules | Older compendium behavior plus a duplicate legacy `smaqit.compendium` skill |
| Desktop SSH-agent recovery for authorized release operations | None |
| Installer smoke test covering all generated platform trees | No worktree lifecycle or distribution-level test |

## Features that should not be upstreamed directly

- Product-specific abilities, workflow creation, refactoring, and model-benchmark skills: retain outside the base or extract only after removing runtime assumptions.
- Fixed telemetry ports, orchestrator component rules, Discord/WebSocket fallbacks, and application service commands: convert to project-discovered verification adapters instead.
- The duplicate `smaqit.compendium` skill: consolidate on `smaqit.project-compendium`.
- Global "approval before every file change" instructions: they conflict with smaqit's explicit autonomous task mode.
- Direct edits to `.github/agents` or `.github/skills`: the base generator must remain the source of installed artifacts.
