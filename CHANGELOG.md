# Changelog

All notable changes to smaqit-extensions will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Breaking Changes (v0.3.0)

**⚠️ This is a breaking change release**

- **Installer now scaffolds `.smaqit/` instead of `docs/`**
  - All task tracking, history, and testing artifacts now use `.smaqit/{tasks,history,user-testing}/`
  - Removed all backwards compatibility with `docs/` structure
  - Projects using smaqit-extensions must update file operations to `.smaqit/`

### Added
- Root-level `Makefile` with `sync` command for dogfooding workflow
- `.github/{agents,prompts,skills}/` directories populated from source files
- Sync verification workflow (`.github/workflows/test-sync.yml`) to ensure `.github/` stays in sync
- Full dogfooding setup: repository now uses its own agents and prompts
- **Auto-confirm mode for release agent** - supports autonomous execution without interactive prompts
  - Detects pre-approved versions in issue/task descriptions (e.g., `**Approved version:** vX.Y.Z`)
  - Detects auto-confirm flag (e.g., `**Auto-confirm:** true`)
  - Detects version in issue titles (e.g., "Release v0.3.0")
  - Enables releases via Copilot Coding Agent and CI/CD pipelines

### Changed
- Installer creates `.smaqit/{tasks,history,user-testing}/` directories (not `docs/`)
- All agents and skills updated to reference `.smaqit/` paths
- Integration tests verify `.smaqit/` structure (not `docs/`)
- README updated with `.smaqit/` structure and dogfooding instructions
- **Release agent refactored** - auto-confirm documentation moved from descriptive section to Input/Directives pattern
  - Auto-confirm patterns documented in Input section
  - Step 3 uses directive style (Agent MUST) instead of descriptive style
  - Reduced file size by 80 lines while maintaining all functionality

### Removed
- All `docs/` directory references and backwards compatibility
- Migration logic for transitioning from `docs/` to `.smaqit/`

### Migration Guide

**For Projects Using smaqit-extensions:**
1. Move content from `docs/` to `.smaqit/`:
   - `docs/tasks/` → `.smaqit/tasks/`
   - `docs/history/` → `.smaqit/history/`
   - `docs/user-testing/` → `.smaqit/user-testing/`
2. Update any custom scripts or automations to reference `.smaqit/` instead of `docs/`
3. Remove the old `docs/` directory if no longer needed

**For Repository Contributors:**
- After modifying source files (`agents/`, `prompts/`, skill directories), run `make sync` before committing
- CI will fail PRs where `.github/` is out of sync with source files

### Added (from previous work)
- Agent Skills Spec adoption with 8 root-level skill directories
  - `session-start/SKILL.md` - Load full project context
  - `session-finish/SKILL.md` - Document session history
  - `session-assess/SKILL.md` - Critical assessment before action
  - `session-title/SKILL.md` - Generate session titles
  - `task-create/SKILL.md` - Create tasks with auto-numbering
  - `task-list/SKILL.md` - Show active tasks
  - `task-complete/SKILL.md` - Mark tasks completed
  - `test-start/SKILL.md` - Initialize testing workflows
- Installer now copies skills to `.github/skills/` directory
- Skills include metadata with version 0.1.0

### Changed
- Prompts are now lightweight stubs that reference corresponding skills
- Updated installer to embed and install skills alongside prompts and agents
- Updated integration tests to verify skills installation
- Agents updated with skill recommendations where relevant

## [0.1.0] - 2026-02-05

### Added
- Session management prompts
  - `session.start.prompt.md` - Load full project context
  - `session.assess.prompt.md` - Analyze requests before implementation
  - `session.finish.prompt.md` - Document session history
  - `session.title.prompt.md` - Generate session titles
- Task tracking prompts
  - `task.create.prompt.md` - Create new tasks with auto-numbering
  - `task.list.prompt.md` - Show active tasks
  - `task.complete.prompt.md` - Mark tasks completed
- Testing workflow prompts
  - `test.start.prompt.md` - Initialize testing workflows
- Utility agents
  - `smaqit.release.agent.md` - Automated release management
  - `smaqit.user-testing.agent.md` - End-to-end testing
- Go-based installer for cross-platform installation
- Bash install script with version mode support

[0.1.0]: https://github.com/ruifrvaz/smaqit-extensions/releases/tag/v0.1.0
