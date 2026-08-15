---
status: Not Started
created: "2026-08-15"
---

# Fix `update` Writing Project-Scoped Agent/Skill Mirrors Despite Documenting Itself as Global-Only

## Description

`smaqit-extensions update` silently writes a full project-scoped mirror of every agent/skill (`.agents/skills/`, `.claude/agents/`, `.claude/commands/`, `.claude/skills/`, `.codex/agents/`, `.github/agents/`, `.github/skills/` — 231 files) into whatever project directory it's run from, even on a project that has no committed dogfooding mirrors of its own and was deliberately migrated to global-only installation (task 023). `--help` documents `update` as "Update binary and refresh global install" — global paths only (`~/.agents/skills/`, `~/.claude/skills/`, `~/.codex/agents/`, etc.) — and `init`, tested in isolation, matches its own documented scope exactly (`.smaqit/tasks/`, `.smaqit/history/`, `.smaqit/user-testing/`, `.github/workflows/` only, nothing under `.agents/`/`.claude/`/`.codex/`/`.github/agents/`/`.github/skills/`). So this is specifically an `update` defect, not a general scope-detection problem shared with `init`.

Reported against `agentic-cms` (github.com/ruifrvaz/agentic-cms): the project had its project-local agent/skill mirrors deliberately deleted (commit `391d4de`, "cleaned up agents and skills", in favor of the global-only install task 023 introduced). Running `smaqit-extensions update` in that project silently restored the full 231-file mirror — confirmed by exact `mtime` correlation between the restored files and the `smaqit-extensions` binary's own rebuild timestamp, and confirmed directly by the user, who reported running `update` there. The user reports seeing the same restoration behavior on at least one other project, so this is not project-specific state — it reproduces from the tool itself on every self-update.

**Likely root cause area:** `update`'s self-update flow long predates global-only installation — task 009 ("Add smaqit-extensions update Self-Update Command") shipped 2026-05-09, task 023 ("Global User-Level Installation with Agent-Specific Adapters") shipped 2026-08-10, three months later. `update`'s post-self-update reinit step (the equivalent of `agentic-cms update`'s `reinitWithBinary` pattern: self-update, then re-run scaffolding in the current directory if it looks like an installed project) most likely never picked up whatever scope-selection logic task 023 added for `init`, and is still unconditionally performing pre-023 project-scoped scaffolding.

## Issue Triage Context

**Mode:** Skip
**Technologies:** None
**Platforms/Environments:** Linux
**Features/Integrations:** None
**Versions/Constraints:** Regression window is between task 009 (2026-05-09) and task 023 (2026-08-10); reproduced against the `update`-installed v2.0.0 binary

## Design Decisions

TBD — to be confirmed during assessment.

## Implementation Steps

1. Locate `update`'s post-self-update reinit path (mirrors `agentic-cms update`'s `reinitWithBinary`: re-exec the freshly-downloaded binary, then re-run project scaffolding if the current directory looks like an installed project).
2. Compare it against `init`'s current scope-selection logic (global vs. `--scope project`, from task 023) — confirm `update`'s reinit calls the same scope-aware path `init` does, rather than a stale pre-023 code path that assumes project scope unconditionally.
3. Fix `update` to respect the same global-by-default / `--scope project`-opt-in behavior `init` already has, so it never writes `.agents/`, `.claude/`, `.codex/`, `.github/agents/`, or `.github/skills/` into a project unless that project explicitly opted into project-scoped installation.
4. Add a regression test: run `update` (or its reinit step directly) against a project with no prior project-scoped mirrors and assert none of those five paths are created.
5. Run `make test` and the installer smoke test; verify manually against a scratch project the way this task's diagnosis did (`init` in an empty repo → confirm only `.smaqit/tasks/`, `.smaqit/history/`, `.smaqit/user-testing/`, `.github/workflows/` exist).

## Known Issues Triage

[Populated by smaqit.task-start via smaqit.utils.triage-issues. Do not edit manually.]

## Acceptance Criteria

- [ ] `smaqit-extensions update`, run in a project with no project-scoped agent/skill mirrors and no `--scope project` opt-in, does not create `.agents/`, `.claude/skills/` or `.claude/agents/` or `.claude/commands/`, `.codex/agents/`, `.github/agents/`, or `.github/skills/`
- [ ] `update`'s reinit path and `init`'s scope selection are verifiably the same code path (or share the same scope-decision logic), not parallel implementations that can drift again
- [ ] A regression test covers this scenario
- [ ] `make test` and the installer smoke test pass

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

## Files to Create / Modify

| File | Action |
|------|--------|
| installer's `update` command source (self-update + reinit path) | Modify |

## Notes

Diagnosed from `agentic-cms` (a consumer project), not from within `smaqit-extensions` itself — reproduction steps there:
1. `git clone` a scratch copy of a project with no project-scoped agent/skill mirrors (or any empty git repo).
2. Confirm `smaqit-extensions init` alone does *not* create `.agents/`, `.claude/agents|commands|skills/`, `.codex/agents/`, `.github/agents/`, or `.github/skills/` — only `.smaqit/tasks/`, `.smaqit/history/`, `.smaqit/user-testing/`, `.github/workflows/`.
3. Run `smaqit-extensions update` in the same directory and confirm whether those five paths appear — this is the actual repro of the reported defect; not re-run here since `update` mutates the real global install and downloads a fresh binary over the network, which wasn't appropriate to do from the diagnosing session.

Child tasks inherit their active parent's branch, worktree, and workflow mode. Only a standalone or parent task owns Git lifecycle cleanup.
