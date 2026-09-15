---
status: In Progress
created: "2026-09-15"
mode: Assisted
started: "2026-09-15"
---

# Guard Against Implementer-Written CHANGELOG.md Conflicts

## Description

`smaqit.task-complete`'s Phase 1 writes a `(pending vX.Y.Z · PR #NNN)`-annotated `CHANGELOG.md` entry directly to local `main` (Step 12), then rebases the task branch onto `main` and promotes that entry into a real version section on the branch (Step 13). If the task branch's own implementation commit (Step 9 for an owner) already touched `CHANGELOG.md`'s `[Unreleased]` section — because nothing currently tells an implementing agent not to — Step 13's rebase collides on the same lines and forces the documented hard stop ("If the rebase conflicts, STOP and report — never auto-resolve").

This gap has existed since task 027 introduced the two-phase pending/promote mechanism (2026-08-14); it is unrelated to task 036's later change of the rebase target from `origin/main` to local `main`, which left the conflict shape identical. The rule "`CHANGELOG.md` is never hand-written during implementation" was already an informal decision (recorded only in this repo's own session history and a compendium answer) but was never surfaced as an actual instruction to an implementing agent. This task closes that gap by adding an explicit guardrail in two places: `smaqit.task-start`'s Step 11 (in-context throughout implementation) and `smaqit.project-init`'s bundled `AGENTS.template.md` (persistent across every consuming project, regardless of context-window state). `task-complete`'s Step 13 "STOP and report, never auto-resolve" policy is intentionally left unchanged — this is a prevention fix, not a change to conflict handling.

## Issue Triage Context

**Mode:** Skip
**Technologies:** None
**Platforms/Environments:** None
**Features/Integrations:** None
**Versions/Constraints:** None

## Design Decisions

- **Prevention, not conflict-resolution:** `task-complete` Step 13's hard-stop policy on a genuine rebase conflict stays exactly as-is. This task only reduces how often that conflict shape is reachable in the first place.
- **Two-location guardrail:** `skills/smaqit.task-start/SKILL.md` Step 11 (seen throughout the implementing session) and `skills/smaqit.project-init/references/AGENTS.template.md`'s Scaffolding section (persistent, ships to every consuming project via `project-init`/`update`) — mirroring the existing precedent of the SSH-agent-recovery guidance being documented in multiple locations for durability.
- **`RULES.md` out of scope:** The three duplicated `references/RULES.md` files (`task-start`, `task-complete`, `task-list`) are phase/mode enforcement checklists, not implementation-content guidance, and are not touched.
- **No `CHANGELOG.md` hand-write during this task's own implementation:** `task-complete` Phase 1 writes the pending entry automatically at completion time — dogfooding the exact rule this task adds.
- **No `README.md` change:** this is an internal skill-instruction fix, not a documented user-facing feature or topology change.

## Implementation Steps

1. In `skills/smaqit.task-start/SKILL.md` Step 11 ("Begin implementation"), add an explicit sentence: implementers must not add or edit an entry in `CHANGELOG.md`'s `[Unreleased]` section during implementation — `task-complete` Phase 1 (Steps 12-13) is the sole writer and promoter of that entry, and a hand-written duplicate will force Step 13's rebase-conflict hard stop. Bump the skill's frontmatter `version` from `0.13.0` to `0.14.0`.
2. In `skills/smaqit.project-init/references/AGENTS.template.md`'s `# Scaffolding` section, add the same rule, phrased for the consuming project's own agent context (this file ships verbatim into every downstream project's `AGENTS.md`). Bump `skills/smaqit.project-init/SKILL.md`'s frontmatter `version` from `0.7.0` to `0.8.0` (matching task 038's precedent of bumping `project-init`'s version whenever its bundled template reference changes).
3. Add a new Q&A entry to `.smaqit/compendium.md` (Release Workflow or Task Management section) formalizing this rule as a discoverable answer, matching the style of existing entries (e.g. "Do release PRs carry an AI-authorship disclaimer footer?").
4. Extend `scripts/smoke-test-installer.sh` with an assertion that the new guardrail text is present in the generated and installed `AGENTS.template.md`, so a future edit cannot silently drop it.
5. Re-read `skills/smaqit.task-complete/SKILL.md` Step 13 to confirm its "STOP and report, never auto-resolve" wording is unchanged — verification only, no edit expected.
6. Run `make test` (15 suites) and `make smoke-test`; fix any stale assertions the new content trips.

## Known Issues Triage

**Triaged:** 2026-09-15
**Result:** Skipped — explicitly marked `Mode: Skip` in task Notes.

## Acceptance Criteria

- [ ] `skills/smaqit.task-start/SKILL.md` Step 11 explicitly instructs implementers not to add/edit a `CHANGELOG.md` `[Unreleased]` entry during implementation
- [ ] `skills/smaqit.project-init/references/AGENTS.template.md`'s Scaffolding section carries the same guardrail for every consuming project
- [ ] `skills/smaqit.task-start/SKILL.md` and `skills/smaqit.project-init/SKILL.md` frontmatter versions are bumped to reflect the content change
- [ ] `.smaqit/compendium.md` documents the rule as a discoverable Q&A entry
- [ ] `task-complete/SKILL.md`'s Step 13 "STOP and report, never auto-resolve" policy is verified unchanged
- [ ] `scripts/smoke-test-installer.sh` asserts the guardrail text is present in the generated/installed `AGENTS.template.md`
- [ ] `make test` and `make smoke-test` pass clean

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
| `skills/smaqit.task-start/SKILL.md` | Modify — Step 11 guardrail, version bump |
| `skills/smaqit.project-init/references/AGENTS.template.md` | Modify — Scaffolding section guardrail |
| `skills/smaqit.project-init/SKILL.md` | Modify — version bump only |
| `.smaqit/compendium.md` | Modify — new Q&A entry |
| `scripts/smoke-test-installer.sh` | Modify — new content assertion |

## Notes

`CHANGELOG.md` itself is not hand-edited during this task's implementation — `task-complete` Phase 1 writes the pending entry automatically at completion time, consistent with the rule being added here.
