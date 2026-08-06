# Project Compendium

## Architecture

**How does smaqit-extensions handle content that differs between GitHub Copilot, Claude Code, and Codex?**

Agent bodies (`agents/*.agent.md`) and skill bodies (`skills/*/SKILL.md`) are shared source, reused across all platforms wherever possible. Two mechanisms handle platform variance without duplicating whole files:

- **Per-platform agent metadata**: each agent's `.smaqit/definitions/agents/<name>.frontmatter.yaml` holds `copilot:`, `claude:`, and `codex:` sections. `scripts/generate-targets.py` combines each section with the shared body to produce YAML-frontmatter agents for Copilot and Claude Code plus standalone TOML custom agents for Codex.
- **`{{PLACEHOLDER}}` tokens for genuinely divergent content**: for the small number of skills whose executable behavior differs by platform — such as `smaqit.release-git-pr` using Copilot's `report_progress` mechanism versus direct authenticated Git operations elsewhere — the shared `SKILL.md` contains named `{{TOKEN}}` placeholders resolved from `.smaqit/definitions/skills/<name>.placeholders.yaml`. This isolates only the actual inflection points; everything else stays identical.

Both mechanisms are resolved once, at build time, by `scripts/generate-targets.py`; installed output contains no unresolved build-time tokens. Generated trees under `installer/` are ephemeral embed inputs. Root `.github/` and `.codex/` plus `.agents/` are workspace dogfooding mirrors, never installer sources.

---

**How does `smaqit.project-init` synchronize instructions across tools?**

Every platform receives the same inference-driven `smaqit.project-init` skill. The skill reads any existing `AGENTS.md`, `CLAUDE.md`, and `.github/copilot-instructions.md` together with repository evidence before writing. It semantically preserves and deduplicates explicit rules, keeps smaqit-owned scaffolding current, and asks the user before resolving irreconcilable instructions.

The synchronized topology is:

- Root `AGENTS.md` is the canonical shared instruction document.
- Root `CLAUDE.md` starts with `@AGENTS.md` and contains only genuinely Claude-specific additions.
- `.github/copilot-instructions.md` is a relative symlink to `../AGENTS.md`; distinct content from a pre-existing Copilot file is merged before replacement.

Repeated initialization is expected to be idempotent. Claude Code may fail to resolve an ancestor import when launched from some repository subdirectories, so launch it from the project root if imported instructions are missing.

---

**How does the installer's `[SMAQIT_SKILLS_DIR]` placeholder work?**

A handful of skills reference their own install path in usage comments or example commands (e.g. `smaqit.project-diagnose`, `smaqit.utils.read-pdf`). Since a skill's install root differs by platform (`.github/skills` for Copilot, `.claude/skills` for Claude Code, `.agents/skills` for Codex), any such self-reference is written in source using the literal placeholder `[SMAQIT_SKILLS_DIR]`. `scripts/generate-targets.py` resolves it when compiling each platform's ephemeral installer tree. The root `Makefile` copies from those compiled outputs, so dogfooding mirrors never contain the literal placeholder either.

---

**Does the worktree workflow add a separate installer or CLI command?**

No. Worktree behavior is implemented by the canonical `smaqit.utils.worktree` skill and its eight shell scripts. The normal initializer installs that skill for GitHub Copilot, Claude Code, and Codex alongside the other workflow skills.

`smaqit.task-start` invokes the workflow to create or reuse a task branch, sibling worktree, sparse checkout, and root VS Code workspace. `smaqit.task-complete` invokes its cleanup path after merging. `worktree.sync` and `worktree.migrate-sessions` are skill triggers, not commands in the `smaqit-extensions` binary.

---

**How do sequential child tasks share one feature branch and worktree?**

Create and start a dedicated parent task, then create each sequential child with `task.create ... --parent NNN`. The child records its own status, criteria, and findings in the active parent worktree, inherits the parent mode, and never creates a branch or worktree. Child completion is bookkeeping only. Once every child is completed, the parent performs the single merge, worktree removal, branch deletion, and workspace refresh. Parent relationships are single-level; a child cannot itself own children.

Feature workflows that create a deployment PR before later phases may write files must define their merge and post-merge write semantics before adopting this lifecycle.

---

## Testing

**How can the local installer be tested end to end?**

Run `make smoke-test` from the repository root or `make -C installer smoke-test`. The test builds the current development installer, provisions a unique temporary project, installs every Copilot, Claude Code, Codex, template, and `.smaqit` artifact, compares installed content with the generated embed staging trees, parses Codex agent TOML, checks platform substitutions, runs uninstall, and verifies cleanup. The temporary project is removed automatically; set `KEEP_SMOKE_DIR=1` to retain it for inspection.

---

**What system dependencies does the hermetic test suite (`make test`) require beyond git and jq?**

`tests/skills/test-parent-task-lifecycle.sh` requires `ripgrep` (`rg`) on `PATH` for its content assertions. `.github/workflows/test-integration.yml` installs it explicitly (`apt-get install -y ripgrep`) before running `make smoke-test`; a local dev environment without `rg` installed will fail that suite with `rg: command not found` even though `make -C installer test` and the rest of the installer smoke test pass fine.

---

**How does `smaqit.test-create` derive build, test, deploy, and health-check commands?**

`task.test-create [id]` generates an E2E test playbook for a task under `.smaqit/user-testing/tests/`. Instead of assuming a specific toolchain (.NET, Discord, orchestrator), the skill probes the project the same way `smaqit.session-start` does: it checks Makefile, package.json, pyproject.toml, go.mod, Cargo.toml, *.sln, AGENTS.md/CLAUDE.md, and specs/stack/*.md for build, test, deploy, and health-check commands. Live-service E2E is included only if the task touches a live/running service, and verification methods are derived from the project's actual interfaces (HTTP, WebSocket, bot, event-driven) rather than a fixed service enum. The playbook template at `references/playbook-template.md` uses `{placeholder}` tokens for all commands.

---

## Memory and Session Persistence

**Why don't smaqit skills call a specific "memory" tool anymore?**

They used to, inconsistently — three different, mutually incompatible conventions existed across different skills (`memory` with `type: workspace`, `store_memory`, and a bare `memory` with a `/memories/session/plan.md` path), none of which are real tools on every platform this project targets. The file-based records this project already maintains — `.smaqit/history/`, `.smaqit/tasks/PLANNING.md` and individual task files, and the plan shown directly in chat — are always the authoritative source. Where a persistent memory/notes capability happens to be available in a given environment, skills use it as a best-effort accelerant for cross-branch or cross-session continuity, but nothing depends on it existing.

---

## Installation

**How does the CLI choose a project root for implicit commands?**

Bare `init`, `update`, and `uninstall` commands first use the enclosing Git worktree root. Outside Git they use the nearest ancestor containing `.smaqit`; if neither exists, they fall back to the current directory for a new standalone project. An explicit `init <dir>` always honors that exact directory.

Git-root precedence prevents an accidental nested installation such as `scripts/.smaqit` from trapping later implicit commands in the wrong directory.

---

## Release Workflow

**Where is desktop SSH-agent popup recovery defined and how is it constrained?**

The canonical instructions live in `agents/smaqit.release.local.agent.md`, `skills/smaqit.release-git-local/SKILL.md`, and `.smaqit/templates/copilot-instructions.template.md`. Generated Copilot, Claude Code, and Codex artifacts plus installer templates carry the same guidance.

When an authorized Git SSH step lacks an inherited agent, the workflow checks already-running desktop sockets in a defined order: GCR, legacy GNOME Keyring, GnuPG, the current OpenSSH socket, then the systemd user environment. It uses a socket only for a command-scoped identity check and one retry of the exact failed Git command, allowing WSLg/GNOME/pinentry unlock or confirmation prompts to appear. It never exports or persists `SSH_AUTH_SOCK`, starts or replaces an agent, loads or removes identities, changes transport, or broadens the authorized Git operation.

---

**Why does self-update launch a fresh binary for project reinitialization?**

Agents, skills, and templates are compiled into the Go binary with `go:embed`. Replacing the executable file does not change the already-running process image, so reinitializing in-process after a download would reinstall stale embedded content and omit newly added files.

After replacing the executable, the update path launches the new binary as a subprocess to run project initialization. Paths where no replacement occurs can safely reinitialize in-process because their embedded content has not changed.

---

**How does this repository keep Claude Code assets from appearing as update-generated untracked files?**

The repository tracks its generated `.claude/` dogfooding mirror alongside the Copilot and Codex mirrors. `smaqit-extensions update` can therefore re-initialize all supported platform assets at the repository root without leaving the installed Claude agents, commands, and skills untracked.

---

**How does a project get post-merge release automation (tag + GitHub Release) after installing smaqit-extensions?**

`smaqit-extensions init`/`update` deploy `.github/workflows/post-merge-release.yml` automatically, create-if-absent — the installer never overwrites an existing copy, so a project-customized workflow is always preserved. The installed workflow is generic and project-agnostic: on a `vX.Y.Z` tag push or a merged PR titled "Prepare release vX.Y.Z"/"Release vX.Y.Z", it creates the tag (if needed) and publishes a GitHub Release with the matching `CHANGELOG.md` section as its notes. It ships with **no build step** — a project that wants binaries or other release artifacts attached must add those steps to its own copy of the file.

This is distinct from `smaqit-extensions`' own `.github/workflows/post-merge-release.yml`, which additionally builds and uploads Go binaries for every platform — that behavior is specific to this repository's own dogfooded release process and is not part of what gets installed elsewhere. `smaqit.release.pr` and `smaqit.release-git-local` describe only the generic tag+release behavior; they point to the installed workflow file itself rather than assuming what it contains, since a project may have extended it.

---

## Task Management

**Why are task files and PLANNING.md excluded from task worktrees?**

Task state (`.smaqit/tasks/PLANNING.md` and individual `NNN_*.md` files) lives exclusively on the main branch. Task worktrees exclude `.smaqit/tasks/` via sparse checkout so no worktree ever has a local copy of task state.

The design eliminates merge conflicts on `PLANNING.md`: when `task-start` and `task-complete` update task status, they write to main's copy directly rather than to the worktree's copy. The worktree is purely for source code changes. When `task-complete` merges the task branch into main, only code files are affected — task state never diverged, so there is nothing to conflict on.

The lifecycle resolver (`9_resolve_task_lifecycle.sh`) finds task files exclusively on main and uses `git worktree list --porcelain` to map branch names to worktree paths for merge/cleanup operations.

`task-start` also performs a task-awareness check before implementation: it scans main for other "In Progress" tasks and uncommitted task-state changes, surfacing them as an informational notice so agents in separate sessions are aware of concurrent work. `task-complete` verifies post-merge that the task is properly finalized on main (status=Completed, committed, PLANNING.md updated).

The rest of `.smaqit/` (templates, references, definitions, user-testing) remains available in task worktrees — only the conflict-prone task-tracking state is isolated.

---
