# smaqit-extensions

**Quality-of-life workflow prompts and agents (smaqit-extensions)**

A collection of prompts and agents that streamline session management, task tracking, release, and testing workflows.

These `smaqit`extensions are designed to work out of the box in any repository (no `smaqit init`, no `.smaqit/`, no `specs/`, no `framework/` required).

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

### Utility Agents
- **smaqit.release** - Automated release management
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
- `agents/` - 2 utility agents
- `skills/` - 8 workflow skills (complete implementations)

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
@smaqit.release
@smaqit.user-testing
```

## Requirements

- GitHub Copilot with prompt/agent support
- A git repository (recommended)

The installer writes files under `.github/prompts/` and `.github/agents/` and will create the `.github/` folder if it doesn't exist.

The installer also scaffolds the docs artifacts used by the prompts:
- `docs/tasks/PLANNING.md`
- `docs/tasks/`
- `docs/history/`
- `docs/user-testing/`

## Development

```bash
cd installer
make build    # Build installer
make test     # Test installer
```

## Contributing

Contributions welcome! Please open an issue or PR.

## License

MIT License - see [LICENSE](LICENSE)

## Related Projects

- [smaqit](https://github.com/ruifrvaz/smaqit) - Spec-driven agent orchestration framework
- [smaqit-sdk](https://github.com/ruifrvaz/smaqit-sdk) - Agent development toolkit
