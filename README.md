# smaQit-extensions

**Quality-of-life workflow prompts, agents, and skills (smaQit-extensions)**

A collection of prompts, agents, and skills that streamline session management, task tracking with approval gates, release automation, and testing workflows.

These `smaQit` extensions are designed to work out of the box in any repository. Install once, and prompts/agents reference the `.smaqit/` directory for task tracking, session history, and testing artifacts.

## What's Included

### Skills
- **session-start** - Load full project context at session start
- **session-finish** - Document session history at completion
- **session-assess** - Analyze requests before implementation
- **session-title** - Generate concise session titles
- **task-create** - Create new tasks with auto-numbering
- **task-start** - Start working on a task (autonomous or assisted mode)
- **task-list** - Show current active tasks
- **task-complete** - Mark tasks as completed with verification
- **test-start** - Initialize testing workflows

### Session Management Prompts
- **session.start** - Load full project context at session start
- **session.assess** - Analyze requests before implementation
- **session.finish** - Document session history at completion
- **session.title** - Generate concise session titles

### Task Tracking Prompts
- **task.create** - Create new tasks with auto-numbering
- **task.start** - Start working on a task with workflow mode
- **task.list** - Show current active tasks
- **task.complete** - Mark tasks as completed with verification

### Testing Prompts
- **test.start** - Initialize testing workflows

### Release Management Skills
- **release-analysis** - Collect changes, assess severity, and suggest next version
- **release-approval** - Obtain approval for suggested version (auto-confirm or interactive)
- **release-prepare-files** - Validate git state and prepare all files for release
- **release-git-local** - Execute git operations for local releases (commit, tag, push)
- **release-git-pr** - Execute git operations for PR-based releases (via report_progress)

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
3. Run: `./smaqit-extensions`

### What Gets Installed

The installer copies files to your project's `.github/` directory:
- `prompts/` - 9 workflow prompts (stubs that reference skills)
- `agents/` - 3 utility agents (release local, release PR, user-testing)
- `skills/` - 14 workflow skills (complete implementations)

## Usage

Skills can be invoked via prompts in GitHub Copilot:

```
User: /session.start
User: /task.create Implement new feature
User: /task.start 001               # Assisted mode (default) - user approval required
User: /task.start 002 --autonomous  # Autonomous mode - AI completes automatically
User: /session.finish
```

### Task Workflow Modes

**Assisted Mode (default):**
- AI implements the task and stops
- User reviews and approves
- User invokes `/task.complete [id]` when satisfied
- Use for: complex features, user-facing changes, quality gates

**Autonomous Mode:**
- AI implements, verifies, and completes automatically
- No user approval gate
- Use for: CI/CD pipelines, batch operations, well-defined refactoring

**Note:** Prompts are now lightweight stubs that reference the corresponding skills. The actual implementation logic resides in the skills under `.github/skills/`.

Agents are available in GitHub Custom Agents:
```
@smaqit.release.local   # Local release (interactive or auto-confirm)
@smaqit.release.pr      # PR-based release (CI/CD, auto-confirm only)
@smaqit.user-testing    # End-to-end testing
```

## Requirements

- GitHub Copilot with prompt/agent support
- A git repository (recommended)

The installer writes files under `.github/prompts/` and `.github/agents/` and will create the `.github/` folder if it doesn't exist.

The installer also scaffolds the `.smaqit/` directory structure used by prompts, agents, and skills:
- `.smaqit/tasks/PLANNING.md` - Central task tracking file
- `.smaqit/tasks/` - Individual task files
- `.smaqit/history/` - Session documentation
- `.smaqit/user-testing/` - Test reports

## Development

### Building the Installer

```bash
cd installer
make build    # Build installer
make test     # Test installer
```

### Dogfooding (Repository Contributors)

This repository uses its own agents, prompts, and skills for development (dogfooding).

Source files are located in:
- `agents/` - Agent definitions
- `prompts/` - Prompt stubs
- `skills/` - Skill implementations

These are copied to `.github/{agents,prompts,skills}/` for use by GitHub Copilot.

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
