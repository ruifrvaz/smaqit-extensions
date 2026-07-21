# Project Compendium

## Architecture

**How does smaqit-extensions handle content that differs between GitHub Copilot, Claude Code, and Codex?**

Agent bodies (`agents/*.agent.md`) and skill bodies (`skills/*/SKILL.md`) are shared source, reused across all platforms wherever possible. Two mechanisms handle platform variance without duplicating whole files:

- **Per-platform agent metadata**: each agent's `.smaqit/definitions/agents/<name>.frontmatter.yaml` holds `copilot:`, `claude:`, and `codex:` sections. `scripts/generate-targets.py` combines each section with the shared body to produce YAML-frontmatter agents for Copilot and Claude Code plus standalone TOML custom agents for Codex.
- **`{{PLACEHOLDER}}` tokens for genuinely divergent content**: for the small number of skills whose *content* (not just frontmatter) differs by platform — e.g. `smaqit.project-init` writes to `.github/copilot-instructions.md` vs `CLAUDE.md`, `smaqit.release-git-pr`'s push step uses Copilot's `report_progress` tool vs Claude's direct `git push` — the shared `SKILL.md` contains named `{{TOKEN}}` placeholders resolved from `.smaqit/definitions/skills/<name>.placeholders.yaml`. This isolates only the actual inflection points; everything else in the file stays identical across platforms.

Both mechanisms are resolved once, at build time, by `scripts/generate-targets.py`; installed output contains no unresolved build-time tokens. Generated trees under `installer/` are ephemeral embed inputs. Root `.github/` and `.codex/` plus `.agents/` are workspace dogfooding mirrors, never installer sources.

---

**How does the installer's `[SMAQIT_SKILLS_DIR]` placeholder work?**

A handful of skills reference their own install path in usage comments or example commands (e.g. `smaqit.project-diagnose`, `smaqit.utils.read-pdf`). Since a skill's install root differs by platform (`.github/skills` for Copilot, `.claude/skills` for Claude Code, `.agents/skills` for Codex), any such self-reference is written in source using the literal placeholder `[SMAQIT_SKILLS_DIR]`. `scripts/generate-targets.py` resolves it when compiling each platform's ephemeral installer tree. The root `Makefile` copies from those compiled outputs, so dogfooding mirrors never contain the literal placeholder either.

---

## Testing

**How can the local installer be tested end to end?**

Run `make smoke-test` from the repository root or `make -C installer smoke-test`. The test builds the current development installer, provisions a unique temporary project, installs every Copilot, Claude Code, Codex, template, and `.smaqit` artifact, compares installed content with the generated embed staging trees, parses Codex agent TOML, checks platform substitutions, runs uninstall, and verifies cleanup. The temporary project is removed automatically; set `KEEP_SMOKE_DIR=1` to retain it for inspection.

---

## Memory and Session Persistence

**Why don't smaqit skills call a specific "memory" tool anymore?**

They used to, inconsistently — three different, mutually incompatible conventions existed across different skills (`memory` with `type: workspace`, `store_memory`, and a bare `memory` with a `/memories/session/plan.md` path), none of which are real tools on every platform this project targets. The file-based records this project already maintains — `.smaqit/history/`, `.smaqit/tasks/PLANNING.md` and individual task files, and the plan shown directly in chat — are always the authoritative source. Where a persistent memory/notes capability happens to be available in a given environment, skills use it as a best-effort accelerant for cross-branch or cross-session continuity, but nothing depends on it existing.
