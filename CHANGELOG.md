# Changelog

All notable changes to smaqit-extensions will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.4] - 2026-05-15

### Changed
- **`smaqit.project-glossary` skill** — refactored to section-based markdown format; replaced category tables with `## Category` headings and plain term lists; removed per-term metadata columns; extracted `assets/GLOSSARY_TEMPLATE.md` for consistent scaffolding
- **`smaqit.compendium` skill** — refactored to section-based markdown format; replaced Q&A table with `## Category` headings and plain entry lists; extracted `assets/COMPENDIUM_TEMPLATE.md`; simplified `references/COMPENDIUM_FORMAT.md`
- Release version metadata updated to v1.0.4 in installer sources (`installer/main.go`, `installer/Makefile`)

## [1.0.1] - 2026-05-14

### Changed
- **`smaqit.project-recap` skill** — enhanced with Git-based Situation Report section and assessment-driven Next Steps; output format updated in `references/OUTPUT_FORMAT.md`
- **`smaqit.release-prepare-files` skill** — added reconciliation step that queries `git log` since the last tag and ensures `[Unreleased]` is complete before promoting to a versioned section
- Removed redundant `Purpose` and `Invocation` sections from `smaqit.compendium`, `smaqit.project-glossary`, `smaqit.project-recap`, and `smaqit.project-research` skill files; preserved all useful context

### Fixed
- **`smaqit update` re-initialization** — `smaqit update` now re-initializes project assets (`.smaqit/`) when the local version is already up-to-date or newer than the latest release, not only when a binary download occurs
- **smaqit.utils.triage-issues v1.2.0** — fixed repo resolution so triage no longer depends on the nonexistent `.smaqit/references/github-repos-registry.md`
  - Resolves `owner/repo` from GitHub URLs already present in `.smaqit/references/project-research.md`
  - Falls back to `gh search repos` for tools not found in the research map and records unresolved tools without skipping triage
  - Clarifies the skill description, scope, and failure handling around repo resolution

## [1.0.0] - 2026-05-10

### Added
- **`smaqit-extensions update` command** — self-update the binary to the latest GitHub release (Linux only)
  - Queries GitHub API for latest release and compares using semver
  - Downloads linux-amd64 binary asset to a temp file, sets executable bit, atomically replaces the running binary (cross-filesystem fallback included)
  - If current directory contains `.smaqit/`, automatically re-runs `init` to deploy updated agents, skills, and templates without overwriting project state
  - Reports "Already up to date" when local version matches latest
  - All error paths print clear messages and exit non-zero without corrupting the binary
- **`smaqit.compendium` skill v0.1.0** — live Q&A knowledge manifest manager
  - Manages `.smaqit/compendium.md` with list, fetch, update, and remove operations
  - Semantic search across Q&A entries grouped by category
  - Upserts Q&A pairs (add or update) and removes entries with confirmation
  - Output format defined in `references/COMPENDIUM_FORMAT.md`
- **`smaqit.project-recap` skill v0.1.0** — live project dashboard generator
  - Generates a structured project dashboard written to `.smaqit/project-recap.md`
  - `project.recap` generates the dashboard; `project.recap --refresh` forces re-scan
  - Script-based scanning via `scripts/scan-metadata.py` (requires `uv`); falls back to sequential frontmatter reads when `uv` is unavailable
  - Output format defined in `references/OUTPUT_FORMAT.md`
- **`smaqit.project-research/references/DOC_PLATFORMS.md`** — curated documentation platform registry used by the research skill

### Changed
- **`smaqit.project-research` v1.2.0** — documentation topology improvements
  - Added `references/DOC_PLATFORMS.md` as a curated registry of documentation platforms and URL patterns
  - Trimmed skill description to lean, inferred-invocation pattern
- **`smaqit.task-create` v0.5.0** — task template now sourced from `assets/TASK_TEMPLATE.md`; standardized task file structure
- **`smaqit.task-complete` v0.6.0** — updated verification logic and task status recording
- **`smaqit.task-start` v0.7.0** — workflow improvements to mode determination and research map integration
- **`smaqit.session-finish` v0.8.0** — updated compendium integration step; aligned with smaqit.compendium skill
- **`smaqit.session-start` v0.8.0** — updated compendium integration step; aligned with smaqit.compendium skill
- **Makefile** — added `smaqit.project-recap` and `smaqit.task-create` assets to sync list; skill count updated to 22

### Fixed
- Code review feedback on `update` command: improved error handling and HTTP status code usage
- `http.StatusTooManyRequests` constant replaces literal `429`; `io.Copy` error now properly wrapped
- Removed erroneous `Invocation` section from `smaqit.project-recap` SKILL.md

## [0.10.0] - 2026-05-05

### Added
- **smaqit.utils.triage-issues skill v1.1.0** — pre-implementation GitHub issue triage gate
  - Searches upstream GitHub repos for open bugs/regressions matching a task's components before implementation begins
  - Reads `.smaqit/references/github-repos-registry.md` to resolve tool names to `owner/repo` pairs
  - Classifies results as Blocking, Advisory, Historical, or Clear
  - Blocking issues halt `smaqit.task-start` and require user direction before proceeding
  - Output written to task file as `## Known Issues Triage` block (format defined in `references/TRIAGE_BLOCK.md`)
  - Invokable standalone as `task.triage [id]` or automatically via `smaqit.task-start` Step 2a
- **smaqit.project-research/references/RESEARCH_MAP.md** — canonical output format template for project research map
- **smaqit.utils.triage-issues/references/TRIAGE_BLOCK.md** — canonical output format template for triage block
- **scripts/recap.py** in smaqit.session-finish, smaqit.session-recap, smaqit.session-title — compact transcript extractor for sessions ≥ 500 lines

### Changed
- **smaqit.task-start v0.6.0** — new Step 2a: invokes `smaqit.utils.triage-issues` after research map verified, before mode determination; full gate behavior with blocking/advisory/clear paths
- **smaqit.project-research v1.1.0** — output format redesigned: project table and task block are now separate; `Task-relevant` column removed; task-specific URLs grouped under `## Task NNN — [title]` heading; `RESEARCH_MAP.md` template extracted to `references/`
- **smaqit.session-finish v0.7.0** — Step 0: conditional transcript handling; < 500 lines reads directly, ≥ 500 lines runs `scripts/recap.py` to extract user + assistant messages
- **smaqit.session-recap v0.4.0** — same Step 0 conditional as session-finish
- **smaqit.session-title v0.4.0** — same Step 0 conditional as session-finish
- **Makefile** — added `smaqit.project-glossary` and `smaqit.utils.triage-issues` to sync skill list; skill count corrected to 20

### Changed
- **smaqit.session-finish v0.6.0** — Step 0 rewritten: reads full session from the JSONL transcript (derived from `{{VSCODE_TARGET_SESSION_LOG}}`); uses first user message (`session.start` invocation) as the guaranteed session anchor; removes unreliable `<conversation-summary>` block logic
- **smaqit.session-recap v0.3.0** — new Step 0 added: reads full session from transcript before enumerating steps; Step 2 updated to enumerate from the loaded arc
- **smaqit.session-title v0.3.0** — new Step 0 added: reads full session from transcript before generating title; Step 1 updated to review the loaded arc

## [0.9.6] - 2026-05-03

### Added
- **smaqit.project-research skill v1.0.0** — project-scoped documentation topology mapper
  - Two-layer model: project layer (full stack from manifests + copilot instructions) always runs; task layer (task-specific relevance annotation) runs only when a task is active or specified
  - Discovers section-level documentation URLs using agent knowledge, `fetch_webpage`, `github_repo`, and `github_text_search`
  - Verifies URL liveness via bundled `scripts/verify-urls.sh` (curl --head; follows redirects; discards 4xx/5xx)
  - Writes persistent map to `.smaqit/references/project-research.md` (one file per project, not per task)
  - Output includes `Task-relevant` annotation column when a task is active
  - Satisfies `smaqit.utilities.triage-issues` (Task 022) contract: `Tool | Section | URL | Status` table
  - Gracefully handles unreachable tools, unknown tools, missing manifests, and missing `.smaqit/references/`

### Changed
- **smaqit.task-start v0.5.0** — new Step 2: research map verification; checks for `.smaqit/references/project-research.md` before implementation; invokes `smaqit.project-research` automatically if absent; surfaces map in-context
- **smaqit.utils.read-pdf** — renamed from `smaqit.utilities.read-pdf` to `smaqit.utils.read-pdf` to align with `smaqit.utils.*` namespace convention
- **README** — Project Management section completed (`smaqit.project-init` added, `smaqit.project-research` moved from Utilities); Utilities section corrected
- **Makefile** — updated skill references for renamed skills
- **installer/main.go** — skill count updated to 18

## [0.9.5] - 2026-05-02

### Added
- **smaqit.project-glossary skill v1.0.0** — new skill for managing a per-project glossary at `.smaqit/glossary.md`
  - Four trigger phrases: `list glossary`, `fetch from glossary [term]`, `update glossary [term]`, `remove from glossary [term]`
  - `update glossary` implements upsert semantics (adds term if absent, edits if present)
  - `remove from glossary` requires confirmation before deletion; cleans up empty category sections
  - Glossary stored as category-grouped markdown tables (Term | Definition | Category)
  - Handles missing glossary file gracefully on all read operations

### Changed
- **smaqit.session-start v0.7.0** — new step 4: conditionally loads `.smaqit/glossary.md` into session context at startup (skipped silently if file does not exist)
- **README** — added Project Management section with `smaqit.project-glossary`; updated skill count to 18

## [0.9.4] - 2026-05-02

### Changed
- **smaqit.utilities.read-pdf** — renamed from `smaqit.read-pdf` to `smaqit.utilities.read-pdf` to align with the utilities skill namespace convention
- **README** — added Utilities section; updated skill count to 17
- **Makefile** — updated skill reference from `smaqit.read-pdf` to `smaqit.utilities.read-pdf`


## [0.9.3] - 2026-05-02

### Added
- **smaqit.read-pdf skill v0.1.0** — new skill for extracting text from PDF files using `pdftotext`
  - Writes a `.extracted.txt` sidecar next to the source PDF
  - Checks for `poppler-utils` at runtime and surfaces install instruction if missing
  - Continues with the caller's original goal after extraction (mid-request pipeline step)
  - Includes `scripts/extract.sh` — self-contained bash wrapper with `[CHECK]`/`[OK]`/`[ERROR]` output

### Changed
- **Makefile sync** — added `smaqit.read-pdf` to the skill list; added `scripts/` directory handling so skill scripts are synced to `.github/skills/` alongside `SKILL.md`

## [0.9.2] - 2026-04-24

### Added
- **Session-recap skill v0.2.0** — new skill for summarizing session progress as a structured table (PR #43)
  - `smaqit.session-recap` skill invoked when user asks for a "recap", "review", or "progress" of the session
  - Renders a strict 3-column table (Step / Status / Notes) covering every significant session action
  - Includes `references/TABLE.md` template enforcing consistent table layout and emoji status indicators (✅ Done, ⏳ Pending, 🚫 Blocked, 🗑️ Abandoned)
- **Project-init skill v0.2.0** — new skill to bootstrap a smaqit project by generating `.github/copilot-instructions.md` from a template (PR #45)
  - Infers project details (name, description, tech stack) from the repository instead of asking the user
  - Installs `copilot-instructions.template.md` in `.smaqit/templates/` via the installer
- **`.smaqit/templates/` directory** — canonical task and planning templates installed by the Go installer (PR #47)
  - `task.template.md` — standard task file scaffold used by `task-create`
  - `PLANNING-template.md` — standard planning file scaffold
  - Installer creates templates in `.smaqit/templates/` with non-overwriting logic to preserve local customizations

### Changed
- **Task skills refactored to reference templates** — `task-create`, `task-start`, and `task-complete` now reference canonical templates in `.smaqit/templates/` (PR #47)
- **Installer: dynamic uninstall** — `smaqit-extensions uninstall` now removes all skills present in the binary rather than a hard-coded list, ensuring newly added skills are always cleaned up (PR #45)

### Fixed
- **Session-finish skill v0.5.2** — added preflight step to handle `<conversation-summary>` blocks correctly; improved classification of session content (PR #49)
- **Session-start skill v0.6.1 / Session-finish skill v0.5.2** — switched from deprecated `store_memory` to `memory` tool with `type: workspace` for cross-branch context (PR #41)

## [0.9.1] - 2026-04-06

### Fixed
- **Session-finish skill v0.4.1** — treat `<conversation-summary>` blocks as current session content, not prior session context
  - Previously, a `<conversation-summary>` block was misclassified as background from a previous session
  - It now correctly represents work done earlier in the same session arc and is included in the history file

## [0.9.0] - 2026-04-05

### Changed
- **Removed prompts directory** — Skills are now the sole instruction component
  - All prompt stubs (`session.start`, `session.assess`, `session.finish`, `session.title`, `task.*`, `test.start`) removed
  - Skills in `skills/` and `.github/skills/` are the canonical instruction source
  - Simplifies the architecture and reduces duplication between prompts and skills
- **Documentation refactored** to align with skills-only architecture
  - Updated README to reflect current skills-based structure

## [0.8.0] - 2026-04-02

### Changed
- **Session-start skill v0.5.0** - Memory is now primary source for session context
  - Memory entries for `"session history"` and `"next steps"` read first on session start
  - File-based history (`.smaqit/history/`) used as fallback/supplement
  - Ensures cross-branch continuity when working on parallel or feature branches
- **Session-finish skill v0.4.0** - Writes memory facts at session end
  - Stores session history, next steps, and task state via `store_memory` tool
  - Memory entries available across all branches immediately after session close
- **Task-complete skill v0.4.0** - Scope-correct memory integration
  - Task skills now own `"task state"` memory scope
  - Consistent with memory scope separation between session and task skills
- **Task-create skill v0.3.0** - Scope-correct memory integration
  - Task skills now own `"task state"` memory scope
- **Task-start skill v0.3.0** - Scope-correct memory integration
  - Task skills now own `"task state"` memory scope

## [0.7.0] - 2026-03-26

### Added
- **Session-start skill v0.3.0** - New codebase pre-read step before task synthesis
  - Added Step 4: Read codebase for the next unblocked task before presenting summary
  - Identifies source areas the next task would touch (interfaces, abstractions, factories)
  - Step is mandatory — cannot be skipped even if task description appears complete
  - Synthesize step now includes per-task approach assessment against codebase
  - Suggested next steps now explicitly guide which task to start or what to ask

### Changed
- **Installer CLI** - Added `init` subcommand, show help by default when no args given
- **Task-complete skill v0.3.0** - Improved description clarity for agent invocation

### Fixed
- Integration test updated to use `init` subcommand

## [0.6.0] - 2026-02-14

### Changed
- **Release-analysis skill v0.3.0** - Enhanced with file-based change detection
  - Added Step 2B: File changes analysis using `git diff --stat --name-status`
  - Handles grafted/shallow repositories correctly
  - Compares against empty tree SHA (4b825dc...) when no tags exist
  - Updated severity assessment to include file pattern analysis
  - Added notes explaining importance of file-based analysis in incomplete histories
  - Fixes issue where commit-only analysis missed actual file changes in grafted repos

## [0.5.0] - 2026-02-13

### Added
- **Task-start skill** - Start tasks with autonomous or assisted workflow mode
  - `task-start/SKILL.md` - Orchestrate task initiation with mode selection
  - `task-start/references/RULES.md` - Workflow enforcement rules (171 lines)
  - Supports `--autonomous` flag for CI/CD workflows (agent completes task)
  - Supports `--assisted` flag for human workflows (requires user approval at checkpoints)
  - Stores mode in task metadata for enforcement by other skills
- **Task workflow mode awareness** - Updated task-list and task-complete for mode-aware operations
  - `task-list` now loads RULES.md and displays mode indicators
  - `task-complete` enforces assisted mode rules (prevents agent auto-completion)
  - References pattern using symlinks to task-start/references/RULES.md
- **Task.start prompt stub** - New prompt stub referencing task-start skill

### Changed
- **Installer enhancements** - Handles references/ subdirectories within skills
  - Uses `cp -rL` to dereference symlinks during sync
  - Embeds full skill trees including references/ subdirs
  - Installs references/ subdirectories alongside skill files
- **Session-start skill** - Added reference to task workflow in context loading
- **README documentation** - Comprehensive updates for task-start and workflow modes
  - Added task-start usage examples (autonomous vs assisted)
  - Added "Workflow Modes" section explaining the two modes
  - Updated counts (9 prompts, 14 skills, 3 agents)
  - Fixed branding consistency (smaQit with capital Q user-facing)
  - Fixed binary name references (./smaqit-extensions)

## [0.4.2] - 2026-02-13

### Fixed
- **Build job dependency** - Added `tag` to build job needs array
  - Build job was checking `needs.tag.result` without declaring dependency
  - Caused workflow to fail when tag job was skipped (local releases)
  - v0.4.1 workflow will now complete successfully

## [0.4.1] - 2026-02-13

### Fixed
- **Release workflow trigger** - Added tag push trigger to unified release workflow
  - Workflow now triggers on both tag push (local releases) and PR merge (PR-based releases)
  - Fixed artifact path typo: `instabuild]` → `installer/dist/*`
  - Removed duplicate release job definition
  - v0.4.0 release will now complete with binaries and GitHub Release

### Added
- **Copilot instructions** - Added `.github/copilot-instructions.md` for dogfooding workflow
  - Documents `make sync` requirement
  - Explains source vs synced file structure

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

[Unreleased]: https://github.com/ruifrvaz/smaqit-extensions/compare/v1.0.4...HEAD
[1.0.4]: https://github.com/ruifrvaz/smaqit-extensions/compare/v1.0.1...v1.0.4
[1.0.1]: https://github.com/ruifrvaz/smaqit-extensions/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/ruifrvaz/smaqit-extensions/compare/v0.10.0...v1.0.0
[0.9.4]: https://github.com/ruifrvaz/smaqit-extensions/compare/v0.9.3...v0.9.4
[0.9.3]: https://github.com/ruifrvaz/smaqit-extensions/compare/v0.9.2...v0.9.3
[0.9.2]: https://github.com/ruifrvaz/smaqit-extensions/compare/v0.9.1...v0.9.2
[0.9.1]: https://github.com/ruifrvaz/smaqit-extensions/compare/v0.9.0...v0.9.1
[0.9.0]: https://github.com/ruifrvaz/smaqit-extensions/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/ruifrvaz/smaqit-extensions/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/ruifrvaz/smaqit-extensions/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/ruifrvaz/smaqit-extensions/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/ruifrvaz/smaqit-extensions/compare/v0.4.2...v0.5.0
[0.4.2]: https://github.com/ruifrvaz/smaqit-extensions/compare/v0.4.1...v0.4.2
[0.4.1]: https://github.com/ruifrvaz/smaqit-extensions/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/ruifrvaz/smaqit-extensions/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/ruifrvaz/smaqit-extensions/compare/v0.1.0...v0.3.0
[0.1.0]: https://github.com/ruifrvaz/smaqit-extensions/releases/tag/v0.1.0
