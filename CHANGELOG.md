# Changelog

All notable changes to smaqit-extensions will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.0] - 2026-02-13

### Added
- **Task tracking system** - `.smaqit/tasks/` directory structure for managing development tasks
  - `PLANNING.md` - Central task overview with status tracking
  - Individual task files with acceptance criteria and notes
- **Unified post-merge-release workflow** - Single automated workflow handling complete release pipeline
  - Triggers on PR merge with release title pattern
  - Creates git tags automatically
  - Builds binaries for all platforms (Linux, macOS, Windows on amd64/arm64)
  - Publishes GitHub Release with binaries and changelog
  - Eliminates GITHUB_TOKEN workflow trigger limitation

### Fixed
- **Critical release automation bug** - GITHUB_TOKEN preventing workflow chaining
  - Merged `post-merge-tag.yml` and `release.yml` into single workflow
  - Release now completes automatically without manual tag creation
  - Fixes broken v0.4.0 release that required manual intervention

### Changed
- **Project structure** - Consolidated skills into organized `skills/` directory
  - Moved 13 skill directories from root into `skills/` folder
  - Matches organizational pattern of `agents/` and `prompts/` directories
  - Updated build process and sync workflows for new structure
- **Release PR agent integration** - Updated documentation for unified workflow
  - Removed manual tag creation instructions
  - Documents automatic post-merge release process

## [0.3.0] - 2026-02-12

### Added
- **Release skills** - 5 composable skills for release workflows
  - `release-analysis` - Collect changes, assess severity, suggest version
  - `release-approval` - Obtain approval (auto-confirm or interactive)
  - `release-prepare-files` - Validate git state and prepare files
  - `release-git-local` - Execute git operations for local releases
  - `release-git-pr` - Execute git operations for PR-based releases
- **New release agent: `smaqit.release.local`** - Local release workflow
  - Lean skill-based architecture (~93 lines, reduced from 280 lines)
  - Supports interactive or auto-confirm modes
  - Direct git access for local development
  - Can commit to main and create tags immediately
- **New release agent: `smaqit.release.pr`** - PR-based release workflow for CI/CD
  - Designed for GitHub Copilot Coding Agent triggered by issues
  - Uses `report_progress` tool for commits (no direct git credentials needed)
  - Auto-confirm mode required (no interactive prompts in CI)
  - Documents post-merge tag creation instructions
  - Tags created manually or via workflow after PR merge to main

### Changed
- README updated with release skills and both release agents

### Removed
- **`smaqit.release` agent** - Replaced by explicit `smaqit.release.local` and `smaqit.release.pr` agents

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
- Skills include metadata with version 0.1.04.0...HEAD
[0.4.0]: https://github.com/ruifrvaz/smaqit-extensions/compare/v0.3.0...v0.4.0

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

[Unreleased]: https://github.com/ruifrvaz/smaqit-extensions/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/ruifrvaz/smaqit-extensions/compare/v0.1.0...v0.3.0
[0.1.0]: https://github.com/ruifrvaz/smaqit-extensions/releases/tag/v0.1.0
