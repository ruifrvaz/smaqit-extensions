---
status: In Progress
mode: Assisted
created: "2026-08-20"
started: "2026-08-20"
---

# Confidentiality pre-commit hook (cross-domain secrets/PII scanner)

## Description

A git pre-commit hook that scans every staged file for credential, PII,
and financial-figure patterns and blocks the commit, distributed as its
own installer artifact (not skill-wrapped) with a thin companion skill
for manual invocation. Ports the pattern set and managed-block
hook-chaining approach proven in `agentic-cms`'s classification engine
(`ac-classify`), but scoped for any project rather than CMS content.

This belongs in `smaqit-extensions` specifically because it's cross-domain
and cross-SDLC-phase — unlike `smaqit.infrastructure-hook-pre-commit-validate`
(smaqit core), which is tied to the infrastructure/deployment domain and
the `new-greenfield-project` pipeline. That existing skill's own secret
check (`sk-ant-`, `BEGIN...PRIVATE KEY`, `password/secret/token=`) is
smaller, independently-written prior art for the credential-pattern
shapes — not modified by this task, different repo, out of scope.

Surfaced from a real incident in an installed `agentic-cms` project: a
session-history file and an accidentally-tracked tool-memory directory
both carried sensitive content, undetected because that classifier's
scope is hardcoded to `docs/`+`wiki/`. The detection logic itself
(`floor_level(text)` in `ac-classify`) is already a standalone function —
no frontmatter, no path restriction — proving the capability doesn't need
CMS machinery at all, which is why it belongs as a general git-hygiene
tool instead.

## Issue Triage Context

**Mode:** Auto
**Technologies:** Go, bash, git hooks
**Platforms/Environments:** Linux, macOS, Windows (existing installer's OS detection already covers this)
**Features/Integrations:** installer `main.go` (`installProject`, `writeFileIfMissing`), companion skill system
**Versions/Constraints:** None

## Design Decisions

- **Project-scoped only, no global install path** — git hooks are
  inherently per-repo; unlike skills, there's no meaningful "install this
  hook globally" semantic in this ecosystem.
- **Three different update semantics for three files, resolved
  precisely** (the core technical risk in this task):
  - The detection script (`pre-commit-confidentiality.sh`) →
    **force-overwritten** every install run, mirroring
    `agentic-cms/.agentic-cms/scripts/` — pattern/bug fixes must
    propagate on `update`.
  - The exclude-list (`confidentiality-scan-ignore`) → **seeded once via
    `writeFileIfMissing`, never overwritten after**, mirroring
    `agentic-cms`'s `CONTENT.md` treatment — user-owned after install.
  - `.git/hooks/pre-commit` itself → **neither helper applies.** Bespoke
    logic: if absent, create fresh with a namespaced managed block
    (`>>> smaqit-extensions:begin >>> ... <<< end <<<`) chaining to the
    staged script; if present, replace only that managed block on
    reinstall (idempotent), or append it if the file already has foreign
    content (e.g. `agentic-cms`'s own hook) — never touch content outside
    the block. Reusing `writeFileIfMissing` verbatim here would be wrong:
    it would silently no-op whenever `.git/hooks/pre-commit` already
    exists for any reason, leaving this hook uninstalled with no error.
- **Coexistence with `agentic-cms`'s hook via disciplined namespaced
  managed blocks, not cross-tool detection logic.** As long as each tool
  only ever touches its own block, they append sequentially in the same
  file with zero awareness of each other required — the same principle
  already proven by `CLAUDE.md`'s multi-block convention (`agentic-cms`'s
  block coexists with arbitrary other content there today).
- **Independent implementation, not shared/imported code across repos.**
  Same pattern *shapes* as `ac-classify`'s `floor_level()` (C3:
  credential-shaped strings — private keys, `sk-*`, AWS key IDs, GitHub
  token shapes, `api_key=`/`secret=`/`password=`/`token=`; C2: 6 currency
  shapes, email, SSN-shaped), ported deliberately since these are
  genuinely separate tools with no shared dependency today.
- **No ack mechanism.** A hit's remediation is: exclude the path
  deliberately (`confidentiality-scan-ignore`, reviewed and committed,
  gitignore syntax), remove the sensitive content, or — if the project
  also has `agentic-cms` installed — promote the path into that tool's
  real frontmatter-based rating/ack system instead. This hook is a
  coarse, cross-project net, not a CMS-aware classifier.
- **Delta-scoped** (`git diff --cached --name-only --diff-filter=ACM`),
  not whole-tree — matching the brownfield-adoption lesson already
  learned in `agentic-cms` task 011: whole-tree blocking makes adoption
  impossible in any pre-existing repo with legacy content.
- **Default exclude-list is broader than `agentic-cms`'s own**, since
  this is a general-purpose, cross-language tool: `.git/`, common
  build/dependency directories (`node_modules/`, `vendor/`,
  `.venv/`/`venv/`, `__pycache__/`, `dist/`, `build/`, `target/`,
  `.next/`), and lockfiles specifically (`package-lock.json`,
  `yarn.lock`, `Cargo.lock`, `go.sum`) — their long hash-like strings are
  a concrete, real false-positive source against the credential patterns.
- **Out of scope**: modifying `smaqit.infrastructure-hook-pre-commit-validate`
  (different repo, domain-tied, explicitly not this task) and
  `agentic-cms`'s own task 012 (separate repo/task; shrinks to
  tier-1-only — the docs/wiki frontmatter-based scope-declaration — once
  this ships, not touched here).

## Implementation Steps

1. **Phase 1 — Hook artifact**: add `installer/hooks/pre-commit-confidentiality.sh`
   (embedded via `//go:embed`, sibling to `installer/workflow-templates/`)
   — reads the staged diff, skips binaries and excluded paths, greps
   remaining staged content against the ported C2/C3 pattern set, blocks
   (non-zero exit) on any hit, reports file + line + category. Add
   `installer/hooks/confidentiality-scan-ignore` (embedded default
   exclude-list per the Design Decisions list above).
2. **Phase 2 — Installer wiring** (depends on 1): new
   `installConfidentialityHook(targetDir string)` in `installer/main.go`,
   modeled on `installReleaseWorkflow`'s `fs.WalkDir`/embed mechanics but
   implementing the three distinct update semantics above (force-overwrite
   script, seed-once exclude-list, managed-block `.git/hooks/pre-commit`
   logic). Call it from `installProject`.
3. **Phase 3 — Companion skill** (parallel with 1–2): create
   `skills/smaqit.hooks.confidentiality-scan/SKILL.md`, mirroring
   `smaqit.infrastructure-hook-pre-commit-validate`'s dual-mode shape — a
   "hook installation" section (pointer to the installer, not
   reimplemented) and a "manual invocation" section an agent can run
   interactively, working even in a clone where the hook isn't installed
   yet.
4. **Phase 4 — Verify** (depends on 2–3): tests parallel to
   `TestScaffoldProjectCreatesOnlyProjectTrackingPaths` — fresh install
   creates the hook + exclude-list; reinstall force-updates the script but
   preserves user edits to the exclude-list; installing into a repo with
   an existing non-empty `.git/hooks/pre-commit` appends rather than
   clobbers; a staged fixture with a planted credential string blocks; the
   same path added to the exclude-list doesn't. Run the repo's standard
   build/test target.

## Known Issues Triage
**Triaged:** 2026-08-20
**Tools searched:** Go (`golang/go`), Git (`git/git`)
**Result:** Historical

### Blocking Issues
None.

### Advisory Issues
None.

### Historical (Closed)
- [#68908 go:embed directive path.Match patterns will fail any given valid pattern with "syntax error in pattern" if any parent directory contains '[' or ']' characters which are valid folder names characters in windows](https://github.com/golang/go/issues/68908) — `golang/go` — closed 2024-08-16

### Unresolvable Tools
- Bash — helper resolved to an unrelated namesake repository (`dylanaraps/pure-bash-bible`, a cheatsheet, not the GNU Bash upstream), not a meaningful source of relevant issues; not searched.

### Omitted Tools
None.

### Search Warnings
None.

## Acceptance Criteria

- [ ] `installer/hooks/pre-commit-confidentiality.sh` and `installer/hooks/confidentiality-scan-ignore` exist, embedded and installed via a new `installConfidentialityHook`, called from `installProject`
- [ ] The hook script is force-overwritten on reinstall; the exclude-list is seeded once and never overwritten after
- [ ] `.git/hooks/pre-commit` gets a namespaced managed block (`>>> smaqit-extensions:begin/end`) that is idempotently replaced on reinstall and appended (not clobbering) when the file already has content from another tool
- [ ] A staged file matching a C2/C3 pattern blocks the commit with file+line+category reported; a path listed in the exclude-list does not block
- [ ] Delta-scoped: a pre-existing violation in an unstaged file does not block an unrelated commit
- [ ] `smaqit.hooks.confidentiality-scan` skill exists with hook-installation and manual-invocation sections
- [ ] New tests parallel to `TestScaffoldProjectCreatesOnlyProjectTrackingPaths` cover fresh install, reinstall-preserves-exclude-list, and append-not-clobber
- [ ] `go test ./...` and the repo's standard build/test target pass

## Findings

[Populated by smaqit.task-complete. Do not fill in manually before task is complete.]

**Implementation approach:**
- TBD

**Decisions made:**
- TBD

**Blockers encountered:**
- TBD

**Follow-up identified:**
- TBD

## Notes

Downstream effect on `agentic-cms` (separate repo, not touched by this
task): its own task 012 shrinks to tier-1-only (docs/wiki
frontmatter-based scope declaration) once this ships, and its docs should
point CMS users at this hook for the broader cross-file net rather than
reimplementing it a third time.
