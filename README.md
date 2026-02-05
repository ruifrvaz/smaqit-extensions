# smaqit-extensions

**Quality-of-life extensions for smaqit development workflows**

A collection of prompts and agents that streamline session management, task tracking, and testing workflows. While designed for smaqit development, these utilities work with any structured development workflow.

## What's Included

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
- `prompts/` - 8 workflow prompts
- `agents/` - 2 utility agents

## Usage

After installation, invoke prompts in GitHub Copilot:

```
User: /session.start
User: /task.create Implement new feature
User: /session.finish
```

Agents are available in GitHub Custom Agents:
```
@smaqit.release
@smaqit.user-testing
```

## Requirements

- GitHub Copilot with prompt/agent support
- Project with `.github/` directory structure

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
