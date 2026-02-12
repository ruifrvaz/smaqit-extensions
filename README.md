# smaqit-extensions

**Quality-of-life workflow prompts and agents (smaqit-extensions)**

A collection of prompts and agents that streamline session management, task tracking, release, and testing workflows.

These `smaqit` extensions are designed to work out of the box in any repository. Install once, and prompts/agents reference the `.smaqit/` directory for task tracking, session history, and testing artifacts.

## What's Included

### Skills
- **session-start** - Load full project context at session start
- **session-finish** - Document session history at completion
- **session-assess** - Analyze requests before implementation
- **session-title** - Generate concise session titles
- **task-create** - Create new tasks with auto-numbering
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
- **smaqit.release** - Automated release management (local development)
- **smaqit.release.pr** - Automated release management (PR-based, CI/CD)
- **smaqit.user-testing** - End-to-end testing workflows

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
- `prompts/` - 8 workflow prompts (stubs that reference skills)
- `agents/` - 3 utility agents (release local, release PR, user-testing)
- `skills/` - 13 workflow skills (complete implementations)

## Usage

Skills can be invoked via prompts in GitHub Copilot:

```
User: /session.start
User: /task.create Implement new feature
User: /session.finish
```

**Note:** Prompts are now lightweight stubs that reference the corresponding skills. The actual implementation logic resides in the skills under `.github/skills/`.

Agents are available in GitHub Custom Agents:
```
@smaqit.release         # Local release (interactive or auto-confirm)
@smaqit.release.pr      # PR-based release (CI/CD, auto-confirm only)
@smaqit.user-testing    # End-to-end testing
```

## Requirements

- GitHub Copilot with prompt/agent support
- A git repository (recommended)

The installer writes files under `.github/prompts/` and `.github/agents/` and will create the `.github/` folder if it doesn't exist.

The installer also scaffolds the `.smaqit/` directory structure used by prompts and agents:
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
- `session-*/`, `task-*/`, `test-*/` - Skill implementations

These are copied to `.github/{agents,prompts,skills}/` for use by GitHub Copilot.

**Important:** After making changes to source files, run:

```bash
make sync
```

This copies updated files to `.github/` so they're available for use. The sync verification workflow in CI will fail if `.github/` is out of sync with source files.

## Contributing

Contributions welcome! Please open an issue or PR.

## License

MIT License - see [LICENSE](LICENSE)

## Related Projects

- [smaqit](https://github.com/ruifrvaz/smaqit) - Spec-driven agent orchestration framework
- [smaqit-sdk](https://github.com/ruifrvaz/smaqit-sdk) - Agent development toolkit
