# Project Compendium

## Architecture

**How does smaqit-extensions handle content that differs between GitHub Copilot, Claude Code, and Codex?**

Agent bodies (`agents/*.agent.md`) and skill bodies (`skills/*/SKILL.md`) are shared source, reused across all platforms wherever possible. Two mechanisms handle platform variance without duplicating whole files:

- **Per-platform agent metadata**: each agent's `.smaqit/definitions/agents/<name>.frontmatter.yaml` holds `copilot:`, `claude:`, and `codex:` sections. `scripts/generate-targets.py` combines each section with the shared body to produce YAML-frontmatter agents for Copilot and Claude Code plus standalone TOML custom agents for Codex.
- **`{{PLACEHOLDER}}` tokens for genuinely divergent content**: for the small number of skills whose executable behavior differs by platform — such as `smaqit.release-git-pr` using Copilot's `report_progress` mechanism versus direct authenticated Git operations elsewhere — the shared `SKILL.md` contains named `{{TOKEN}}` placeholders resolved from `.smaqit/definitions/skills/<name>.placeholders.yaml`. This isolates only the actual inflection points; everything else stays identical.

Both mechanisms are resolved once, at build time, by `scripts/generate-targets.py`; installed output contains no unresolved build-time tokens. Generated trees under `installer/` are ephemeral embed inputs, rebuilt from canonical `agents/`/`skills/` on every build. Agents and skills are installed globally (not committed to this repo) — `make sync` only regenerates the installer staging trees; there are no committed mirrors to update.

---

**How does `smaqit.project-init` synchronize instructions across tools?**

Every platform receives the same inference-driven `smaqit.project-init` skill. The skill reads any existing `AGENTS.md`, `CLAUDE.md`, and `.github/copilot-instructions.md` together with repository evidence before writing. It semantically preserves and deduplicates explicit rules, keeps smaqit-owned scaffolding current, and asks the user before resolving irreconcilable instructions.

The synchronized topology is:

- Root `AGENTS.md` is the canonical shared instruction document.
- Root `CLAUDE.md` starts with `@AGENTS.md` and contains only genuinely Claude-specific additions.
- `.github/copilot-instructions.md` is a relative symlink to `../AGENTS.md`; distinct content from a pre-existing Copilot file is merged before replacement.

Repeated initialization is expected to be idempotent. Claude Code may fail to resolve an ancestor import when launched from some repository subdirectories, so launch it from the project root if imported instructions are missing.

The `# Scaffolding` section seeded into `AGENTS.md` comes from `skills/smaqit.project-init/references/AGENTS.template.md` — a skill-bundled reference installed globally alongside the skill itself, not a project-scaffolded file under `.smaqit/templates/`. This means the template is always present wherever the skill is installed, regardless of a given project's `.smaqit/` scaffolding state. Despite the name, `.github/copilot-instructions.md` never carries distinct Copilot-specific content; it is always the symlink described above.

---

**How does the installer's `[SMAQIT_SKILLS_DIR]` placeholder work?**

A handful of skills reference their own install path in usage comments or example commands (e.g. `smaqit.project-diagnose`, `smaqit.utils.read-pdf`). Since a skill's install root differs by platform (`~/.agents/skills` for Copilot and Codex under the default global install, `~/.claude/skills` for Claude Code; `.github/skills`/`.agents/skills`/`.claude/skills` respectively under `--scope project`), any such self-reference is written in source using the literal placeholder `[SMAQIT_SKILLS_DIR]`. `scripts/generate-targets.py` resolves it when compiling each platform's ephemeral installer tree into `installer/`, so no installed output ever contains the literal placeholder.

---

**Does the worktree workflow add a separate installer or CLI command?**

No. Worktree behavior is implemented by the canonical `smaqit.utils.worktree` skill and its nine shell scripts. The normal initializer installs that skill for GitHub Copilot, Claude Code, and Codex alongside the other workflow skills.

`smaqit.task-start` invokes the workflow to create or reuse a task branch, sibling worktree, sparse checkout, and root VS Code workspace. `smaqit.task-complete` invokes its cleanup path after merging. `worktree.sync` and `worktree.migrate-sessions` are skill triggers, not commands in the `smaqit-extensions` binary.

---

**How do `smaqit.utils.worktree` scripts determine which repository to operate on?**

Every script resolves the project root from the caller's current working directory — via a bare `git rev-parse --show-toplevel` (scripts 1, 3–8) or a bare `git worktree list --porcelain` (script 9's lifecycle resolver) — never from the script's own installed file location. This matters because under the default global install, the scripts live entirely outside any project (`~/.claude/skills/...`, `~/.agents/skills/...`); deriving the root from `${BASH_SOURCE[0]}` would resolve the wrong repository, or fail outright with "not a git repository." Every documented invocation in `SKILL.md` therefore requires cwd to already be at the project root when the script runs — Gotcha #16 states this explicitly for Steps 1–8, matching Step 9's own documented convention. `2_validate_prereqs.sh`'s bare `git rev-parse --git-dir` check is the same cwd-anchored pattern in miniature, and the only script that needed no fix when this was corrected.

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

**How does the CLI choose an installation target?**

`curl -fsSL https://raw.githubusercontent.com/ruifrvaz/smaqit-extensions/main/install.sh | bash` downloads the binary and runs global agent/skill installation automatically. After that, running `smaqit-extensions` (no args, or `init`) scaffolds `.smaqit/` and `.github/workflows/post-merge-release.yml` in the current project. It first uses the enclosing Git worktree root, then outside Git the nearest ancestor containing `.smaqit`, then falls back to the current directory for a new standalone project. `update` refreshes the global installation and re-scaffolds `.smaqit/` templates if present. `uninstall` defaults to global scope; pass `--scope project` to remove a project installation instead.

Git-root precedence prevents an accidental nested installation such as `scripts/.smaqit` from trapping later commands in the wrong directory.

---

**Does `smaqit-extensions update` include every fix committed to `main`, or only tagged releases?**

Only tagged releases. `update` fetches the latest GitHub Release and downloads its published binary — it has no awareness of `main`'s commit history beyond that. A direct commit to `main` (e.g. a small infra fix landed outside the PR-gated task flow) is invisible to `update` until some later release's tag includes it. Concretely: `post-merge-release.yml` tags and releases at the moment a task's PR merges, so any commit pushed to `main` *after* that merge — including another same-day hotfix — sits unreleased until a new release is cut, even though it's already on `main` and in the repository's history.

---

**Does `smaqit-extensions update`/`init` distinguish its own source repo from a consumer project when scaffolding?**

No — not currently. Both check only whether `.smaqit/` exists in the target directory (`installer/main.go`, `checkAndReInitWithBinary` and `checkAndReInit`), with no check for "this directory is smaqit-extensions' own checkout." Since this repository also maintains its own `.smaqit/` for task tracking, running `update` (or `init`) from inside it re-creates the committed-dogfooding-mirror pattern removed in v1.14.3 — `.github/agents/`, `.github/skills/`, `.claude/`, `.codex/agents/`, `.agents/skills/` — plus resurrects an orphaned `copilot-instructions.template.md`. Everything created this way is untracked by git, so it's always safe to `rm -rf` the resulting paths; nothing is lost. This is unrelated to binary-replacement staleness (see "Why does self-update launch a fresh binary for project reinitialization?") — it reproduces identically regardless of which binary version runs it.

---

**Does installing or updating remove files that are no longer part of the current release?**

No. The installer (fresh install or `update`) copies and overwrites files from the current source into the global install directories, but it never prunes files that exist on disk but are no longer present in the version being installed. A file left behind by an earlier development-time `--install-global` run (e.g. a helper script from an in-progress skill rework that was later dropped from the shipped design) survives an official reinstall untouched — its presence doesn't imply it's still part of the current release. Verify installed content against the exact released source (e.g. `git show <tag>:<path>` for a specific file, or a repo-wide grep for any reference to a suspect file) rather than trusting a version-string match alone.

---

## Release Workflow

**Where is desktop SSH-agent popup recovery defined and how is it constrained?**

The canonical instructions live in `agents/smaqit.release.local.agent.md`, `skills/smaqit.release-git-local/SKILL.md`, and `skills/smaqit.project-init/references/AGENTS.template.md`. Generated Copilot, Claude Code, and Codex artifacts carry the same guidance — the template is a skill-bundled reference, installed globally alongside `smaqit.project-init` itself, not a project-scaffolded file.

When an authorized Git SSH step lacks an inherited agent, the workflow checks already-running desktop sockets in a defined order: GCR, legacy GNOME Keyring, GnuPG, the current OpenSSH socket, then the systemd user environment. It uses a socket only for a command-scoped identity check and one retry of the exact failed Git command, allowing WSLg/GNOME/pinentry unlock or confirmation prompts to appear. It never exports or persists `SSH_AUTH_SOCK`, starts or replaces an agent, loads or removes identities, changes transport, or broadens the authorized Git operation.

---

**Do release PRs carry an AI-authorship disclaimer footer?**

No. `CLAUDE.md` at the repository root explicitly instructs against adding a "Generated with Claude Code" footer (or any equivalent AI-authorship disclaimer) to pull request descriptions. Such a footer is not part of any smaqit skill or agent's own PR template — it originates from Claude Code's own baseline `gh pr create` guidance and must be suppressed via this project-level instruction.

---

**Why does self-update launch a fresh binary for project reinitialization?**

Agents, skills, and templates are compiled into the Go binary with `go:embed`. Replacing the executable file does not change the already-running process image, so reinitializing in-process after a download would reinstall stale embedded content and omit newly added files.

After replacing the executable, the update path launches the new binary as a subprocess to run project initialization. Paths where no replacement occurs can safely reinitialize in-process because their embedded content has not changed.

---

**How does a project get post-merge release automation (tag + GitHub Release) after installing smaqit-extensions?**

`smaqit-extensions install --scope project`/`update` deploy `.github/workflows/post-merge-release.yml` automatically, create-if-absent — the installer never overwrites an existing copy, so a project-customized workflow is always preserved. The installed workflow is generic and project-agnostic: on a `vX.Y.Z` tag push or a merged PR titled "Prepare release vX.Y.Z"/"Release vX.Y.Z", it creates the tag (if needed) and publishes a GitHub Release with the matching `CHANGELOG.md` section as its notes. It ships with **no build step** — a project that wants binaries or other release artifacts attached must add those steps to its own copy of the file.

This is distinct from `smaqit-extensions`' own `.github/workflows/post-merge-release.yml`, which additionally builds and uploads Go binaries for every platform — that behavior is specific to this repository's own dogfooded release process and is not part of what gets installed elsewhere. `smaqit.release.pr` and `smaqit.release-git-local` describe only the generic tag+release behavior; they point to the installed workflow file itself rather than assuming what it contains, since a project may have extended it.

---

## Task Management

**Why are task files and PLANNING.md excluded from task worktrees?**

Task state (`.smaqit/tasks/PLANNING.md` and individual `NNN_*.md` files) lives exclusively on the main branch. Task worktrees exclude `.smaqit/tasks/` via sparse checkout so no worktree ever has a local copy of task state.

The design eliminates merge conflicts on `PLANNING.md`: when `task-start` and `task-complete` update task status, they write to main's copy directly — and push it to `origin/main` immediately, with a bounded fetch-rebase-retry loop on collision — rather than to the worktree's copy or deferring to `session-finish`. The worktree is purely for source code changes.

The lifecycle resolver (`9_resolve_task_lifecycle.sh`) finds task files exclusively on main and uses `git worktree list --porcelain` to map branch names to worktree paths for merge/cleanup operations. Branch ownership itself is recovered from the task's own title, not a stored field: `find_active_task()` reads the task file on main and, if its status is in the caller's allowed set, recomputes the expected branch name via `task_branch_name()` — the same slug logic used when the branch was first created — then matches it against the registered worktree branches. Renaming an in-progress task's title after its branch exists breaks this recomputation, since the recomputed slug would no longer match the real branch. The allowed-status set differs by caller: parent-child joining requires strictly `In Progress`; an owner's own `--purpose complete` resolution accepts either `In Progress` (task-complete's Phase 1) or `PR Open` (Phase 2) — see "How does `task-complete` work now that it no longer merges directly into `main`?" below.

`task-start` also performs a task-awareness check before implementation: it scans main for other "In Progress" tasks and uncommitted task-state changes, surfacing them as an informational notice so agents in separate sessions are aware of concurrent work. `task-complete`'s Phase 2 verifies post-merge that the task is properly finalized on main (status=Completed, committed, PLANNING.md updated).

The rest of `.smaqit/` (templates, references, definitions, user-testing) remains available in task worktrees — only the conflict-prone task-tracking state is isolated.

Implementation changes in a task worktree are deliberately left uncommitted until `task-complete` runs: for an owner, immediately before Phase 1 pushes the branch and opens its PR; for a child, immediately before its own completion commit to main. This is the only point in the lifecycle a task branch receives an implementation commit, so Assisted-mode review always sees a normal working-tree diff rather than already-committed history.

---

**How does an agent work across the primary checkout and a task worktree in the same session?**

`git worktree list --porcelain` always lists the main worktree first, and every linked worktree shares the same `.git` object database — so any worktree can address any other via `git -C <path>` or an absolute file path, without changing directory. This repository has no committed dogfooding mirrors (removed once the global-install migration landed) — skill discovery happens through the globally-installed copies (`~/.claude/skills/`, `~/.agents/skills/`), entirely outside the repo, exactly like any consumer project under the default global install. The sparse-checkout exclusion list (`.github/agents/`, `.github/skills/`, `.claude/agents/`, `.claude/commands/`, `.claude/skills/`, `.agents/skills/`, `.codex/agents/`) is therefore purely defensive here too — it has nothing to exclude unless a project explicitly used `install --scope project`. A session's tools are anchored at main while source edits are addressed to whichever worktree folder actually holds the file. The generated multi-root `.code-workspace` file (main plus every active task worktree) is what makes both trees visible to one IDE session at once.

---

**How does `task-complete` work now that it no longer merges directly into `main`?**

For an owner (standalone or parent) task, completion is PR-gated and runs in two phases, because PR review is asynchronous and can't be waited out inside a single invocation. A child task is entirely unaffected — it still just commits into the shared parent worktree and updates task-file bookkeeping, with no PR and no release of its own.

**Phase 1** (Status `In Progress`): commits the implementation, computes the task's own release version via `release-analysis`'s Task mode (fetches `origin/main` fresh and treats any other task's currently-pending version as already claimed), pushes the branch, opens a PR titled `Prepare release vX.Y.Z`, pushes a `(pending vX.Y.Z · PR #NNN)`-annotated entry to `CHANGELOG.md`'s `[Unreleased]` section directly on `main`, then rebases the branch and promotes that entry into a real `## [X.Y.Z]` section on the branch itself (so the merged PR carries the changelog change and `post-merge-release.yml`'s release-notes extraction has something to find). The task's status becomes `PR Open`, recording the PR number in a `**PR:**` field. Assisted mode stops here; Autonomous mode immediately self-merges (`gh pr merge --merge`) and falls straight into Phase 2.

**Phase 2** (Status `PR Open`, re-entrant): confirms the PR actually merged via `gh pr view --json state,mergedAt` — never inferred any other way — pulls `main`, flips status to `Completed`, removes the worktree, and force-deletes (`-D`, not `-d`) the **local** branch only. `-D` is required because GitHub's own merge confirmation is authoritative regardless of merge strategy, and a squash merge (or Phase 1's own rebase) leaves the local branch tip unable to satisfy `-d`'s ancestry check. The remote branch is never deleted — it's kept indefinitely as an audit trail of every merged/released task.

Each PR is also that task's release: merging it is what triggers `post-merge-release.yml`'s existing tag + GitHub Release automation, just now firing per-task instead of per manually-triggered batch. `CHANGELOG.md` can hold several tasks' pending entries at once, each promoted independently by its own PR merge — so tags can land out of numeric order, and this is expected. See also: "How does a project get post-merge release automation (tag + GitHub Release) after installing smaqit-extensions?"

---

**How many approvals does `task.plan` need before creating a new task (Mode A)?**

Just one. The plan and the pre-populated task-create fields derived from it are shown together in the same message; approving either approves both, and `task.create` is invoked immediately afterward with no separate re-confirmation. Mode B (an existing task ID) is different — its post-approval prompt offers three genuinely distinct choices (start now, update the task file, or hold for later), which is not a restatement of the plan and is not collapsed.

---

## Issue Triage

**How does `smaqit.utils.triage-issues` reduce execution-token usage without losing task signal?**

New tasks declare a compact `## Issue Triage Context` with the triage mode, technologies, platforms/environments, features/integrations, and versions/constraints. `smaqit.project-research/scripts/task-context.sh` validates and fingerprints just those fields; triage does not load general task prose for structured tasks. Project research stores a keyed task block for that fingerprint, and triage reads only that exact block rather than the full research map.

GitHub access is likewise projected before model inspection: `github-issues.sh` limits each open or closed search to ten issues, excludes pull requests, retains only decision-relevant metadata, and caps at most three corroborating detail excerpts to 1,500 characters each. The workflow retains the Blocking, Advisory, Historical, and Clear decisions, with warnings preventing a false Clear result. Legacy task prose remains a warned migration fallback until the task is re-planned.

---
