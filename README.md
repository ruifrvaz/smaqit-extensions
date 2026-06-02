**Quality-of-life workflows, agents and skills**

Enhance your agentic development with streamlined session management, task tracking, release and test automation. Designed to work out of the box in any repository with a simple one-time install.

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

#### Testing
- **smaqit.test-start** - Initialize testing workflows

#### Release Management
- **smaqit.release-analysis** - Collect changes, assess severity, and suggest next version
- **smaqit.release-approval** - Obtain approval for suggested version (auto-confirm or interactive)
- **smaqit.release-prepare-files** - Validate git state and prepare all files for release
- **smaqit.release-git-local** - Execute git operations for local releases (commit, tag, push)
- **smaqit.release-git-pr** - Execute git operations for PR-based releases (via report_progress)

#### Project Management
- **smaqit.project-init** - Bootstrap a new smaqit project by generating `.github/copilot-instructions.md` from a template
- **smaqit.project-glossary** - Manage a per-project glossary (`list glossary`, `fetch from glossary`, `update glossary`, `remove from glossary`)
- **smaqit.project-research** - Build and maintain a documentation topology map for the current project (`project.research`, `project.research [task-id]`)
- **smaqit.project-recap** - Generate a live project dashboard from the current codebase state (`project.recap`, `project.recap --refresh`)
- **smaqit.project-compendium** - Manage a live Q&A knowledge base (`list compendium`, `fetch from compendium`, `update compendium`, `remove from compendium`)

#### Assessment
- **smaqit.parity-assess** - Compare two systems and generate a structured parity assessment with Mermaid diagrams and an action roadmap (`parity.assess <name>`)

#### Utilities
- **smaqit.utils.read-pdf** - Extract text from a PDF file and continue with the caller's original goal
- **smaqit.utils.triage-issues** - Search upstream GitHub repos for known issues before implementation begins (`task.triage [id]`)

### Utility Agents
- **@smaqit.release.local** - Automated release management (local development)
- **@smaqit.release.pr** - Automated release management (PR-based, CI/CD)
- **@smaqit.user-testing** - End-to-end testing workflows

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

The installer copies files to your project's `.github/` directory:
- `agents/` - 3 utility agents (release local, release PR, user-testing)
- `skills/` - 23 workflow skills (complete implementations)

## Usage

Skills are the primary instruction component and can be invoked directly in GitHub Copilot by referencing the skill name in your request:

```
User: smaqit.session-start
User: smaqit.task-create Implement new feature
User: smaqit.task-start 001               # Assisted mode (default) - user approval required
User: smaqit.task-start 002 --autonomous  # Autonomous mode - AI completes automatically
User: smaqit.session-finish
```

The `smaqit-extensions` binary also accepts CLI commands:

```bash
smaqit-extensions init           # Install extensions in current directory
smaqit-extensions update         # Update binary to the latest release (Linux only)
smaqit-extensions uninstall      # Remove extensions from current directory
smaqit-extensions version        # Show version
```

### Self-Update

```bash
smaqit-extensions update
```

Fetches the latest release from GitHub, downloads the new binary, and replaces the running binary atomically. If the current directory contains a `.smaqit/` project, it automatically re-runs `init` to deploy updated agents, skills, and templates without overwriting your project state (tasks, history, glossary).

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

## Requirements

- GitHub Copilot with agent and skill support
- A git repository

The installer writes files under `.github/agents/` and `.github/skills/` and will create the `.github/` folder if it doesn't exist.

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
```

### Contributors

This repository uses its own agents and skills for development (dogfooding).

Source files are located in:
- `agents/` - Agent definitions
- `skills/` - Skill implementations

These are copied to `.github/{agents,skills}/` for use by GitHub Copilot.

**Important:** After making changes to source files, run:

```bash
make sync
```

This copies updated files to `.github/` so they're available for use. The sync verification workflow in CI will fail if `.github/` is out of sync with source files.

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
