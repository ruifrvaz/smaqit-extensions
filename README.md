**Quality-of-life workflows, agents and skills**

Enhance your agentic development with streamlined session management, task tracking, release and test automation. Designed to work out of the box in any repository with a simple one-time install.

## Compatibility

| Platform | Status |
|----------|--------|
| GitHub Copilot (VS Code) | ✅ Supported |
| Claude Code | ✅ Supported |
| Codex | ✅ Supported |

A single `smaqit-extensions init` installs all three targets. Each platform receives artifacts compiled from the same canonical `agents/` and `skills/` sources.

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
- **smaqit.task-start** - Start working on a task with workflow mode
- **smaqit.task-list** - Show current active tasks
- **smaqit.task-complete** - Mark tasks as completed with verification
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
- **smaqit.project-init** - Bootstrap project instructions for the active platform (`.github/copilot-instructions.md`, `CLAUDE.md`, or `AGENTS.md`)
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
3. Run: `./smaqit-extensions init`

### What Gets Installed

The installer compiles the canonical root sources into platform-specific artifacts, then installs:

- `.github/agents/` - 3 utility agents (release local, release PR, user-testing)
- `.github/skills/` - 28 workflow skills (complete implementations)
- `.claude/agents/` - 3 utility subagents (same 3, Claude Code format)
- `.claude/commands/` - 3 slash commands, one per subagent
- `.claude/skills/` - 28 workflow skills (same content as `.github/skills/`)
- `.codex/agents/` - 3 project custom agents (standalone TOML)
- `.agents/skills/` - 28 workflow skills (Codex repository discovery path)

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
smaqit-extensions init           # Install extensions in the detected project root
smaqit-extensions init <dir>     # Install extensions in exactly the specified directory
smaqit-extensions update         # Update binary and refresh the detected project root
smaqit-extensions uninstall      # Remove extensions from the detected project root
smaqit-extensions version        # Show version
```

For commands without an explicit directory, the CLI detects the enclosing Git worktree root. Outside Git, it uses the nearest ancestor containing `.smaqit`, then falls back to the current directory for a new standalone project. This makes invocation from nested directories such as `scripts/` safe.

### Self-Update

```bash
smaqit-extensions update
```

Fetches the latest release from GitHub, downloads the new binary, and replaces the running binary atomically. If the detected project root contains `.smaqit/`, it automatically re-runs `init` there to deploy updated agents, skills, and templates without overwriting your project state (tasks, history, glossary).

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

On Codex, repository skills are discovered automatically from `.agents/skills/`; invoke one with `$` or select it through `/skills`. The same 3 utility agents are project-scoped custom subagents in `.codex/agents/`; ask Codex to spawn the named agent when delegation is useful.

## Requirements

- GitHub Copilot with agent and skill support, Claude Code, or Codex
- A git repository

The installer writes files under `.github/{agents,skills}/`, `.claude/{agents,commands,skills}/`, `.codex/agents/`, and `.agents/skills/`, creating each folder if it doesn't exist.

The installer also scaffolds the `.smaqit/` directory structure used by agents and skills:
- `.smaqit/tasks/PLANNING.md` - Central task tracking file
- `.smaqit/tasks/` - Individual task files
- `.smaqit/history/` - Session documentation
- `.smaqit/user-testing/` - Test reports
- `.smaqit/templates/` - Canonical task and planning templates

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

Source files are located in:

- `agents/` - Agent definitions
- `skills/` - Skill implementations

Generated targets are copied to `.github/{agents,skills}/` and `.codex/agents/` plus `.agents/skills/` for this repository's Copilot and Codex dogfooding environments.

**Important:** After making changes to source files, run:

```bash
make sync
```

This compiles updated files into the gitignored `installer/` staging trees, then synchronizes the committed `.github/`, `.codex/`, and `.agents/` dogfooding mirrors. CI fails when any mirror is out of sync with its generated target. This repository does not maintain a `.claude/` dogfooding copy; Claude output is still built and verified through scratch installations.

### Multi-Platform Build Pipeline

Platform output shipped by `smaqit-extensions init` is generated, not hand-maintained. Additional source locations feed it:

- `commands/` - Claude Code slash-command wrappers, one per agent
- `.smaqit/definitions/agents/*.frontmatter.yaml` - per-platform agent metadata for Copilot, Claude Code, and Codex; agent bodies are reused from `agents/`
- `.smaqit/definitions/skills/*.placeholders.yaml` - per-platform values for skill instructions that genuinely differ by platform

Running `make -C installer prepare` (or `python3 scripts/generate-targets.py` directly) compiles these, plus `agents/` and `skills/`, into gitignored `installer/{agents-copilot,agents-claude,agents-codex,commands-claude,skills,skills-claude,skills-codex}/` trees that the Go binary embeds. Root `.github/`, `.codex/`, and `.agents/` are dogfooding mirrors only and are never used as installer embed sources.

## Releases

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
