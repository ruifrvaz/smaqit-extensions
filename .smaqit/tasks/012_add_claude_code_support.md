---
status: Completed
mode: Assisted
created: "2026-07-16"
completed: "2026-07-16"
---

# Add Claude Code Support (Dual-Target Install)

## Description

Extend `smaqit-extensions init` to deploy a Claude Code-compatible copy of every agent and skill alongside the existing GitHub Copilot output, so a single install populates both `.github/{agents,skills}/` (unchanged) and `.claude/{agents,skills,commands}/` (new). This is the "Claude-compatible version of smaqit-extensions" release product — additive, not a replacement; Copilot support is fully preserved.

This mirrors a refactor already completed and proven in the sibling `smaqit` repo (`~/projects/smaqit`, commit `11be9be` "feat: add Claude Code support alongside GitHub Copilot (dual-target)", plus follow-up `e04300f`), which went through three rejected design iterations before landing on: **body/content stays in the existing source tree; only per-platform frontmatter is split out; all compiled/target-specific output lives in gitignored build directories, never committed.** An internal reference installation contains an already-installed `.claude/` tree that shows the target shape in practice (and a few rot spots — see Pitfalls to Avoid below).

## Design Decisions (confirmed)

- **Dual-target, unconditional.** `smaqit-extensions init` always writes both `.github/*` and `.claude/*` — no `--target` flag. Matches smaqit's precedent exactly.
- **Source of truth stays at repo root, unchanged in place.** `agents/smaqit.<name>.agent.md` and `skills/smaqit.<name>/SKILL.md` remain exactly as they are today (Copilot-native format). No restructuring into smaqit's heavier `{{PLACEHOLDER}}`-in-body pattern — verified the 3 agent bodies contain zero inline Copilot-tool-name references, so bodies can be reused verbatim for Claude output. Only frontmatter differs per platform.
- **Claude naming convention — verified directly against `~/projects/smaqit/scripts/generate-agents.py` (not just the internal reference installation, which turned out to diverge from the actual generator on this point):**
  - **Filenames and skill directories keep dots**, identical to the Copilot source, on both platforms. Only the *internal* Claude agent `name:` frontmatter *value* is hyphenated (Claude's naming rule applies to that field, not to paths). Confirmed by reading actual compiled output in `~/projects/smaqit/installer/agents-claude/smaqit.business.md` — the file is named with dots, but its frontmatter reads `name: smaqit-business`.
  - Agents: flat file `.claude/agents/smaqit.<name>.md` (dotted filename, `.agent.md` suffix dropped to plain `.md`; frontmatter `name:` hyphenated, e.g. `smaqit-release-local`).
  - Skills: directory `.claude/skills/smaqit.<name>/SKILL.md` — **unchanged dotted directory name**, same as Copilot. `smaqit-extensions.project-diagnose` stays `smaqit.project-diagnose` on both sides; only the `[SMAQIT_SKILLS_DIR]` root prefix differs.
  - That installation's hyphenated `.claude/skills/smaqit-session-start/` style directories do **not** match this — treat it as a divergent/manual port on this specific point, not the convention to follow.
- **Agent frontmatter split:** one new file per agent, `.smaqit/definitions/agents/<name>.claude.yaml`, holding just the Claude-side `name`, `description`, `tools`. Lighter than smaqit's dual-platform-per-file YAML since the Copilot side needs no change — this file only ever supplies the Claude override.
- **Tool mapping (Copilot VS Code tool ID → Claude Code tool name)** for the 3 agents' actual tool sets:
  | Copilot | Claude |
  |---|---|
  | `edit` | `Edit` |
  | `search` | `Grep`, `Glob` |
  | `execute/runInTerminal` | `Bash` |
  | `execute/getTerminalOutput` | (covered by `Bash`) |
  | `execute/runTests` | (covered by `Bash`) |
  | `execute/testFailure` | (covered by `Bash`) |
  | `read/readFile` | `Read` |
  | `read/terminalSelection`, `read/terminalLastCommand` | (covered by `Bash`) |
  | `search/usages` | `Grep` |
  | `read/problems` | (no direct Claude equivalent — drop) |
  | `todo` | `TodoWrite` |

  Resolved per-agent Claude `tools:` (comma-separated string, per both reference repos' convention):
  - `smaqit-release-local`: `Bash, Read, Edit, Grep, Glob, TodoWrite`
  - `smaqit-release-pr`: `Bash, Read, Edit, Grep, Glob, TodoWrite` — **note:** the Copilot source (`agents/smaqit.release.pr.agent.md`) declares no `tools:` field at all; it runs under GitHub Copilot Coding Agent and relies on the implicit `report_progress` primitive for commits, which has no Claude Code equivalent. The Claude subagent instead gets direct `Bash` access to run `git`/`gh` itself, same as release-local.
  - `smaqit-user-testing`: `Bash, Edit, Grep, Glob, TodoWrite`
- **Skills need no per-skill Claude frontmatter file and no frontmatter rewriting at all** — verified `generate_skills()` in smaqit's generator does a straight `shutil.copytree` per platform plus a text-only `[SMAQIT_SKILLS_DIR]` substitution pass; `name:`/`description:`/`metadata:` are copied byte-for-byte unchanged. This means `metadata.version` is **preserved automatically** simply by not touching skill frontmatter — no special-casing needed, and no risk of repeating the `internal reference installation` regression (which dropped it via a from-scratch manual port, not via this copy-based mechanism).
- **`[SMAQIT_SKILLS_DIR]` placeholder** for the two files found with hardcoded install-path self-references, resolved at compile time to `.github/skills` (Copilot) or `.claude/skills` (Claude):
  - `skills/smaqit.project-diagnose/SKILL.md:63`
  - `skills/smaqit.project-diagnose/scripts/diagnose-inventory.sh:5`
  - (`skills/smaqit.release-git-local/SKILL.md:101` is a dev-workflow `git add` example referring to *this* repo's own maintenance, not an install path — leave untouched.)
- **Commands:** add `commands/smaqit.<name>.md` (3 files, dotted filenames matching agent source stems, Claude Code slash-command format, minimal `description:` frontmatter) for all 3 agents — unlike smaqit's phase agents, none of smaqit-extensions' 3 agents are delegate-only (all are already directly `@`-invocable in Copilot per the README), so all 3 get a command, none are omitted. Each command body delegates via the `Task` tool to the matching subagent (referenced by its hyphenated Claude `name:`, e.g. `smaqit-release-local`), mirroring `commands/smaqit.development.md` in the smaqit repo verbatim in structure.
- **Compiler:** new `scripts/generate-targets.py` (Python, matching smaqit's toolchain choice), run via `installer/Makefile`'s `prepare` target before `go build`. Produces four gitignored output trees: `installer/skills-copilot/`, `installer/skills-claude/`, `installer/agents-claude/`, `installer/commands-claude/`. (No `installer/agents-copilot/` needed — the existing `//go:embed agents/*.md` continues to read the root `agents/` directly, unchanged.)
- **No plugin/marketplace manifest.** Confirmed smaqit does not use `.claude-plugin/plugin.json` for this — it ships via the same "installer writes files directly" model as Copilot. Task 010 (marketplace plugin) remains a separate, unrelated effort.
- **No AGENTS.md/CLAUDE.md scaffolding.** Confirmed smaqit-extensions' installer has no analogous instructions-file installation today (unlike smaqit) — out of scope here, not needed for skills/agents to function.

## Pitfalls to Avoid

The internal `.claude/` tree is a real but imperfect port and should not be copied uncritically:
- It dropped `metadata.version` from every skill — preserve it instead (see above).
- `smaqit-project-recap/scripts/scan-metadata.py`'s docstring still describes the pre-port `agents/*.agent.md` / `skills/*/SKILL.md` source layout, not the installed `.claude/` layout it actually ships in — when porting `smaqit.project-recap`, check whether its `scan-metadata.py` needs a `[SMAQIT_SKILLS_DIR]`-aware rewrite so this doesn't reproduce the same staleness.
- `smaqit-project-init/SKILL.md` there references a nonexistent `smaqit.project-zero-to-prod` skill — a dangling leftover. Check the current `skills/smaqit.project-init/SKILL.md` doesn't already contain the same dangling reference; fix if so (unrelated to this task's core scope but cheap to catch while touching the file).

## Implementation Steps

1. Read `~/projects/smaqit/scripts/generate-agents.py` in full as the direct implementation reference — adapt (don't reinvent) its skill-copy + placeholder-substitution logic and its agent frontmatter-merge logic for smaqit-extensions' lighter single-file-override design.
2. Create `.smaqit/definitions/agents/` with 3 `<name>.claude.yaml` files (release-local, release-pr, user-testing) — `name`, `description`, `tools` per the mapping table above. Inspect `agents/smaqit.release.pr.agent.md` frontmatter first to confirm its tool list before writing its Claude counterpart.
3. Create `commands/` at repo root with 3 files (`smaqit.release.local.md`, `smaqit.release.pr.md`, `smaqit.user-testing.md`), Task-delegation format per smaqit's `commands/smaqit.development.md` example.
4. Fix the two `[SMAQIT_SKILLS_DIR]`-eligible hardcoded paths in `smaqit.project-diagnose`.
5. Write `scripts/generate-targets.py`: copies `skills/` → `installer/skills-copilot` (verbatim) and `installer/skills-claude` (identical dotted dir/file names, only `[SMAQIT_SKILLS_DIR]` text substitution); reads each `agents/smaqit.<name>.agent.md` body (stripping its Copilot frontmatter) + matching `.claude.yaml` → writes `installer/agents-claude/smaqit.<name>.md` (dotted filename, hyphenated internal `name:`); copies `commands/*.md` verbatim → `installer/commands-claude/`.
6. Add `installer/agents-claude/`, `installer/commands-claude/`, `installer/skills-copilot/`, `installer/skills-claude/` to `.gitignore`, with a comment matching smaqit's ("auto-populated by `make prepare` — never edit or commit manually").
7. Update `installer/Makefile`: add/extend a `prepare` target that runs the generator before `build`/`build-all`.
8. Update `installer/main.go`:
   - Add `//go:embed skills-copilot` (replacing direct `skills/*` embed, now sourced from the generated copy for consistency — confirm this doesn't change Copilot output byte-for-byte before switching), `//go:embed agents-claude/*.md`, `//go:embed commands-claude/*.md`, `//go:embed skills-claude`.
   - `cmdInstall`: create `.claude/agents`, `.claude/commands`, `.claude/skills` dirs; copy the three new embedded trees into them, unconditionally, alongside the existing `.github/*` copy.
   - `cmdUninstall`: symmetric removal of the three new `.claude/*` paths, with the same empty-parent-dir cleanup already done for `.github/`.
   - Fix the stale "27 workflow skills" string in `printHelp()` (should reflect current count and mention `.claude/` output too).
9. Update root `Makefile`'s dogfooding `sync` target only if this repo should also self-host a `.claude/` copy for its own use (open question — default to **not** doing this, matching smaqit's own repo which kept its `.claude/settings.json` dev-only and separate from shipped content; flag as a note for the user rather than assuming).
10. Update `README.md`: add a Compatibility section (GitHub Copilot / Claude Code, both ✅ Supported) matching smaqit's README pattern; update "What Gets Installed" to list `.claude/agents/`, `.claude/commands/`, `.claude/skills/`.
11. Update `CHANGELOG.md` with an entry for Claude Code support.
12. Build and test end-to-end: `make -C installer build`, run the built binary's `init` against a scratch directory, verify `.claude/agents/`, `.claude/commands/`, `.claude/skills/` are populated correctly and `.github/*` output is byte-identical to pre-change output (no regression).
13. Mark this task Completed in `PLANNING.md`.

## Acceptance Criteria

- [x] `scripts/generate-targets.py` exists and produces `installer/{skills,skills-claude,agents-claude,commands-claude}` from root `agents/`, `skills/`, `commands/`, `.smaqit/definitions/agents/` (`installer/skills/` — the existing Copilot embed path — is now populated by the generator instead of a raw `cp`, since the raw copy never resolved `[SMAQIT_SKILLS_DIR]`)
- [x] `.smaqit/definitions/agents/*.claude.yaml` exists for all 3 agents with correct Claude-mapped `tools:`
- [x] `commands/smaqit.<name>.md` exists for all 3 agents (dotted filenames, matching agent source stems)
- [x] `[SMAQIT_SKILLS_DIR]` placeholder resolved correctly in `smaqit.project-diagnose`'s SKILL.md and script for both targets — verified in compiled `installer/skills/` (→ `.github/skills`) and `installer/skills-claude/` (→ `.claude/skills`); also fixed in this repo's own dogfooding `make sync` (was resolving the same way as the old raw installer copy, i.e. not at all — added a `sed` resolution pass to root `Makefile`)
- [x] Claude-side skill frontmatter preserves `metadata.version` (does not repeat the internal reference installation regression) — confirmed: `generate_skills()` never touches skill frontmatter, only a text substitution for the placeholder
- [x] `installer/main.go` deploys `.claude/agents/`, `.claude/commands/`, `.claude/skills/` unconditionally alongside unchanged `.github/*` output
- [x] `cmdUninstall` removes all `.claude/*` paths symmetrically — verified via scratch-dir end-to-end test (65/65 files removed, 0 leftovers)
- [x] `.gitignore` covers all generated `installer/*` directories (`agents-claude/`, `commands-claude/`, `skills-claude/`; `skills/` and `agents/` were already covered)
- [x] `installer/Makefile` `prepare`/`build` runs the generator before compiling
- [x] End-to-end test: built binary's `init` on a scratch dir produces correct `.claude/` tree (3 agents, 3 commands, 28 skills); `.github/*` output verified unchanged (28 skills, 3 agents, byte-identical content for unaffected skills)
- [x] `README.md` documents Claude Code support (Compatibility section + installed-files list)
- [x] `CHANGELOG.md` updated
- [x] `PLANNING.md` updated to mark this task Completed

## Files to Create / Modify

| File | Action |
|------|--------|
| `.smaqit/definitions/agents/smaqit.release.local.claude.yaml` | Create |
| `.smaqit/definitions/agents/smaqit.release.pr.claude.yaml` | Create |
| `.smaqit/definitions/agents/smaqit.user-testing.claude.yaml` | Create |
| `commands/smaqit.release.local.md` | Create |
| `commands/smaqit.release.pr.md` | Create |
| `commands/smaqit.user-testing.md` | Create |
| `scripts/generate-targets.py` | Create |
| `skills/smaqit.project-diagnose/SKILL.md` | Modify — `[SMAQIT_SKILLS_DIR]` placeholder |
| `skills/smaqit.project-diagnose/scripts/diagnose-inventory.sh` | Modify — `[SMAQIT_SKILLS_DIR]` placeholder |
| `.gitignore` | Modify — ignore 4 generated `installer/*` dirs |
| `installer/Makefile` | Modify — `prepare` target |
| `installer/main.go` | Modify — new embeds, dual-target `cmdInstall`/`cmdUninstall`, fixed skill count in help text |
| `README.md` | Modify — Compatibility section, installed-files list |
| `CHANGELOG.md` | Modify — add entry |
| `skills/smaqit.project-init/SKILL.md` | Modify — removed dangling `smaqit.project-zero-to-prod` reference (Pitfalls to Avoid, opportunistic fix) |
| `Makefile` (root) | Modify — added `[SMAQIT_SKILLS_DIR]` resolution pass to dogfooding `sync` target (same class of bug the installer's raw skills `cp` had) |
| `.smaqit/tasks/PLANNING.md` | Modify — mark completed |

## Findings

**Implementation approach:**
- Followed the verified `~/projects/smaqit` generator pattern exactly, adapted for smaqit-extensions' simpler surface (3 stable agents, no `{{PLACEHOLDER}}`-in-body machinery needed since none of the 3 agent bodies reference Copilot-specific tool names inline)
- `scripts/generate-targets.py` compiles `agents/smaqit.<name>.agent.md` (body reused verbatim) + `.smaqit/definitions/agents/<name>.claude.yaml` (Claude-side `name`/`description`/`tools` override) into `installer/agents-claude/smaqit.<name>.md`; copies `commands/*.md` verbatim into `installer/commands-claude/`; copies `skills/` into both `installer/skills/` (Copilot, existing embed path) and `installer/skills-claude/` (new), resolving `[SMAQIT_SKILLS_DIR]` per platform
- `installer/main.go` gained 3 new `//go:embed` directives and two small helpers (`installFlatFiles`/`installSkillTree`, mirrored by `removeFlatFiles`/`removeSkillTree`) to avoid tripling the existing install/uninstall walk logic for the 3 new Claude trees, while leaving the existing Copilot install/uninstall code paths untouched to minimize regression risk

**Decisions made:**
- Filenames and skill directories keep dots on both platforms (`smaqit.release.local.md`, `smaqit.project-diagnose/`); only the Claude agent's internal `name:` frontmatter *value* is hyphenated — verified directly against smaqit's actual compiled output, not just its secondhand summary, after the internal reference installation turned out to diverge from this (it used hyphenated directories, which is not what the real generator produces)
- Replaced the installer's raw `cp -rL ../skills/* skills/` (which would have shipped the literal `[SMAQIT_SKILLS_DIR]` string) with the generator populating `installer/skills/` directly — same embed path, no `main.go` change needed for that specific embed
- `smaqit-release-pr`'s Claude tools (`Bash, Read, Edit, Grep, Glob, TodoWrite`) were derived from *absence* of Copilot tooling (it has no `tools:` field at all, relying on Copilot Coding Agent's `report_progress` primitive) rather than a 1:1 tool mapping — Claude has no equivalent primitive, so it gets direct `Bash`/`gh` access instead, matching `smaqit-release-local`
- Did not dogfood a `.claude/` copy of this repo's own tooling (matching smaqit's own repo, which keeps Claude dev tooling separate from shipped content) — flagged as an open question in Notes, not actioned
- Fixed two pre-existing bugs discovered along the way, both a direct consequence of introducing `[SMAQIT_SKILLS_DIR]`: the dogfooding `make sync` target didn't resolve it either (same bug class as the installer's raw copy), and PyYAML's default ASCII-only dump escaped the em dash in one Claude-side description into `—`

**Blockers encountered:**
- The Bash tool's safety classifier was intermittently unavailable for an extended period mid-task, blocking all command execution (generator run, build, tests) while file edits continued unaffected; resolved on retry once the classifier recovered, no other workaround needed

**Follow-up identified:**
- None — task 010 (marketplace plugin) and task 007 (MCP server) remain separate, unrelated efforts; no new tasks surfaced during implementation

## Notes

- This task file, the `.smaqit/definitions/agents/` convention, and the generator script naming deliberately follow the proven `smaqit` repo pattern rather than inventing a new one — see that repo's `.smaqit/history/058_claude_code_migration_2026-07-16.md` for the full rationale behind rejecting simpler alternatives (full duplication; generated output committed at repo root; definitions replacing root `agents/` entirely).
- Open question flagged in step 9 for the user: whether smaqit-extensions should also dogfood a `.claude/` copy of its own tooling in this repo (matching what `smaqit` does for itself), separate from what gets shipped to consumers. Default assumption is no — confirm before implementing if this matters.
