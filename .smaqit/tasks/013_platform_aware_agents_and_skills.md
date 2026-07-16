# Platform-Aware Agent Frontmatter and Skill Content (Claude Code Follow-up)

**Status:** Completed
**Mode:** Assisted
**Created:** 2026-07-16
**Completed:** 2026-07-16

## Description

Follow-up to task 012 (Claude Code dual-target install). Task 012 shipped a working dual-target installer, but a post-implementation review surfaced three real gaps:

1. **Agent frontmatter source asymmetry.** `agents/smaqit.<name>.agent.md` still carries full Copilot-native frontmatter inline; only the Claude side is generated, from a separate override file (`.smaqit/definitions/agents/<name>.claude.yaml`). This doesn't match the proven `~/projects/smaqit` pattern (body-only source + one `.frontmatter.yaml` with `copilot:`/`claude:` sections for BOTH platforms) that task 012 was explicitly modeled on, and it means any future third platform (e.g. Codex) has no consistent place to add its frontmatter.
2. **No project-instructions file is installed at all.** Neither `.github/copilot-instructions.md` nor `CLAUDE.md`/`AGENTS.md` is auto-scaffolded by `smaqit-extensions init` — that's always been `smaqit.project-init`'s job, opt-in. But `smaqit.project-init` only knows how to produce `.github/copilot-instructions.md`.
3. **Two skills have Copilot-only content, not just Copilot-only paths.** Unlike the narrow `[SMAQIT_SKILLS_DIR]` path-placeholder case task 012 handled, `smaqit.project-init` (targets `.github/copilot-instructions.md` specifically) and `smaqit.release-git-pr` (its entire push mechanism is the `report_progress` tool, a GitHub Copilot Coding Agent primitive with no Claude Code equivalent) have **prescriptive, executable content** that is simply wrong when followed under Claude Code. Both are installed byte-identical to `.claude/skills/` today.

Additionally, 4 skills (`smaqit.project-diagnose`, `smaqit.project-recap` + its `OUTPUT_FORMAT.md`, `smaqit.project-research`, `smaqit.session-start`) reference `.github/copilot-instructions.md` as *one of several* read-only context sources, without also mentioning the Claude equivalent — not broken, but incomplete.

## Design Decisions (confirmed)

- **Mechanism: extend the existing `{{PLACEHOLDER}}` substitution, not full file duplication.** smaqit already resolves small per-platform tokens (e.g. `{{WEB_TOOL}}`) inside otherwise-shared agent bodies via a per-artifact YAML definitions file. This task extends the *same* mechanism to (a) skills, not just agents, and (b) placeholder values that span a whole step or table row, not just one word. Rejected alternative: two full duplicate SKILL.md files per platform for `project-init`/`release-git-pr` — would duplicate ~70% identical content (Steps 1/2/4, Output, most of Error Handling, most of Notes in `release-git-pr`; the entire template-population logic in `project-init`), creating the exact drift risk this repo's own `make sync` discipline exists to prevent. Placeholders isolate only the genuine inflection points.
- **Agent frontmatter: full symmetry with smaqit.** `agents/smaqit.<name>.agent.md` becomes body-only (frontmatter stripped, filename unchanged — see below). One `.smaqit/definitions/agents/<name>.frontmatter.yaml` per agent holds `copilot:` and `claude:` sections, each with `name`/`description`/`tools` (Copilot also keeps `metadata.version`, since this repo — unlike smaqit — versions its agents; no `user-invocable` field needed, none of our 3 agents are delegate-only). Both `installer/agents-copilot/` and `installer/agents-claude/` become generated output (previously only `agents-claude` was generated; Copilot was a raw embed of the root source).
- **No filename rename.** `agents/smaqit.<name>.agent.md` keeps its `.agent.md` suffix even though it's now body-only, to avoid an unnecessary cascade — the suffix is referenced as a glob pattern (`agents/*.agent.md`) in `.github/copilot-instructions.md`, `smaqit.release-git-local`'s dev-workflow example, and `smaqit.project-recap`'s scanner; all of these keep working unmodified since the *pattern* doesn't care whether matched files carry frontmatter. Only the scanner's *frontmatter-reading* logic needs to change (see below) — the glob itself does not.
- **`smaqit.project-recap`'s `scan-metadata.py` must be updated.** It currently calls `extract_frontmatter()` directly on each `agents/*.agent.md` file. Once that file is body-only, this silently returns `None` for every agent and the recap dashboard would show zero agents with no error. Fix: for agents specifically, read `.smaqit/definitions/agents/<stem>.frontmatter.yaml`'s `copilot:` section instead of the body file's own (now-absent) frontmatter. Skills are unaffected — skill frontmatter stays identical across platforms, untouched by this task.
- **`smaqit.project-init` gets one placeholder: `{{INSTRUCTIONS_FILE}}`** (`.github/copilot-instructions.md` / `CLAUDE.md`), used everywhere the skill references its output path. The template file itself (`.smaqit/templates/copilot-instructions.template.md`) stays a single shared file, unmodified and unrenamed — its `# Scaffolding` ignore-list already names `.github/` paths; add the `.claude/` equivalents to the same list (both sets are safe to list unconditionally — ignoring a path that doesn't exist in a given install is harmless), so the template itself needs zero platform branching. Frontmatter `description:` gets reworded to be platform-neutral prose (not templated — skill frontmatter still carries no per-platform variance elsewhere in the repo, and inventing that mechanism for one description line isn't worth it).
- **`smaqit.release-git-pr` gets four placeholders**, isolating exactly the `report_progress`-shaped inflection points: `{{PUSH_STEP}}` (the full "Step 3" section, heading included — content genuinely differs, not just a word), `{{PUSH_METHOD_SUMMARY}}` (short phrase reused in the intro line, "When to use" bullet, and comparison table), `{{PUSH_CREDENTIAL_SOURCE}}` (comparison-table cell), `{{PUSH_FAILURE_ROW}}` (Error Handling table row). Everything else — Steps 1/2/4, PR-title verification, Output section, most of Error Handling, most of Notes — stays 100% shared, zero duplication.
- **The 4 "incomplete" skills get plain-text edits, no placeholder mechanism.** They only *read* `.github/copilot-instructions.md` as one of several optional context sources ("if present"); mentioning `CLAUDE.md`/`AGENTS.md` alongside it is accurate and harmless regardless of which platform is actually installed, so this needs no build-time branching — just clearer shared wording.
- **Future platforms (e.g. Codex):** the yaml schema (`copilot:`/`claude:` top-level keys per artifact) extends by adding a new key and a new generator loop entry — no restructuring needed. This is why the mechanism is a flat per-platform map, not a two-file split.

## Implementation Steps

### A. Agent frontmatter symmetry
1. For each of the 3 agents: extract the existing Copilot frontmatter block from `agents/smaqit.<name>.agent.md` into a new `.smaqit/definitions/agents/smaqit.<name>.frontmatter.yaml` under a `copilot:` key (preserving `name`, `description`, `metadata.version`, `tools`); add a `claude:` key with the existing content from the task-012 `.claude.yaml` file (`name`, `description`, `tools`). Delete the old `.claude.yaml` files.
2. Strip the frontmatter block from `agents/smaqit.<name>.agent.md`, leaving body only (starting at the first `#` heading).
3. Rewrite `generate_agents()` in `scripts/generate-targets.py`: read each `agents/*.agent.md` body directly (no more `split_frontmatter` — nothing to split), load the merged `<stem>.frontmatter.yaml`, resolve any `placeholders:` block (none needed today, but keep the mechanism generic — reuse the same `resolve_placeholders()` helper used for skills), and write both `installer/agents-copilot/<stem>.agent.md` and `installer/agents-claude/<stem>.md`. Restore the `FlowList`/`dump_frontmatter` bracket-style handling for Copilot's `tools:` array (removed in task 012 since it wasn't needed there).
4. Update `installer/main.go`: change the Copilot agent embed from `//go:embed agents/*.md` (raw source) to `//go:embed agents-copilot/*.md` (generated); rename `agentFiles` → `copilotAgentFiles` for symmetry with `claudeAgentFiles`; update the `installFlatFiles`/`removeFlatFiles` call sites' `srcRoot` from `"agents"` to `"agents-copilot"`.
5. Update `installer/Makefile`: remove the now-redundant `@cp -r ../agents/*.md agents/` line (Copilot agents are generated now, not raw-copied); remove the stale `installer/agents/` directory reference from `clean`; add `agents-copilot/` to the removed dirs in `clean`.
6. Update root `Makefile`'s dogfooding `sync` target: replace `cp -f agents/*.md .github/agents/` with a step that runs the generator (`python3 scripts/generate-targets.py`) and copies from `installer/agents-copilot/*.agent.md` instead — mirrors the exact fix already applied to `sync`'s skills step in task 012 (raw-copying the now-frontmatter-less source would ship broken agent files to this repo's own `.github/agents/`).
7. Update `.gitignore`: add `installer/agents-copilot/`; the old `installer/agents/` entry can stay (harmless, now simply unused) or be removed — remove it for cleanliness since nothing populates that path anymore.
8. Fix `skills/smaqit.project-recap/scripts/scan-metadata.py`: replace the direct `extract_frontmatter(path)` call in the agent-scanning branch with a new `load_agent_platform_frontmatter(root, stem, platform="copilot")` that reads `.smaqit/definitions/agents/<stem>.frontmatter.yaml` and returns its `copilot:` section. Update the module docstring's field description accordingly.
9. Update `skills/smaqit.project-recap/SKILL.md`'s "Fallback (if `uv` is unavailable)" prose (currently: "Extract the YAML frontmatter block... from each `agents/*.agent.md` file") to describe reading the corresponding `.smaqit/definitions/agents/<stem>.frontmatter.yaml`'s `copilot:` section for agents instead.

### B. Extend the generator's placeholder mechanism to skills
10. In `scripts/generate-targets.py`, factor the existing agent-only `resolve_placeholders()` into a shared helper usable by both `generate_agents()` and `generate_skills()`.
11. Extend `generate_skills()`: after the existing `[SMAQIT_SKILLS_DIR]` substitution pass, check for `.smaqit/definitions/skills/<skill-dir-name>.placeholders.yaml`; if present, resolve any `{{TOKEN}}` occurrences in every file of that skill's output directory (not just `SKILL.md`) using the current platform's values.

### C. `smaqit.project-init` — platform-aware output path
12. Create `.smaqit/definitions/skills/smaqit.project-init.placeholders.yaml` with `INSTRUCTIONS_FILE: {copilot: .github/copilot-instructions.md, claude: CLAUDE.md}`.
13. Edit `skills/smaqit.project-init/SKILL.md`: replace every literal `.github/copilot-instructions.md` reference in the body (Steps 1, 5, Requirements) with `{{INSTRUCTIONS_FILE}}`. Reword the frontmatter `description:` to be platform-neutral (mention both target files explicitly, no placeholder needed there).
14. Edit `.smaqit/templates/copilot-instructions.template.md`'s `# Scaffolding` section: add `.claude/agents/`, `.claude/skills/`, `.claude/commands/` to the ignore-list alongside the existing `.github/` entries, plus `commands/` and `scripts/` (new task-012 source dirs) alongside `agents/`/`skills/`. This file is shared verbatim across both platforms — no rename, no branching.

### D. `smaqit.release-git-pr` — platform-aware push mechanism
15. Create `.smaqit/definitions/skills/smaqit.release-git-pr.placeholders.yaml` with the 4 placeholders described in Design Decisions (`PUSH_STEP`, `PUSH_METHOD_SUMMARY`, `PUSH_CREDENTIAL_SOURCE`, `PUSH_FAILURE_ROW`). Claude's `PUSH_STEP` uses direct `git push` (no tag creation, matching the PR workflow's existing constraint), mirroring `smaqit-release-local`'s Claude tool access already established in task 012.
16. Edit `skills/smaqit.release-git-pr/SKILL.md`: replace "### Step 3: Push via report_progress" and its full body with `{{PUSH_STEP}}`; replace the intro-line, "When to use this skill" bullet, and comparison-table "Push method" cell with `{{PUSH_METHOD_SUMMARY}}`; replace the comparison-table "Git credentials" cell with `{{PUSH_CREDENTIAL_SOURCE}}`; replace the Error Handling `report_progress fails` row with `{{PUSH_FAILURE_ROW}}`. Reword frontmatter `description:` to be platform-neutral. Reword the Notes bullet about `report_progress` authentication to reference `{{PUSH_METHOD_SUMMARY}}` or platform-neutral phrasing.

### E. Incomplete skills — plain-text fallback mentions
17. Edit `skills/smaqit.project-diagnose/SKILL.md`, `skills/smaqit.project-recap/SKILL.md` (+ `references/OUTPUT_FORMAT.md`), `skills/smaqit.project-research/SKILL.md`, `skills/smaqit.session-start/SKILL.md`: everywhere `.github/copilot-instructions.md` is mentioned as a context source, add `CLAUDE.md`/`AGENTS.md` alongside it as the Claude Code equivalent. Plain text, no placeholder needed (both mentions are accurate regardless of platform).

### F. Build, verify, document
18. Run `python3 scripts/generate-targets.py`, inspect `installer/agents-copilot/` output against the pre-change `agents/*.agent.md` content for equivalence (frontmatter fields match; cosmetic YAML formatting differences like quote style are acceptable).
19. `make -C installer build`; end-to-end `init` on a scratch dir — verify `.claude/skills/smaqit.project-init/SKILL.md` resolves to `CLAUDE.md`, `.github/skills/smaqit.project-init/SKILL.md` still resolves to `.github/copilot-instructions.md`; same check for `release-git-pr`'s push section on both sides.
20. `make sync` (root, dogfooding) — verify `.github/agents/*.agent.md` still contains full, correct frontmatter (not body-only) after the source-of-truth move.
21. Run `uv run skills/smaqit.project-recap/scripts/scan-metadata.py .` (or equivalent) against this repo — verify all 3 agents still appear with correct name/version/description.
22. Update `CHANGELOG.md` with an entry.
23. Mark this task Completed in `PLANNING.md`.

## Acceptance Criteria

- [x] `agents/smaqit.<name>.agent.md` is body-only (no frontmatter) for all 3 agents
- [x] `.smaqit/definitions/agents/smaqit.<name>.frontmatter.yaml` exists for all 3 agents with `copilot:` and `claude:` sections; old `.claude.yaml` files removed
- [x] `installer/agents-copilot/` and `installer/agents-claude/` are both generator output (neither is a raw copy); `installer/main.go` embeds `agents-copilot/*.md` for Copilot
- [x] `scan-metadata.py` correctly reports all 3 agents (name, version, description) after the frontmatter move — verified directly; `smaqit.project-recap`'s fallback prose updated to match
- [x] Root `Makefile` `sync` and `installer/Makefile` `prepare` both produce fully-formed Copilot agent files (frontmatter + body), not body-only files — verified via `make sync` and inspecting `.github/agents/*.agent.md`
- [x] `smaqit.project-init` writes to `.github/copilot-instructions.md` under Copilot and `CLAUDE.md` under Claude Code — verified via literal compiled-output inspection and a scratch-dir end-to-end `init`
- [x] Shared `copilot-instructions.template.md`'s Scaffolding section lists both `.github/` and `.claude/` paths; template is not duplicated or renamed
- [x] `smaqit.release-git-pr`'s compiled Claude output describes direct `git push`, not `report_progress`, in its push step, comparison table, and error-handling table; compiled Copilot output verified unchanged (byte-diff shows only the intentional wording clarifications, same mechanism)
- [x] The 4 "incomplete" skills mention both `.github/copilot-instructions.md` and `CLAUDE.md`/`AGENTS.md` as context sources
- [x] `make -C installer build` succeeds; end-to-end scratch-dir `init` (+ `uninstall`, 65/65 files removed) produces correct platform-specific content for both modified skills
- [x] `CHANGELOG.md` updated; `PLANNING.md` marked Completed

## Files to Create / Modify

| File | Action |
|------|--------|
| `.smaqit/definitions/agents/smaqit.release.local.frontmatter.yaml` | Create (replaces `.claude.yaml`) |
| `.smaqit/definitions/agents/smaqit.release.pr.frontmatter.yaml` | Create (replaces `.claude.yaml`) |
| `.smaqit/definitions/agents/smaqit.user-testing.frontmatter.yaml` | Create (replaces `.claude.yaml`) |
| `.smaqit/definitions/agents/*.claude.yaml` (3 files) | Delete |
| `agents/smaqit.release.local.agent.md` | Modify — strip frontmatter |
| `agents/smaqit.release.pr.agent.md` | Modify — strip frontmatter |
| `agents/smaqit.user-testing.agent.md` | Modify — strip frontmatter |
| `.smaqit/definitions/skills/smaqit.project-init.placeholders.yaml` | Create |
| `.smaqit/definitions/skills/smaqit.release-git-pr.placeholders.yaml` | Create |
| `scripts/generate-targets.py` | Modify — agent generation rewrite, shared placeholder helper, skill placeholder resolution |
| `installer/main.go` | Modify — Copilot agent embed path, var rename, helper call sites |
| `installer/Makefile` | Modify — remove raw agents cp, update clean |
| `Makefile` (root) | Modify — sync agents via generator output, not raw copy |
| `.gitignore` | Modify — `installer/agents-copilot/` |
| `skills/smaqit.project-recap/scripts/scan-metadata.py` | Modify — read agent frontmatter from definitions yaml |
| `skills/smaqit.project-recap/SKILL.md` | Modify — fallback prose; incomplete-skill fallback mention |
| `skills/smaqit.project-recap/references/OUTPUT_FORMAT.md` | Modify — incomplete-skill fallback mention |
| `skills/smaqit.project-init/SKILL.md` | Modify — `{{INSTRUCTIONS_FILE}}` placeholder, neutral description |
| `.smaqit/templates/copilot-instructions.template.md` | Modify — add `.claude/` paths to Scaffolding ignore-list |
| `skills/smaqit.release-git-pr/SKILL.md` | Modify — 4 placeholders, neutral description |
| `skills/smaqit.project-diagnose/SKILL.md` | Modify — incomplete-skill fallback mention |
| `skills/smaqit.project-research/SKILL.md` | Modify — incomplete-skill fallback mention |
| `skills/smaqit.session-start/SKILL.md` | Modify — incomplete-skill fallback mention |
| `CHANGELOG.md` | Modify — add entry |
| `.smaqit/tasks/PLANNING.md` | Modify — mark completed |

## Findings

**Implementation approach:**
- Restructured the 3 agents to full copilot/claude symmetry, matching smaqit's proven pattern exactly: `agents/*.agent.md` is now body-only, `.smaqit/definitions/agents/*.frontmatter.yaml` holds both platforms' frontmatter, and both `installer/agents-copilot/` and `installer/agents-claude/` are generator output — no raw embed remains on either side
- Extended `scripts/generate-targets.py`'s `{{PLACEHOLDER}}` mechanism (previously agent-only, unused in practice) to skills too, via `.smaqit/definitions/skills/<name>.placeholders.yaml`; reused the identical `resolve_placeholders()` helper for both artifact types
- Consolidated `installer/main.go`'s Copilot agent install/uninstall loops to reuse the `installFlatFiles`/`removeFlatFiles` helpers already built for the Claude side in task 012, removing ~35 lines of duplicated `fs.WalkDir` boilerplate now that both platforms follow the same generated-flat-files shape
- Root `Makefile`'s dogfooding `sync` now runs the same generator and copies from its output (`installer/agents-copilot/`, `installer/skills/`) instead of raw-copying source — single source of truth for "what a correct Copilot install looks like," shared by the real installer and this repo's own `.github/`

**Decisions made:**
- Did not rename `agents/*.agent.md` to drop the now-inaccurate `.agent.md` suffix (body is no longer Copilot-specific) — the suffix is used as a glob pattern in 4 other places (contributor docs, dev-workflow example, recap scanner) that don't care about frontmatter presence; renaming would have forced unnecessary edits there for a cosmetic gain
- `smaqit.project-init`'s shared template stays a single unrenamed file — its Scaffolding ignore-list now lists both `.github/` and `.claude/` paths unconditionally (safe regardless of which platform is actually installed) rather than branching the template itself, since only the skill's *output path* genuinely differs, not the template content
- `smaqit.release-git-pr` isolated exactly 4 named placeholders (`PUSH_STEP`, `PUSH_METHOD_SUMMARY`, `PUSH_CREDENTIAL_SOURCE`, `PUSH_FAILURE_ROW`) rather than one giant block or full file duplication — kept Steps 1/2/4, Output, and most of Error Handling/Notes 100% shared
- Discovered (not originally in the plan) that `smaqit.project-recap`'s `scan-metadata.py` reads agent frontmatter directly from the body file — fixed by pointing it at the new `.frontmatter.yaml`'s `copilot:` section; caught via direct test run against this repo before it could ship as a silent dashboard regression

**Blockers encountered:**
- None — the Bash classifier outage that affected task 012 had already resolved by the time this task started

**Follow-up identified:**
- None. Tasks 002, 007, 010 remain the only other open items in `PLANNING.md`, all unrelated to this work.

## Notes

- This task does not touch the installer's core dual-target install/uninstall logic from task 012 (directory creation, file counts, `.claude/{agents,commands,skills}/` deployment) — only the *content* of what gets generated for `smaqit.project-init`, `smaqit.release-git-pr`, and the 3 agents.
- Deliberately does not add installer-level auto-scaffolding of `AGENTS.md`/`CLAUDE.md` at `init` time (smaqit's pattern) — this repo's existing design keeps project-instructions generation as an opt-in skill (`smaqit.project-init`), and this task makes that skill platform-aware rather than changing where the responsibility lives.
- `smaqit.release-git-local` (the non-PR release agent's skill) already works correctly on both platforms without changes — it uses direct `git push` on both, no `report_progress` dependency; only `release-git-pr` (the CI/CD-oriented one) has the mismatch.
- The dev-workflow example line in `skills/smaqit.release-git-local/SKILL.md:101` and `.github/copilot-instructions.md`'s contributor docs (`git add agents/smaqit.release.pr.agent.md ...`) remain valid and unchanged — they reference the file by its existing (unrenamed) path.
