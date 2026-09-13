# Project Init Scaffolding Fixes

**Date:** 2026-09-13
**Session focus:** Reviewed and fixed three confirmed gaps in `smaqit.project-init`'s scaffolding, from user report through implementation and release.
**Tasks completed:** 038 — Fix Project-Init Scaffolding: Drop Copilot-Instructions Symlink, Trim Boilerplate, Add Baseline Workspace (shipped v2.1.0, PR #137)
**Tasks referenced:** None — no other task touched this session

## Actions Taken

- Started with `smaqit.session-start`; presented the four Not Started tasks (028, 002, 007, 010) and recommended task 002 as the smallest well-scoped next step.
- User instead asked for a design review of `smaqit.project-init`, reporting three complaints from real usage: it injects "shitty" scaffolding instructions irrelevant to downstream projects, still relies on the old `copilot-instructions.md` design, and never creates a workspace file.
- Investigated the skill, its template, and task 015's original design record. Confirmed all three complaints directly against current source (not a stale install — verified the installed binary/skill matched the `v2.0.6` tag): `AGENTS.template.md`'s `# Scaffolding` section force-copies a Desktop Linux SSH agent recovery paragraph and an 11-item scope-project-only path list into every project regardless of relevance; `.github/copilot-instructions.md` was a relative OS symlink whose creation depends on the acting tool/platform supporting symlinks (task 015's own issue triage had already flagged the adjacent risk, claude-code#66559); `.code-workspace` is only ever created by `smaqit.utils.worktree`'s worktree-lifecycle script, never at project init.
- Researched GitHub's own documentation (`docs.github.com/en/copilot/reference/custom-instructions-support`, the CLI custom-instructions guide, and the 2025-08-28 coding-agent changelog post) and confirmed VS Code Copilot Chat, the Copilot coding agent, and Copilot CLI all now read a root `AGENTS.md` natively — grounding the decision to drop the symlink rather than patch it.
- Asked the user two clarifying questions (symlink fallback approach; whether to scaffold a baseline workspace) via `AskUserQuestion`; the user chose to drop `copilot-instructions.md` entirely with no legacy fallback anywhere, and confirmed the baseline-workspace idea.
- Ran `smaqit.task-plan` (Mode A) to formalize the fix into an execution plan and pre-populated task fields; the user requested one revision (no legacy-fallback mention anywhere, including the six secondary skills' generic instruction-probe hints) before approving. `smaqit.task-create` created task 038.
- Ran `smaqit.task-start 038`: resolved as owner, created branch/worktree. Research map had no task 038 block yet; refreshed it with 6 verified URLs (Go docs, GitHub Copilot custom-instructions docs ×3, Claude Code memory/import docs, VS Code multi-root workspace docs). Issue triage returned Advisory (two tangential Claude Code symlink-related issues that corroborate rather than block the design; one closed issue confirming the industry direction toward `AGENTS.md`) — no blocking issues, continued without a gate.
- Implemented the fix: trimmed `AGENTS.template.md`'s Scaffolding section; rewrote `smaqit.project-init/SKILL.md`'s topology and Step 8 to migrate-then-delete a legacy `copilot-instructions.md` instead of symlinking to it; updated six secondary skills' instruction-probe hints, `README.md`, and `.smaqit/compendium.md`; added `installBaselineWorkspace` to `installer/main.go` (wired into `scaffoldProject`, reusing the existing `writeFileIfMissing` create-if-absent helper) plus two new Go unit tests; fixed the smoke-test assertions that had gone stale against the new topology and added new ones for the baseline workspace file.
- Verified thoroughly: `make test` (15 suites), `make smoke-test`, `go build`/`vet`/`test`, `gofmt`, `git diff --check` all clean. Live-tested both paths in scratch directories: the built binary's `init` produces the correct baseline `.code-workspace` (idempotent, and round-trips cleanly with `7_build_workspace.sh` when a real worktree is later added), and the installed `smaqit.project-init` skill correctly migrates a seeded legacy `copilot-instructions.md`'s sentinel content into `AGENTS.md` and deletes the file.
- Mid-implementation, the user flagged a second-order issue: the template's scope-project-only path list still named `installer/`, `agents/`, `skills/`, `commands/`, `scripts/` at the repo root — paths that only ever exist in smaqit-extensions' own source checkout, never in any consuming project (not even one that used `--scope project`, which only creates the platform mirror directories). Confirmed and removed; re-ran the full test suite and smoke test clean, and refreshed the global install.
- Ran `task.complete 038`: wrote Findings, checked off all 8 acceptance criteria, computed the release version via `release-analysis` Task mode (MINOR — a genuinely new capability, the baseline workspace file — landing on v2.1.0 against the v2.0.6 boundary, no pending-version collisions), opened PR #137 ("Prepare release v2.1.0"), wrote and promoted the pending changelog entry. Stopped per Assisted mode's Phase 1 gate.
- User merged the PR — ran Phase 2: confirmed `MERGED` via `gh pr view`, merged `origin/main` into local `main` (a real merge, since local `main` was 3 commits ahead with unpushed PR-open bookkeeping), set status to `Completed`, moved the `PLANNING.md` entry, removed the worktree, force-deleted the local branch. Confirmed the `v2.1.0` tag and GitHub Release published cleanly.
- After reporting completion, the user asked a sharp follow-up: does the `smaqit.project-init` *skill* itself also scaffold the baseline workspace? Checked the merged skill file directly — confirmed it does not; only `smaqit-extensions init` (the Go binary's `scaffoldProject`) does. This was a deliberate substitution made while turning the user's original answer ("project-init creates a minimal `.code-workspace`") into the actual plan, reasoned through in the plan's Design Decisions but never re-confirmed with the user as a substitution. Surfaced the resulting edge-case gap (a project that only ever runs the `project-init` skill directly, without ever running `smaqit-extensions init` first, gets no workspace file from either path) and asked whether to fix it. User chose to leave it as-is — every documented install path already runs `init` as part of setup, so the skill-only scenario is self-inflicted misuse, not a real workflow.

## Problems Solved

- **Irrelevant, unconditionally-copied scaffolding boilerplate**: `AGENTS.template.md` force-injected desktop-SSH-recovery guidance and a list of paths that exist only under `--scope project` (or previously, incorrectly, only in smaqit-extensions' own repo) into every single downstream project's canonical `AGENTS.md`, regardless of relevance. Trimmed to what's actually universal, with paths that can genuinely appear in a consuming project kept and everything else removed.
- **A fragile, tool-dependent symlink design**: `.github/copilot-instructions.md` as a relative OS symlink assumed every acting tool/platform could create real symlinks — an assumption task 015's own research had already flagged as risky for the adjacent CLAUDE.md-as-symlink case. Verified via GitHub's own docs that the assumption is now unnecessary altogether, since Copilot reads `AGENTS.md` natively; retired the symlink design rather than hardening it.
- **No workspace file until a project's first task**: `smaqit-extensions init` now scaffolds a baseline single-folder `.code-workspace`, matching the exact shape `7_build_workspace.sh` already expects, so the transition to a project's first real task worktree is seamless rather than the file appearing out of nowhere.

## Decisions Made

- **Drop `.github/copilot-instructions.md` entirely, no fallback anywhere** — confirmed against GitHub's own documentation rather than assumption, and applied uniformly across the skill and all six secondary skills' generic instruction-probe hints per direct user instruction.
- **Baseline workspace scaffolding lives in the Go binary (`scaffoldProject`), not the `project-init` skill** — a substitution made during planning for determinism and precedent-matching (mirrors `post-merge-release.yml`'s create-if-absent handling), which left an edge-case gap the user later caught and chose to accept rather than fix.
- **SSH-recovery guidance and the scope-project path list are trimmed, not deleted outright** — the underlying guidance is still valid for a project that actually uses `smaqit.release-git-local` or `--scope project`; it just shouldn't be force-copied into every project regardless of relevance.
- **CHANGELOG.md is never hand-written during implementation** — left untouched during the implementation phase per this project's established convention that `task-complete` Phase 1 is the sole writer of the pending-annotated entry.

## Files Modified

- `skills/smaqit.project-init/references/AGENTS.template.md` — trimmed Scaffolding section
- `skills/smaqit.project-init/SKILL.md` — new topology, Step 8 rewritten, version bumped to 0.7.0
- `skills/smaqit.session-start/SKILL.md`, `skills/smaqit.project-diagnose/SKILL.md`, `skills/smaqit.project-recap/SKILL.md` (+ `references/OUTPUT_FORMAT.md`), `skills/smaqit.project-research/SKILL.md`, `skills/smaqit.test-create/SKILL.md` — instruction-probe hints updated to the new topology
- `README.md`, `.smaqit/compendium.md` — topology description updated, plus a new post-completion entry distinguishing the CLI's `init` from the skill's `project-init`
- `installer/main.go` — new `installBaselineWorkspace`, wired into `scaffoldProject`, `printHelp()` updated
- `installer/main_test.go` — two new unit tests (creation + idempotency)
- `scripts/smoke-test-installer.sh` — fixed stale assertions, added new ones
- `CHANGELOG.md` — `## [2.1.0]` section
- `.smaqit/tasks/038_project_init_scaffolding_gaps.md` — full lifecycle (created, started, completed)
- `.smaqit/tasks/PLANNING.md` — task 038 moved Active → Completed
- `.smaqit/references/project-research.md` — task 038 block added

## Next Steps

- Tasks 028, 002, 007, 010 remain Not Started, untouched this session.
- No new follow-up filed. The accepted edge-case gap (project-init skill run standalone, without `smaqit-extensions init` ever having run, produces no workspace file) is a known, deliberately unaddressed limitation — revisit only if a real project actually hits it.

## Session Metrics

- **Duration:** Full session, single continuous thread
- **Tasks completed:** 1 (038), shipped v2.1.0 (PR #137, merged)
- **Tasks abandoned:** 0
- **Releases shipped:** 1 (v2.1.0 — MINOR, new baseline-workspace capability plus two fixes)
- **Tests written:** 2 new Go unit tests (`TestScaffoldProjectCreatesBaselineWorkspace`, `TestScaffoldProjectPreservesExistingWorkspace`); full `make test` (15 suites) and `make smoke-test` both passing, `go vet`/`gofmt`/`git diff --check` clean
- **Live verification:** two separate live scratch-directory trials (Go binary `init` path; LLM-driven `project-init` skill migration path), both confirmed correct
- **Design gaps caught post-completion:** 1 (baseline-workspace scaffolding living only in the Go binary, not the skill itself) — surfaced by the user, confirmed, and consciously accepted rather than fixed
