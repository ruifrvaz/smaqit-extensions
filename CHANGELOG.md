# Changelog

All notable changes to smaqit-extensions will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
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
