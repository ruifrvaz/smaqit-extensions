# Project Compendium

## Architecture

**How does smaqit-extensions handle content that differs between GitHub Copilot and Claude Code?**

Agent bodies (`agents/*.agent.md`) and skill bodies (`skills/*/SKILL.md`) are shared source, reused verbatim on both platforms wherever possible. Two mechanisms handle platform variance without duplicating whole files:

- **Per-platform frontmatter**: each agent's `.smaqit/definitions/agents/<name>.frontmatter.yaml` holds `copilot:` and `claude:` sections (name, description, tools, and Copilot's `metadata.version`). `scripts/generate-targets.py` merges each platform's frontmatter with the shared body to produce `installer/agents-copilot/` and `installer/agents-claude/`.
- **`{{PLACEHOLDER}}` tokens for genuinely divergent content**: for the small number of skills whose *content* (not just frontmatter) differs by platform — e.g. `smaqit.project-init` writes to `.github/copilot-instructions.md` vs `CLAUDE.md`, `smaqit.release-git-pr`'s push step uses Copilot's `report_progress` tool vs Claude's direct `git push` — the shared `SKILL.md` contains named `{{TOKEN}}` placeholders resolved from `.smaqit/definitions/skills/<name>.placeholders.yaml`. This isolates only the actual inflection points; everything else in the file stays identical across platforms.

Both mechanisms are resolved once, at build time, by `scripts/generate-targets.py`; the installed output for each platform contains no unresolved tokens. Adding a third platform (e.g. Codex) means adding a new key to the same YAML files, not restructuring anything.

---

**How does the installer's `[SMAQIT_SKILLS_DIR]` placeholder work?**

A handful of skills reference their own install path in usage comments or example commands (e.g. `smaqit.project-diagnose`, `smaqit.utils.read-pdf`). Since a skill's install root differs by platform (`.github/skills` for Copilot, `.claude/skills` for Claude Code), any such self-reference is written in source using the literal placeholder `[SMAQIT_SKILLS_DIR]`. `scripts/generate-targets.py` resolves it to the correct path per platform when compiling `installer/skills/` and `installer/skills-claude/`. The root `Makefile`'s dogfooding `sync` target also resolves it (by copying from the already-compiled `installer/` output rather than raw-copying `skills/`), so this repo's own `.github/skills/` never ships the literal placeholder text either.

---

## Memory and Session Persistence

**Why don't smaqit skills call a specific "memory" tool anymore?**

They used to, inconsistently — three different, mutually incompatible conventions existed across different skills (`memory` with `type: workspace`, `store_memory`, and a bare `memory` with a `/memories/session/plan.md` path), none of which are real tools on every platform this project targets. The file-based records this project already maintains — `.smaqit/history/`, `.smaqit/tasks/PLANNING.md` and individual task files, and the plan shown directly in chat — are always the authoritative source. Where a persistent memory/notes capability happens to be available in a given environment, skills use it as a best-effort accelerant for cross-branch or cross-session continuity, but nothing depends on it existing.
