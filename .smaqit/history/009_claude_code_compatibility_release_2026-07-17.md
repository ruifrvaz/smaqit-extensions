# Claude Code Compatibility Release

**Date:** 2026-07-17
**Session focus:** Add first-class Claude Code support to smaqit-extensions (dual-target install), fix a wide platform-compatibility gap in skill content, and ship the result as v1.5.0
**Tasks completed:** 012, 013, 014
**Tasks referenced:** None

---

## Actions Taken

- Fixed `smaqit.task-refresh`, which existed only in `.github/skills/` with no `skills/` source and no `Makefile` sync entry — created the source file, registered it, updated `README.md`
- Resolved a merge conflict between local work and 27 commits of upstream drift (remote had advanced through v1.2.0–v1.4.0 while local sat at v1.1.4-derived history)
- Researched an internal installation and the sibling `smaqit` repository to understand a proven dual-target install pattern before designing this repo's own version
- **Task 012 — Claude Code dual-target install:** built `scripts/generate-targets.py`, per-agent Claude frontmatter overrides, `commands/` slash-command wrappers, and dual-target `cmdInstall`/`cmdUninstall` in `installer/main.go`; fixed two hardcoded `.github/skills/...` paths via a new `[SMAQIT_SKILLS_DIR]` placeholder
- User spotted the agent frontmatter design diverged from the proven reference pattern and that neither `AGENTS.md`/`CLAUDE.md` nor genuinely platform-specific skill content were handled — ran a structured re-assessment before continuing
- **Task 013 — Platform-aware agent/skill content:** restructured `agents/*.agent.md` to body-only source with per-platform frontmatter in `.smaqit/definitions/agents/*.frontmatter.yaml`; extended the generator's `{{PLACEHOLDER}}` mechanism to skills; made `smaqit.project-init` (writes `CLAUDE.md` vs `.github/copilot-instructions.md`) and `smaqit.release-git-pr` (direct `git push` vs Copilot's `report_progress`) platform-aware; fixed a consequent regression in `smaqit.project-recap`'s `scan-metadata.py`, which read agent frontmatter directly from the now-body-only source files
- User caught a further gap: `smaqit.session-finish` hardcoded a Copilot-only `memory` tool. A full audit found three mutually inconsistent memory-tool naming conventions across 8 skills, a VS Code-only `vscode_askQuestions` reference, and a real bug in `smaqit.utils.read-pdf`'s `allowed-tools:` frontmatter (named nonexistent Claude tools)
- **Task 014 — Generic tool language:** replaced all hardcoded platform-specific tool references with capability-conditional prose ("if available, use it — otherwise the file-based record is authoritative"); gave session-history skills a native-context-first branch before falling back to VS Code's transcript log; fixed `read-pdf`'s `allowed-tools:` and a dangling self-reference
- Built the dev binary and ran real end-to-end installs against scratch directories after each task, verifying `.claude/{agents,commands,skills}/` output directly (frontmatter, resolved placeholders, uninstall symmetry)
- Committed all work as 5 logically-grouped commits (not one dump), each independently reviewable
- Ran the full local release workflow via `smaqit.release-analysis` → `smaqit.release-approval` → `smaqit.release-prepare-files` → `smaqit.release-git-local`: found and reconciled two additional unreleased changes the analysis step surfaced (a `task-refresh` sync fix and a `project-compendium` instructions update that predated this session), promoted `[Unreleased]` to `v1.5.0`, synced version files, committed, and tagged
- Push failed from the agent's execution environment (SSH agent socket and `gh` token were both inaccessible/under-scoped there) — user pushed from their own terminal instead; verified the result independently via the GitHub API and watched the release workflow to completion

## Problems Solved

- **`smaqit.task-refresh` violated the source-of-truth rule:** existed in `.github/skills/` with no canonical source. Fixed by creating `skills/smaqit.task-refresh/SKILL.md` and adding it to the sync list.
- **Divergent branch history:** local was 27 commits behind remote across three unreleased minor versions. Resolved via merge, taking remote's superset Makefile/README and verifying the true on-disk skill count (28).
- **Agent frontmatter design didn't match the proven reference pattern:** initial design kept full Copilot frontmatter inline in `agents/*.agent.md` and only generated a Claude override. Corrected to full symmetry — body-only source, both platforms generated from one `.frontmatter.yaml`.
- **Hidden regression from the frontmatter restructure:** `smaqit.project-recap`'s scanner read agent frontmatter directly from the source file; once that became body-only, it would have silently reported zero agents. Caught by testing the scanner directly against this repo before it could ship broken.
- **Three inconsistent, Copilot-only tool names for "memory":** `memory` + `type: workspace`, `store_memory`, and a bare `memory` with a `/memories/session/plan.md` path — none real on Claude Code. Replaced with capability-conditional language reused consistently across all 8 affected skills.
- **`smaqit.utils.read-pdf`'s `allowed-tools:` named nonexistent Claude tools** (`run_in_terminal read_file` instead of `Bash Read`), which would have blocked the skill from reading files under Claude Code — found only because the platform-language audit went skill-by-skill rather than stopping at the first example.
- **Push access unavailable from the agent's own environment:** no SSH agent socket, no correctly-scoped `gh` token. Rather than attempting workarounds with unknown keys, handed the exact two-line push command to the user and verified the outcome independently afterward via `gh api`.

## Decisions Made

- **Extend smaqit's existing `{{PLACEHOLDER}}` mechanism instead of duplicating whole skill files per platform** — isolates only the genuine inflection points (a handful of named tokens per skill), keeps ~90%+ of shared content in one place, avoids the drift risk full duplication would create
- **File-based records (`.smaqit/history/`, `PLANNING.md`, task files, the plan shown in chat) are always the authoritative source; a named memory tool, where one exists, is a best-effort accelerant only** — no platform ever depends on a specific memory tool existing
- **No installer-level auto-scaffolding of `AGENTS.md`/`CLAUDE.md`** — kept project-instructions generation as the existing opt-in `smaqit.project-init` skill, now made platform-aware, rather than changing where that responsibility lives
- **Committed in 5 logical groups** (install mechanism; platform-aware skills; recap scanner fix; project-diagnose path fixes; generic tool language) rather than one commit, so each concern is independently reviewable
- **Did not attempt further SSH/credential workarounds** once the agent's own key and token both failed — handed off to the user rather than guessing through unrelated private keys in `~/.ssh/`

## Files Modified

- **Core install mechanism:** `installer/main.go`, `installer/Makefile`, `Makefile`, `.gitignore`, `scripts/generate-targets.py` (new), `commands/*` (new), `.smaqit/definitions/agents/*.frontmatter.yaml` (new), `agents/*.agent.md`, `README.md`
- **Platform-aware skills:** `skills/smaqit.project-init/SKILL.md`, `skills/smaqit.release-git-pr/SKILL.md` (+ `.github/` mirrors), `.smaqit/definitions/skills/*.placeholders.yaml` (new), `.smaqit/templates/copilot-instructions.template.md`, `skills/smaqit.project-research/SKILL.md`
- **Recap scanner fix:** `skills/smaqit.project-recap/scripts/scan-metadata.py`, `skills/smaqit.project-recap/SKILL.md`, `skills/smaqit.project-recap/references/OUTPUT_FORMAT.md`
- **Path fixes:** `skills/smaqit.project-diagnose/SKILL.md`, `skills/smaqit.project-diagnose/scripts/diagnose-inventory.sh`
- **Generic tool language:** `skills/smaqit.session-finish/SKILL.md`, `smaqit.session-start`, `smaqit.session-recap`, `smaqit.session-title`, `smaqit.task-create`, `smaqit.task-start`, `smaqit.task-complete`, `smaqit.task-plan`, `smaqit.utils.read-pdf`, `smaqit.test-complete`, `smaqit.parity-assess` (all + `.github/` mirrors)
- **Task/tracking files:** `.smaqit/tasks/012_add_claude_code_support.md`, `013_platform_aware_agents_and_skills.md`, `014_generic_tool_language.md` (all new), `.smaqit/tasks/PLANNING.md`
- **Release:** `CHANGELOG.md` (promoted `[Unreleased]` → `[1.5.0]`), `installer/main.go` and `installer/Makefile` version bumps

## Next Steps

- None pending from this session — v1.5.0 is live with binaries for all 5 platforms
- Remaining open items in `PLANNING.md` (tasks 002, 007, 010) are pre-existing and unrelated to this session's work

## Session Metrics

- **Duration:** Full working session (multi-hour)
- **Tasks completed:** 3 (012, 013, 014)
- **Commits:** 6 (5 feature/fix + 1 release commit)
- **Files touched:** ~65 across source, `.github/` mirrors, and tracking docs
- **Release shipped:** v1.5.0, published with 5 platform binaries, GitHub Release live
