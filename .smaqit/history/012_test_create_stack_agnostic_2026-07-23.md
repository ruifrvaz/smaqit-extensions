# Test Create Stack Agnostic

**Date:** 2026-07-23
**Session focus:** Rewrite `smaqit.test-create` to be stack-agnostic; release v1.7.1
**Tasks completed:** test-create stack-agnostic fix (ad-hoc, no task ID)
**Release:** v1.7.1

## Actions Taken

- Identified all hardcoded .NET/Discord/orchestrator references in `smaqit.test-create/SKILL.md` and `references/playbook-template.md`
- Rewrote `SKILL.md` Step 2: replaced fixed `dotnet build project.sln` / `orchestrator-start.sh` / `health.sh` / `journalctl -u project-orchestrator` / `wscat ws://localhost:5000/ws` with a generic stack-probing step that checks Makefile, package.json, pyproject.toml, go.mod, Cargo.toml, *.sln, AGENTS.md/CLAUDE.md, and specs/stack/*.md
- Replaced the fixed live-service enum (`orchestrator, Discord, WebSocket, vLLM, Hindsight, RAG, TTS, STT`) with generic detection (any live/running service) and derivation of verification from the project's actual interfaces
- Rewrote `references/playbook-template.md` from a filled-in project-specific example into a true template with `{placeholder}` tokens and generic HTTP/WebSocket/bot patterns
- Bumped skill version 1.0.0 → 2.0.0
- Ran `make sync` to distribute to `.github/`, `.agents/`, `installer/` and verified all copies match
- Released v1.7.1: updated CHANGELOG.md, bumped installer/main.go + installer/Makefile to 1.7.1, committed in 3 logical commits, tagged, and pushed

## Problems Solved

- **`smaqit.test-create` produced non-executable playbooks for non-.NET projects** — the skill assumed every project is a .NET solution with a Discord bot, orchestrator, and specific systemd units. It now probes the actual project and derives commands generically, matching the pattern used by `smaqit.session-start` and `smaqit.test-start`.

## Decisions Made

- **Stack probing approach**: Mirror `smaqit.session-start`'s pattern of checking multiple project manifests in a defined priority order, rather than checking a single manifest type.
- **Drop the project-specific worked example**: The old template was indistinguishable from a real template. Moved generic patterns into the template itself; no separate worked-example file was created since the three interface patterns (HTTP, WebSocket, bot/event-driven) are self-documenting.
- **PATCH release**: The fix is backward-compatible — existing playbooks are unaffected, the playbook structure is unchanged. Only the command derivation changed.

## Files Modified

- `skills/smaqit.test-create/SKILL.md` — Major rewrite (99 lines changed, version 1.0.0 → 2.0.0)
- `skills/smaqit.test-create/references/playbook-template.md` — Full rewrite (54 lines changed, true template)
- `.github/skills/smaqit.test-create/SKILL.md` — Synced copy
- `.github/skills/smaqit.test-create/references/playbook-template.md` — Synced copy
- `.agents/skills/smaqit.test-create/SKILL.md` — Synced copy
- `.agents/skills/smaqit.test-create/references/playbook-template.md` — Synced copy
- `CHANGELOG.md` — Added v1.7.1 section
- `installer/main.go` — Version 1.7.0 → 1.7.1
- `installer/Makefile` — Version 1.7.0 → 1.7.1
- `.smaqit/tasks/015_synchronize_project_instructions_in_project_init.md` — Marked as Completed
- `.smaqit/tasks/PLANNING.md` — Updated task 015 status

## Next Steps

- Task 087 (rewrite Phase 4 Step 6 with generic stack-spec-driven deploy-skill matching) — already planned in previous session
- Clean up PLANNING.md: verify tasks 071/074 are complete, reconcile task 070 priority

## Session Metrics

- **Duration:** 2 sessions (bug fix + release)
- **Tasks completed:** 1 (test-create stack-agnostic fix)
- **Release:** v1.7.1
- **Files created/modified:** 11
- **Commits:** 3
