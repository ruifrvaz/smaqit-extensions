**Quality-of-life workflows, agents and skills**

Enhance your agentic development with streamlined session management, task tracking, release and test automation. Designed to work out of the box in any repository with a simple one-time install.

## Compatibility

| Platform | Status |
|----------|--------|
| GitHub Copilot (VS Code) | ✅ Supported |
| Claude Code | ✅ Supported |
| Codex | ✅ Supported |

A single `curl .../install.sh | bash` installs all three targets globally. Each platform receives artifacts compiled from the same canonical `agents/` and `skills/` sources.

## What's Included

### Skills

#### Session Management
- **smaqit.session-start** - Load full project context at session start
- **smaqit.session-assess** - Analyze requests before implementation
- **smaqit.session-finish** - Document session history at completion
- **smaqit.session-title** - Generate concise session titles
- **smaqit.session-recap** - Summarize session progress as a structured table

#### Task Tracking
- **smaqit.task-create** - Create new tasks with auto-numbering
- **smaqit.task-start** - Create a lifecycle-owner branch/worktree or join an active parent task, then start with the effective workflow mode
- **smaqit.task-list** - Show current active tasks
- **smaqit.task-complete** - Verify and complete tasks; lifecycle owners merge and refresh once their children are complete
- **smaqit.task-refresh** - Identify session work with no corresponding task and surface retroactive task candidates

#### Testing
- **smaqit.test-start** - Initialize testing workflows
- **smaqit.test-create** - Create structured E2E test playbooks from task files with build-gate, deploy-gate, and live-service E2E validation
- **smaqit.test-complete** - Finalize testing sessions by verifying pass/fail criteria and generating standardized test reports

#### Release Management
- **smaqit.release-analysis** - Collect changes, assess severity, and suggest next version
- **smaqit.release-approval** - Obtain approval for suggested version (auto-confirm or interactive)
- **smaqit.release-prepare-files** - Validate git state and prepare all files for release
- **smaqit.release-git-local** - Execute git operations for local releases (commit, tag, push)
- **smaqit.release-git-pr** - Execute git operations for PR-based releases using the platform's authenticated push mechanism

#### Project Management
- **smaqit.project-init** - Inferentially merge existing project guidance into canonical `AGENTS.md`, synchronize Claude through `CLAUDE.md` → `@AGENTS.md`, and link `.github/copilot-instructions.md` to the canonical file
- **smaqit.project-glossary** - Manage a per-project glossary (`list glossary`, `fetch from glossary`, `update glossary`, `remove from glossary`)
- **smaqit.project-diagnose** - Scan project structure for gaps across testing, security, logging, monitoring, provisioning, and CI/CD domains (`project.diagnose`, `project.diagnose security --tasks`)
- **smaqit.project-research** - Build and maintain a documentation topology map for the current project (`project.research`, `project.research [task-id]`)
- **smaqit.project-recap** - Generate a live project dashboard from the current codebase state (`project.recap`, `project.recap --refresh`)
- **smaqit.project-compendium** - Manage a live Q&A knowledge base (`list compendium`, `fetch from compendium`, `update compendium`, `remove from compendium`)

#### Assessment
- **smaqit.parity-assess** - Compare two systems and generate a structured parity assessment with Mermaid diagrams and an action roadmap (`parity.assess <name>`)

#### Utilities
- **smaqit.utils.read-pdf** - Extract text from a PDF file and continue with the caller's original goal
- **smaqit.utils.triage-issues** - Search upstream GitHub repos for known issues before implementation begins (`task.triage [id]`)
- **smaqit.utils.worktree** - Sync branch worktrees and the VS Code multi-root workspace

### Utility Agents

- **@smaqit.release.local** (Copilot) / **/smaqit.release.local** (Claude Code) / **smaqit.release.local** (Codex subagent) - Automated release management (local development)
- **@smaqit.release.pr** (Copilot) / **/smaqit.release.pr** (Claude Code) / **smaqit.release.pr** (Codex subagent) - Automated release management (PR-based, CI/CD)
- **@smaqit.user-testing** (Copilot) / **/smaqit.user-testing** (Claude Code) / **smaqit.user-testing** (Codex subagent) - End-to-end testing workflow

## Installation

### Quick Install (Bash)

```bash
curl -fsSL https://raw.githubusercontent.com/ruifrvaz/smaqit-extensions/main/install.sh | bash
```

### Manual Installation

1. Download the latest release from [Releases](https://github.com/ruifrvaz/smaqit-extensions/releases)
2. Extract the binary
3. Run: `./smaqit-extensions --install-global`

### What Gets Installed

The installer downloads the binary and installs agents and skills globally:

- `~/.agents/skills/` - 29 workflow skills (shared by GitHub Copilot + Codex)
- `~/.copilot/agents/` - 3 utility agents (GitHub Copilot)
- `~/.claude/agents/` - 3 utility subagents (Claude Code)
- `~/.claude/commands/` - 3 slash commands, one per subagent
- `~/.claude/skills/` - 29 workflow skills (Claude Code)
- `~/.codex/agents/` - 3 project custom agents (standalone TOML)

Running `smaqit-extensions init` in a project additionally scaffolds:

- `.smaqit/` — task tracking (PLANNING.md), session history, templates
- `.github/workflows/post-merge-release.yml` — generic, project-agnostic release automation (tag + GitHub Release; no build step). Deployed create-if-absent: `init` and `update` never overwrite an existing copy, so local edits (e.g. adding a build/artifact-upload step) are always preserved.

**Environment overrides:**

| Variable | Default | Overrides |
|----------|---------|-----------|
| `COPILOT_HOME` | `~/.copilot` | Copilot agent install root |
| `CLAUDE_CONFIG_DIR` | `~/.claude` | Claude agent/skill/command install root |
| `CODEX_HOME` | `~/.codex` | Codex agent install root |

## Usage

Skills are the primary instruction component and can be invoked directly in GitHub Copilot, Claude Code, or Codex by referencing the skill name in your request:

```
User: smaqit.session-start
User: smaqit.task-create Implement new feature
User: smaqit.task-start 001               # Assisted mode (default) - user approval required
User: smaqit.task-start 002 --autonomous  # Autonomous mode - AI completes automatically
User: smaqit.session-finish
```

The `smaqit-extensions` binary also accepts CLI commands:

```bash
smaqit-extensions init                    # Scaffold .smaqit/ tracking in current project
smaqit-extensions init <dir>              # Scaffold .smaqit/ tracking in specified directory
smaqit-extensions update                  # Update binary and refresh global install
smaqit-extensions uninstall               # Remove extensions from global paths
smaqit-extensions uninstall --scope project  # Remove extensions from project directory
smaqit-extensions version                 # Show version
```

For commands without an explicit directory, the CLI detects the enclosing Git worktree root. Outside Git, it uses the nearest ancestor containing `.smaqit`, then falls back to the current directory for a new standalone project. This makes invocation from nested directories such as `scripts/` safe.

### Self-Update

```bash
smaqit-extensions update
```

Fetches the latest release from GitHub, downloads the new binary, and replaces the running binary atomically. Refreshes the global installation automatically. If the detected project root contains `.smaqit/`, it also re-scaffolds project templates without overwriting your project state (tasks, history, glossary) or a pre-existing `.github/workflows/post-merge-release.yml`.

> **Note:** Self-update is currently supported on Linux only.

### Task Workflow Modes

**Assisted Mode (default):**
- AI implements the task and stops
- User reviews and approves
- User invokes `smaqit.task-complete [id]` when satisfied
- Use for: complex features, user-facing changes, quality gates

**Autonomous Mode:**
- AI implements, verifies, and completes automatically
- No user approval gate
- Use for: CI/CD pipelines, batch operations, well-defined refactoring

### Task Worktrees

`smaqit.task-start [id]` creates a `task/NNN-title` branch, adds a sibling Git worktree, and refreshes the project’s `.code-workspace` file for a standalone or parent task. A task declaring `**Parent:** NNN` joins the active parent's registered branch and worktree instead; it creates no child Git resources and inherits the parent mode.

`smaqit.task-complete [id]` records a child task's criteria, findings, and state without touching Git resources. The standalone or parent owner performs the one merge, worktree removal, branch deletion, and workspace refresh only after every declared child is `Completed`. Shared-parent tasks are intended for sequential or coordinated work; independent parallel editing still needs separate branches and worktrees.

The workflow is implemented by the installed `smaqit.utils.worktree` skill and its shell scripts; there is no separate worktree command or service. Task worktrees use sparse checkout to omit generated platform scaffolding and avoid duplicate skill discovery while retaining canonical project source. `worktree.migrate-sessions` can explicitly migrate VS Code chat sessions when first switching to the multi-root workspace; it is never run automatically.

Agents are available in GitHub Custom Agents:
```
@smaqit.release.local   # Local release (interactive or auto-confirm)
@smaqit.release.pr      # PR-based release (CI/CD, auto-confirm only)
@smaqit.user-testing    # End-to-end testing
```

On Claude Code, the same 3 agents are available as slash commands, which delegate to the matching subagent via `Task`:
```
/smaqit.release.local   # Local release (interactive or auto-confirm)
/smaqit.release.pr      # PR-based release (CI/CD, auto-confirm only)
/smaqit.user-testing    # End-to-end testing
```

On Codex, skills are discovered from the global `~/.agents/skills/` directory; invoke one with `$` or select it through `/skills`. Agents are discovered from the global `~/.codex/agents/` directory; ask Codex to spawn the named agent when delegation is useful.

## Requirements

- GitHub Copilot with agent and skill support, Claude Code, or Codex
- A git repository (for project scaffolding)

The installer writes skills and agents to global user-level paths (`~/.agents/skills/`, `~/.copilot/agents/`, `~/.claude/`, `~/.codex/agents/`). Running `smaqit-extensions init` scaffolds `.smaqit/` project tracking and `.github/workflows/post-merge-release.yml` in a repository.

`smaqit.release.pr` and `smaqit.release.local` depend on `.github/workflows/post-merge-release.yml` for the tag-and-release step after a release commit or PR merge; `init`/`update` deploy it automatically (create-if-absent), so it is present in any project that has run `smaqit-extensions init`.

## Development

### Building the Installer

```bash
cd installer
make build    # Build installer
make test     # Test installer
make smoke-test  # Build, install into a temporary project, verify, and uninstall
```

The same smoke test is available from the repository root as `make smoke-test`. It compares every installed platform tree with the generated embed staging tree, validates Codex agent TOML and skill resolution, and verifies uninstall cleanup. Temporary projects are removed automatically; use `KEEP_SMOKE_DIR=1 make smoke-test` to retain one for inspection.

### Contributors

This repository uses its own agents and skills for development (dogfooding).

Source files are located in `agents/`, `skills/`, and `commands/` at the repo root. After modifying source files, rebuild and reinstall globally:

```bash
cd installer
make prepare && make build
./dist/smaqit-extensions --install-global
```

`make sync` regenerates the gitignored `installer/` staging trees from canonical source — there are no committed mirrors to update. Running `--install-global` after building picks up the changed content for your editor session.

### Multi-Platform Build Pipeline

Platform output shipped by `install.sh` is generated, not hand-maintained. Additional source locations feed it:

- `commands/` - Claude Code slash-command wrappers, one per agent
- `.smaqit/definitions/agents/*.frontmatter.yaml` - per-platform agent metadata for Copilot, Claude Code, and Codex; agent bodies are reused from `agents/`
- `.smaqit/definitions/skills/*.placeholders.yaml` - per-platform values for skill instructions that genuinely differ by platform

Running `make -C installer prepare` (or `python3 scripts/generate-targets.py` directly) compiles these, plus `agents/` and `skills/`, into gitignored `installer/{agents-copilot,agents-claude,agents-codex,commands-claude,skills,skills-claude}/` trees that the Go binary embeds. This repository carries no committed `.github/agents/`, `.github/skills/`, `.claude/`, `.codex/`, or `.agents/` dogfooding mirrors — agents and skills are installed globally via `--install-global`, the same as any consumer project.

## Releases

> **Note:** This section describes how *smaqit-extensions itself* is released — its `.github/workflows/post-merge-release.yml` also builds and publishes the Go binaries for every platform, which is specific to this repository. A project that installs smaqit-extensions gets a simpler, generic version of this workflow (tag + GitHub Release, no build step) deployed automatically by `init`/`update`; see [What Gets Installed](#what-gets-installed).

Releases are fully automated via PR-based workflow:

1. Create a release issue (or use existing template)
2. Assign to Copilot Coding Agent
3. Agent creates PR with CHANGELOG updates
4. Review and merge PR
5. Post-merge workflow automatically:
   - Creates and pushes git tag
   - Builds binaries for all platforms
   - Creates GitHub Release with binaries

**No manual git operations required!**

### For Maintainers

- Ensure release PR titles follow format: "Prepare release vX.Y.Z" or "Release vX.Y.Z"
- Post-merge workflow extracts version from PR title and handles everything
- Tag format: `vX.Y.Z` (e.g., `v0.3.0`)
- All release steps run in a single unified workflow

## Contributing

Contributions welcome! Please open an issue or PR.

## License

MIT License - see [LICENSE](LICENSE)

## Related Projects

- [smaQit](https://github.com/ruifrvaz/smaqit) - Spec-driven agent orchestration framework
- [smaQit-sdk](https://github.com/ruifrvaz/smaqit-sdk) - Agent development toolkit
