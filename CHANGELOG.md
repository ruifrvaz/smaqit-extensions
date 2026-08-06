# Changelog

All notable changes to smaqit-extensions will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Dogfooding mirror drift guard** — `make sync` now also regenerates root `.claude/{agents,commands,skills}` from canonical source, and `make smoke-test` asserts this repo's own `.claude/` mirror matches the generated staging trees. Previously only `.github/` and `.agents/` were kept in sync automatically; `.claude/` could silently drift indefinitely with no error.
- **Framework-scope gate in `smaqit.task-plan`** — a plan whose Relevant Files touch canonical `skills/`/`agents/` source or a generated platform mirror now surfaces a dedicated Framework Impact section (affected component, why it belongs there, application-owned alternative considered) as part of the single plan approval, instead of proceeding as if it were an ordinary application-local change.
- Hermetic regression suite for `smaqit.project-research`'s `verify-urls.sh`, exercised against a local HTTP fixture server.

### Fixed
- **`verify-urls.sh` four-column contract** — the script now actually parses the `TOOL/SECTION/URL/LAYER` format `smaqit.project-research/SKILL.md` has documented; previously `LAYER` was silently appended onto the URL with an embedded tab, corrupting every request. It now accepts any `2xx` status (not just literal `200`), falls back to a single bounded GET when HEAD is rejected, and preserves `LAYER` through to a five-field output.
- **Assisted-mode completion semantics** — `smaqit.task-complete` and its `RULES.md` (synced identically across `task-start`, `task-complete`, and `task-list`) now consistently state that an agent may execute completion once the user explicitly requests it in chat, not only via the literal `/task.complete` command, while still prohibiting self-initiated completion.
- **`smaqit.session-finish` compendium instructions** — removed instructions to maintain a `Sessions` counter and `Last Updated` field per compendium entry, which directly contradicted `COMPENDIUM_FORMAT.md`'s explicit prohibition on per-entry dates and session counters.

## [1.12.0] - 2026-08-06

### Added
- **Task state isolation to main worktree** — task worktrees now exclude `.smaqit/tasks/` via sparse checkout. `smaqit.task-start` and `smaqit.task-complete` read and write task state (PLANNING.md + task files) exclusively on main, eliminating merge conflicts on PLANNING.md across parallel worktrees. The lifecycle resolver maps branches to worktrees via `git worktree list`. Task-awareness checks at start surface concurrent in-progress work; completion verifies finalization on main.

### Fixed
- Collapse redundant double-approval in `smaqit.task-plan` Mode A.
- Resync `.claude/` skill mirrors that drifted from canonical source — `smaqit.release-git-local` and `smaqit.release-git-pr` now match their canonical `skills/` counterparts.
- Install `ripgrep` in CI integration workflow before running the smoke test suite.

## [1.11.0] - 2026-08-01

### Added
- **Release automation workflow bootstrap** — `smaqit-extensions init`/`update` now deploy a generic, project-agnostic `.github/workflows/post-merge-release.yml` (tag on merge + GitHub Release, no build step) create-if-absent, so `smaqit.release.pr` and `smaqit.release-git-local` have working post-merge automation out of the box instead of assuming a workflow the installer never shipped.

### Fixed
- **Release agent/skill accuracy** — `smaqit.release.pr`, `smaqit.release-git-pr`, and `smaqit.release-git-local` no longer claim guaranteed binary builds as part of post-merge automation; they describe the generic tag+release behavior the installed workflow actually provides and point to the workflow file for any project-added build steps.

## [1.10.0] - 2026-07-29

### Added
- **Claude Code dogfooding mirror** — the generated `.claude/` agents, commands, and skills are now tracked in this repository, so running `smaqit-extensions update` no longer leaves its installed Claude assets untracked.
- **Parent-owned subtask lifecycle** — an optional `Parent: NNN` task relationship lets sequential child tasks share one parent branch and worktree, inherit its workflow mode, and retain independent task state and findings.

### Changed
- **Task lifecycle safeguards** — task creation, start, completion, listing, templates, worktree guidance, CI, and hermetic topology tests now enforce parent/child ownership while preserving standalone task behavior.

## [1.9.1] - 2026-07-29

### Fixed
- **Task worktree platform visibility** — sparse task worktrees now retain project-owned configuration, including `.github/workflows/`, while excluding only generated agent and skill mirrors. Sparse configuration failures fall back to a usable full checkout.
- **VS Code workspace visibility** — generated multi-root workspaces now exclude only build output and no longer hide `.github`, `.claude`, `.agents`, or `.codex` from the primary or linked roots.

## [1.9.0] - 2026-07-26

### Added
- **Task worktree workflow** — `smaqit.task-start` now creates a task branch and sibling worktree, while `smaqit.task-complete` merges the branch, removes its worktree, deletes the merged branch, and refreshes the VS Code multi-root workspace.
- **`smaqit.utils.worktree` skill** — adds the complete branch/worktree workflow for generic project names and installer distribution across Copilot, Claude Code, and Codex, including sparse checkout, workspace synchronization, failure contracts, and explicit VS Code chat-session migration.

### Changed
- **29-skill distribution** — installer help, generated trees, dogfooding mirrors, and documentation include the worktree skill.
- **Skill execution contract** — generated project instructions require agents to execute documented skill scripts in order without skipping or streamlining their side effects.

### Fixed
- **Local and PR release boundary compatibility** — release analysis and changelog preparation now recognize both exact `Release vX.Y.Z` local markers and `Prepare release vX.Y.Z` PR markers, preventing older PR markers from being selected after a local release.

## [1.8.0] - 2026-07-23

### Added
- **In-progress task gate in `smaqit.session-finish` (v0.9.0)** — before creating the session history file, the skill now scans `.smaqit/tasks/PLANNING.md` for tasks still marked "In Progress". If any are found, the finish stops and instructs the user to complete them with `task.complete [id]` first (or say "skip" to proceed). Prevents sessions from closing with unfinished tracked work.

## [1.7.1] - 2026-07-23

### Fixed
- **`smaqit.test-create` stack-agnostic rewrite** — the skill was hardcoded to a .NET/Discord/orchestrator stack (`dotnet build`, `orchestrator-start.sh`, `journalctl -u project-orchestrator`, `wscat ws://localhost:5000/ws`). It now probes the project for build/test/deploy/health-check commands by checking Makefile, package.json, pyproject.toml, go.mod, Cargo.toml, *.sln, AGENTS.md/CLAUDE.md, and specs/stack/*.md. The live-service E2E section derives verification from the project's actual interfaces (HTTP, WebSocket, bot, event-driven) instead of a fixed service enum. `references/playbook-template.md` is now a true template with `{placeholder}` tokens. Skill version bumped to 2.0.0.

## [1.7.0] - 2026-07-22

### Added
- **Desktop Linux SSH-agent recovery** — local release agents and the Git release skill now discover already-running GCR, GNOME Keyring, GnuPG, and OpenSSH session sockets on WSL2/WSLg, native Ubuntu/GNOME, and XFCE, then retry an explicitly authorized failed SSH operation once with a command-scoped socket so the desktop unlock or confirmation prompt can appear. The shared project-instructions template used for `CLAUDE.md` documents the same safeguards against persistence or broader authorization. (9465bd5, 7740741)

### Fixed
- **Nested-directory project targeting** — bare `init`, `update`, and `uninstall` commands now detect the enclosing Git worktree root instead of writing into the current subdirectory. Outside Git they use the nearest `.smaqit` ancestor, while explicit `init <dir>` continues to honor the supplied directory exactly. Regression coverage reproduces an accidental `scripts/.smaqit` installation and verifies implicit commands still target the repository root. (f58d89b, 7740741)
- **Existing project instructions during `smaqit.project-init`** — initialization now reads and inferentially merges existing `AGENTS.md`, `CLAUDE.md`, and `.github/copilot-instructions.md` instead of aborting when the active platform file exists. The synchronized result uses canonical root `AGENTS.md`, a Claude `@AGENTS.md` importer with Claude-only additions, and a relative Copilot symlink to `../AGENTS.md`; explicit rules are preserved, conflicts are surfaced before writing, and repeat runs are idempotent. Claude Code's known upstream limitation for ancestor imports during some subdirectory launches is documented by the skill. (733d2f6, 7740741)

## [1.6.1] - 2026-07-21

### Changed
- **Release documentation** — recorded the v1.6.0 Codex installer release context in the project compendium and session history. (e3c56af)

### Fixed
- **Self-update asset refresh** — after replacing the installer binary, `smaqit-extensions update` now launches the newly installed executable to re-initialize project assets, preventing stale compile-time embedded content from the old process from being written back to the project. Added regression tests and made the smoke-test gate run the Go test suite. (9c36d1d)

## [1.6.0] - 2026-07-21

### Added
- **Codex support (third install target)** — `smaqit-extensions init` now compiles and installs repository skills to `.agents/skills/` and project custom agents to `.codex/agents/*.toml`, with platform-aware substitutions for Codex project conventions. Canonical content remains in root `agents/` and `skills/`; generated `installer/{agents-codex,skills-codex}/` trees are ephemeral build inputs only. (71a90d2)
- **Local installer smoke test** — `make smoke-test` builds the current development installer, provisions an isolated temporary project, verifies all Copilot, Claude Code, Codex, template, and `.smaqit` outputs against the generated embed staging trees, validates Codex TOML and platform substitutions, runs uninstall, and confirms cleanup. `KEEP_SMOKE_DIR=1` retains the fixture for inspection. (ff302a0)

### Changed
- **Codex dogfooding mirrors** — `make sync` now maintains `.agents/skills/` and `.codex/agents/` mirrors in this repository, and integration checks validate them alongside the existing Copilot and Claude Code targets. (45fe15c)
- **Compatibility documentation** — README and project guidance now describe the three-target Copilot, Claude Code, and Codex installation model. (b0abcb5)

## [1.5.0] - 2026-07-17

### Added
- **Claude Code support (dual-target install)** — `smaqit-extensions init` now deploys `.claude/{agents,commands,skills}/` alongside the existing `.github/{agents,skills}/` output, unconditionally (no flag needed; GitHub Copilot support is unaffected). Agent bodies (`agents/*.agent.md`, body-only) and skill content (`skills/`) are shared source; per-platform frontmatter lives in `.smaqit/definitions/agents/*.frontmatter.yaml` (`copilot:`/`claude:` sections), and platform-divergent skill *content* (not just frontmatter) is isolated via `{{PLACEHOLDER}}` tokens resolved from `.smaqit/definitions/skills/*.placeholders.yaml`. New `scripts/generate-targets.py` compiles all of this into gitignored `installer/{agents-copilot,agents-claude,commands-claude,skills,skills-claude}/` trees consumed by `//go:embed`, run via `make -C installer prepare` (and by the root `Makefile`'s dogfooding `sync` target, which now compiles rather than raw-copies).
- **`smaqit.project-init` is platform-aware** — generates `.github/copilot-instructions.md` under GitHub Copilot and `CLAUDE.md` under Claude Code from the same shared template, via the new `{{INSTRUCTIONS_FILE}}` placeholder. The shared template's Scaffolding ignore-list now covers both `.github/` and `.claude/` paths.
- **`smaqit.release-git-pr` is platform-aware** — its push step, comparison table, and error-handling entry now correctly describe direct `git push`/`gh` (via Bash) under Claude Code instead of the GitHub Copilot Coding Agent-only `report_progress` tool, which has no Claude Code equivalent.

### Changed
- **`smaqit.project-compendium`** — clarified that entries must state current, as-is facts and conventions, never a historical/incident narrative ("On [date], X broke and was fixed by Y"); session narratives belong in `.smaqit/history/`, incident analysis in `.smaqit/reports/`. Updated the session-finish scan filter and `references/COMPENDIUM_FORMAT.md`'s writing rules accordingly.

### Fixed
- **`smaqit.task-refresh`** — the skill existed only in `.github/skills/` (added directly, bypassing the source-of-truth discipline) with no corresponding `skills/` source and no entry in the root `Makefile`'s dogfooding sync list. Added the missing source file, registered it in `Makefile`, and updated `README.md`'s skill count and Task Tracking list.
- **`smaqit.project-diagnose` skill** — replaced hardcoded `.github/skills/...` install-path references (in `SKILL.md` and `scripts/diagnose-inventory.sh`) with the `[SMAQIT_SKILLS_DIR]` placeholder, resolved per platform at build time
- **`smaqit.project-recap`'s `scan-metadata.py`** — updated to read agent frontmatter from `.smaqit/definitions/agents/*.frontmatter.yaml` instead of the agent source file itself, which is now body-only; previously this would have silently reported zero agents
- **`smaqit.project-diagnose`, `smaqit.project-recap`, `smaqit.project-research`, `smaqit.session-start`** — now mention `CLAUDE.md`/`AGENTS.md` alongside `.github/copilot-instructions.md` as a project-context source
- **`skills/smaqit.project-init/SKILL.md`** — removed a dangling reference to a nonexistent `smaqit.project-zero-to-prod` skill
- **Removed hardcoded, inconsistent, Copilot-only tool names from 9 skills** — `smaqit.session-finish`, `smaqit.session-start`, `smaqit.session-recap`, `smaqit.session-title`, `smaqit.task-create`, `smaqit.task-start`, `smaqit.task-complete`, and `smaqit.task-plan` referenced a `memory` tool (three different, mutually inconsistent conventions: `memory` with `type: workspace`, `store_memory`, and a bare `memory` with a `/memories/session/plan.md` path) and, in `smaqit.task-plan`, the literal VS Code tool ID `vscode_askQuestions` — none of which are real Claude Code tools. All are now conditional, capability-based language ("if a memory capability is available, use it — otherwise the file-based record remains authoritative"), correct on both platforms without any build-time branching. `smaqit.session-finish`/`session-recap`/`session-title` also gained a native-context-first branch for reading session history, falling back to the existing VS Code transcript-log path only when needed.
- **`smaqit.utils.read-pdf`** — its `allowed-tools:` frontmatter (Claude Code-only syntax) named nonexistent tools (`run_in_terminal read_file`) instead of the real `Bash Read`, which would have blocked the skill from using `Read` under Claude Code; also fixed a self-reference to a nonexistent `smaqit.read-pdf` skill directory (should be `smaqit.utils.read-pdf`) and added the missing `[SMAQIT_SKILLS_DIR]` placeholder to its example command

## [1.3.0] - 2026-06-21

### Added
- **`smaqit.test-create` skill v1.0.0** — creates structured E2E test playbooks from task files with build-gate, deploy-gate, and live-service E2E validation (#108)
- **`smaqit.test-complete` skill v1.0.0** — finalizes testing sessions by verifying pass/fail criteria and generating standardized test reports (#108)

### Changed
- **`smaqit.test-start` skill** — refined to delegate report generation to `smaqit.test-complete`; updated directives and workflow phases (#108)
- **`smaqit.user-testing` agent v0.5.0** — updated to hand off report generation to `smaqit.test-complete`; refined directives and tool specifications (#108)
- **Makefile** — added `smaqit.test-create`, `smaqit.test-complete`, `smaqit.task-plan`, `smaqit.task-refresh` to sync list; all 27 skills now synced to `.github/`
- Release version metadata updated to 1.3.0 in installer sources (`installer/main.go`, `installer/Makefile`)

## [1.4.0] - 2026-07-13

### Added
- **`smaqit.project-diagnose` skill v1.1.0** — scans project structure for gaps across testing, security, logging, monitoring, provisioning, and CI/CD domains; produces a prioritised finding report with domain checklists and optional task creation (`project.diagnose`)

### Changed
- **Makefile** — added `smaqit.project-diagnose` to sync list; changed assets copy to recursive (`cp -rfL`) to support nested asset directories
- Release version metadata updated to 1.4.0 in installer sources (`installer/main.go`, `installer/Makefile`)

## [1.2.0] - 2026-06-03

### Added
- **`smaqit.parity-assess` skill v1.0.0** — structured parity assessment skill with Mermaid diagram guide, assessment template, and installer/README sync updates (#107)
- **`smaqit.task-plan` skill v1.0.0** — pre-implementation planning skill that scores task complexity, gathers codebase context in parallel, resolves gaps, and produces execution plans (#106)

### Changed
- **`smaqit.user-testing` agent** — now prohibits ad-hoc bugfixes during test runs, requires diagnosis plus concrete follow-up fixes, and adds a dedicated report section (#109)
- Release version metadata updated to 1.2.0 in installer sources (`installer/main.go`, `installer/Makefile`)

## [1.1.5] - 2026-05-30

### Added
- **`smaqit.task-refresh` skill v1.0.0** — new skill for retroactive task creation at session end; scans session commits and modified files, cross-references against `PLANNING.md` active tasks, and surfaces candidates for task creation to prevent committed work from going untracked (#103)

### Fixed
- **`smaqit update`** — fixed update command to correctly detect platform/arch and handle portable binary detection on non-Linux systems; resolves wrong-arch binary being downloaded on macOS and other platforms (#103)
- Release version metadata updated to 1.1.5 in installer sources (`installer/main.go`, `installer/Makefile`)

## [1.1.4] - 2026-05-24

### Changed
- **smaqit.project-init v0.3.0** — add directory scaffolding step: creates `docs/`, `assets/`, `assets/raw/` if they do not exist (idempotent); updated description to reflect new behaviour

## [1.1.3] - 2026-05-16

### Changed
- **`smaqit.utils.triage-issues` skill** — replaced `gh` CLI dependency with `curl` against the GitHub REST API for repo resolution and issue search; improves compatibility in agent environments where `gh` may be unavailable (#97)
- **`smaqit.user-testing` agent** — decoupled from `.smaqit/tasks`; removed task-file dependency so the agent can run standalone without a task management setup (#99)
- **`smaqit.release-analysis` skill** — refactored change-collection to use `Prepare release vX.Y.Z` commits as the authoritative release boundary instead of git tags and `gh pr list`; eliminates missed entries caused by shallow clones and incorrectly-ordered PR timestamps
- **`smaqit.release-prepare-files` skill** — aligned reconciliation step to use the same `Prepare release` commit boundary as `smaqit.release-analysis`
- Release version metadata updated to 1.1.3 in installer sources (`installer/main.go`, `installer/Makefile`)

## [1.1.2] - 2026-05-15

### Changed
- **`smaqit.compendium` skill** — renamed to `smaqit.project-compendium` for consistent naming across all project-scoped skills; updated references in `smaqit.session-finish`, Makefile, and README (#93)

## [1.1.1] - 2026-05-15

### Fixed
- **`smaqit init`/`smaqit update`** — fixed inflated skill count reported at the end of the install/update run; the counter now increments once per unique skill directory rather than once per file walked inside skills/; corrected static help text from "20 workflow skills" to "22 workflow skills" (#88)

## [1.1.0] - 2026-05-15

### Changed
- **`smaqit.project-glossary` skill** — refactored to section-based markdown format; replaced category tables with `## Category` headings and plain term lists; removed per-term metadata columns; extracted `assets/GLOSSARY_TEMPLATE.md` for consistent scaffolding (#77)
- **`smaqit.compendium` skill** — refactored to section-based markdown format; replaced Q&A table with `## Category` headings and plain entry lists; extracted `assets/COMPENDIUM_TEMPLATE.md`; simplified `references/COMPENDIUM_FORMAT.md` (#80)
- Release version metadata updated to 1.1.0 in installer sources (`installer/main.go`, `installer/Makefile`)

### Fixed
- **Release agents** (`smaqit.release-analysis`, `smaqit.release-prepare-files`, `smaqit.release-git-pr`) — added `gh pr list` fallback and cross-check to recover changelog entries missed in shallow/grafted clones (#84)
- **Post-merge release workflow** — repaired automation trigger condition and corrected incomplete changelog coverage for prior releases (#84)

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

[Unreleased]: https://github.com/ruifrvaz/smaqit-extensions/compare/v1.12.0...HEAD
[1.12.0]: https://github.com/ruifrvaz/smaqit-extensions/compare/v1.11.0...v1.12.0
[1.11.0]: https://github.com/ruifrvaz/smaqit-extensions/compare/v1.10.0...v1.11.0
[1.10.0]: https://github.com/ruifrvaz/smaqit-extensions/compare/v1.9.1...v1.10.0
[1.9.1]: https://github.com/ruifrvaz/smaqit-extensions/compare/v1.9.0...v1.9.1
[1.9.0]: https://github.com/ruifrvaz/smaqit-extensions/compare/v1.8.0...v1.9.0
[1.8.0]: https://github.com/ruifrvaz/smaqit-extensions/compare/v1.7.1...v1.8.0
[1.7.1]: https://github.com/ruifrvaz/smaqit-extensions/compare/v1.7.0...v1.7.1
[1.7.0]: https://github.com/ruifrvaz/smaqit-extensions/compare/v1.6.1...v1.7.0
[1.6.1]: https://github.com/ruifrvaz/smaqit-extensions/compare/v1.6.0...v1.6.1
[1.6.0]: https://github.com/ruifrvaz/smaqit-extensions/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/ruifrvaz/smaqit-extensions/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/ruifrvaz/smaqit-extensions/compare/v1.2.0...v1.4.0
[1.3.0]: https://github.com/ruifrvaz/smaqit-extensions/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/ruifrvaz/smaqit-extensions/compare/v1.1.5...v1.2.0
[1.1.5]: https://github.com/ruifrvaz/smaqit-extensions/compare/v1.1.4...v1.1.5
[1.1.4]: https://github.com/ruifrvaz/smaqit-extensions/compare/v1.1.3...v1.1.4
[1.1.3]: https://github.com/ruifrvaz/smaqit-extensions/compare/v1.1.2...v1.1.3
[1.1.2]: https://github.com/ruifrvaz/smaqit-extensions/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/ruifrvaz/smaqit-extensions/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/ruifrvaz/smaqit-extensions/compare/v1.0.1...v1.1.0
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
