---
status: In Progress
created: "2026-09-15"
mode: Assisted
started: "2026-09-15"
---

# Guard Against Implementer-Written CHANGELOG.md Conflicts

## Description

`smaqit.task-complete`'s Phase 1 authors a task's changelog entry in the wrong place. Step 12 commits a `(pending vX.Y.Z · PR #NNN)`-annotated bullet to `CHANGELOG.md`'s `[Unreleased]` section on `main`, and Step 13 transplants it into the task branch by rebasing the branch onto `main` and promoting the bullet into a `## [X.Y.Z]` section. Three verified structural problems follow:

1. **`[Unreleased]` has two owners on one line range.** The branch is where the implementation lives, and implementations naturally touch `[Unreleased]`; the entry is born on `main` and moved across by rebase. When both sides touch the section, Step 13's rebase conflicts and hits its own "STOP and report — never auto-resolve" rule. Task 027's own Findings record that promotion-by-rebase was bolted on during a self-review pass, not designed in.
2. **The version-claim registry has been dead since task 036.** `release-analysis` Step 1e and `release-approval` Step 4b read `git show origin/main:CHANGELOG.md` for pending annotations, but 036 moved Step 12's commit to local `main` only. The annotation reaches `origin/main` only inside the PR branch, where the next commit promotes it away — so a concurrent task's `release-analysis` never sees another task's claim.
3. **Step 13's rebase onto local `main` leaks every unpushed bookkeeping commit into the release PR.** Verified on `origin/main`: `chore: start task 038`, `chore: task 038 — pending v2.1.0 changelog entry`, `chore: start task 037`, `chore: create task 037`, and a compendium-docs commit all arrived through PR branches — contradicting 036's "bookkeeping commits are never pushed" contract.

The fix moves the entry to the branch from birth: after the PR exists, Phase 1 writes the `## [X.Y.Z] - date` section directly on the task branch (folding in any `[Unreleased]` bullets the implementer already left there) and plain-pushes; the claim registry becomes the set of open PRs titled `Prepare release vX.Y.Z`, read via `gh pr list --json` and filtered client-side; and `task-start` branches from freshly fetched `origin/main` so local bookkeeping never rides into a PR. This deletes the pending-entry convention, the rebase, the force-push, the `main`-side abandon cleanup, and the whole conflict class. A first implementation of this task as an instruction-level guardrail (in `task-start` Step 11 and `AGENTS.template.md`) was rejected on review as a circuit breaker on a structural flaw; the task's title is kept for lifecycle continuity.

## Issue Triage Context

**Mode:** Auto
**Technologies:** GitHub CLI (gh), Git
**Platforms/Environments:** None
**Features/Integrations:** gh pr list JSON output, PR-title matching in post-merge-release.yml
**Versions/Constraints:** None

## Design Decisions

- **No `main`-side `CHANGELOG.md` write anywhere in the task lifecycle:** the branch owns its entry from birth. `[Unreleased]` on `main` means only "unreleased" again, and nothing in Phase 1 commits to `main` except task-state bookkeeping.
- **Claim registry = open PR titles:** `release-analysis` Step 1e and `release-approval` Step 4b read `gh pr list --state open --limit 100 --json number,title` and keep titles matching `^(Prepare release|Release) v\d+\.\d+\.\d+$`. Filtering is client-side — never `--search`, whose index is eventually consistent. `gh` is already a hard dependency of Step 11's `gh pr create`; no new dependency.
- **Abandoned-PR versions return to the pool:** the registry is open PRs only, so a closed-unmerged PR's version becomes reusable. Task 027's "never reuse the version it claimed" was never actually enforced — its Step 24 deleted the annotation, which un-claimed it — and a never-tagged version is safe to reuse.
- **`task-start` branches from fetched `origin/main`, not local `main`:** without this, a second task started before `session-finish` would still carry the first task's unpushed bookkeeping into its PR even with the rebase gone.
- **Implementer edits to `[Unreleased]` are input, not error:** the on-branch write folds them into the release section, so `task-start` gets no "don't touch CHANGELOG" rule and `AGENTS.template.md` is untouched.
- **Concurrent-PR collisions at GitHub merge time are unchanged:** two open PRs both inserting `## [X.Y.Z]` below `[Unreleased]` can still conflict when the second merges — same as today, and now the only CHANGELOG conflict class.
- **Consumers with an in-flight old-style task are unaffected:** that branch already carries its promotion commit, and a leftover annotation on their local `main` is promoted away by its merge. Not a breaking change.

## Implementation Steps

**Phase A — lifecycle skills**

1. `skills/smaqit.task-complete/SKILL.md`: rewrite the Phase 1 intro bullet (line 14) and the Local-Only Sessions paragraph (line 21: bookkeeping = Steps 14/18/abandon; only Step 11's branch push and Step 13's changelog push touch `origin`). Rewrite Step 12 as *Write this task's versioned `CHANGELOG.md` section on the branch* (in the worktree, via `release-prepare-files`' Task-Release operation from step 4; never touches `main`). Rewrite Step 13 as *Commit and push the changelog commit* — `git add CHANGELOG.md`, commit `chore: task NNN — changelog for vX.Y.Z`, plain `git push origin <branch>`; a rejected push STOPs and reports, no rebase, no `--force-with-lease`. Fix Step 17's "Steps 12 and 14" text, drop Step 21's rebase-rewrites-SHAs sentence (squash rationale stays), collapse the Abandon Path to close-PR + status (no `main`-side cleanup; renumber). Bump version `0.12.0` → `0.13.0`.
2. `skills/smaqit.task-start/SKILL.md` Step 3: create the owner branch from `origin/main` after `git fetch origin main`, not from local `main`, with the rationale that local `main` legitimately carries unpushed bookkeeping that must not enter a PR. Bump version `0.13.0` → `0.14.0`.
3. `skills/smaqit.task-complete/references/RULES.md` lines 154 and 168-169: Phase 1 order becomes commit → compute version → push branch + `gh pr create` → write `## [X.Y.Z]` on the branch → push → `PR Open`; replace the "PR before pending entry" rule with "the PR title is the version claim; the branch carries its own `## [X.Y.Z]` section". Copy byte-identically to the `task-start` and `task-list` copies (the lifecycle test diffs them).

**Phase B — release skills**

4. `skills/smaqit.release-prepare-files/SKILL.md`: replace *Pending Entry Convention* and *Pending Entry Mode* with one *Task-Release Mode* operation: take `release-analysis`'s `changes` list plus whatever bullets sit under `[Unreleased]` in the branch's working tree, dedupe, write them under `## [X.Y.Z] - YYYY-MM-DD` inserted directly below `## [Unreleased]` (the same shape as batched Step 2C), and leave `[Unreleased]` as an empty header. No comparison-link update (unchanged from today). Bump version `0.8.0` → `0.9.0`.
5. `skills/smaqit.release-analysis/SKILL.md`: rewrite Step 1e as *Claimed-version awareness* using the `gh pr list` read from the Design Decisions. Clarify Step 2E that Task mode reads `[Unreleased]` from `<task-branch>` (where the implementer's bullets are). Update Step 4's collision text, the Output `mode` echo, and the Notes bullet about fetching before the pending-version check. Bump version `0.9.0` → `0.10.0`.
6. `skills/smaqit.release-approval/SKILL.md` Step 4b: re-scan open PR titles the same way instead of `origin/main`'s `CHANGELOG.md`. Bump version `0.3.0` → `0.4.0`.
7. `skills/smaqit.release-git-pr/SKILL.md` *Invocation from `smaqit.task-complete`* section: Steps 1-2 skipped because `task-complete`'s Step 13 commits `CHANGELOG.md` itself on the branch; Step 3 skipped because `task-complete` pushes (plain push); remove the force-with-lease sentence. Bump version `0.4.0` → `0.5.0`.

**Phase C — tests and docs**

8. `tests/skills/test-task-complete-pr-lifecycle.sh` lines 257-269: replace the pending-write ordering and `--force-with-lease` assertions with: PR creation precedes the on-branch changelog write; Phase 1 contains no `rebase main` and no `--force-with-lease`; Step 13 uses a plain push; `task-start` documents branching from `origin/main`.
9. Rename `tests/skills/test-release-analysis-pending-versions.sh` → `test-release-analysis-claimed-versions.sh` (Makefile target too). Mechanical test: a fixture `CHANGELOG.md` whose `[Unreleased]` holds an implementer bullet, plus a `changes` list → run the documented fold → assert the new `## [X.Y.Z]` section sits below `[Unreleased]`, holds both bullets deduped, `[Unreleased]` is empty, older sections untouched. Contract assertions: `release-analysis` documents `gh pr list` claim awareness; `release-prepare-files` documents Task-Release Mode; no `(pending v` string remains anywhere under `skills/`.
10. `.smaqit/compendium.md`: rewrite the "How does `task-complete` work…" Phase 1 paragraph, the pending-entry sentence in "Why are task files… excluded", and the "pending-claim check" sentence in the `release-analysis` boundary entry; add one entry recording where a task's changelog entry is authored, how versions are claimed, and — as history — why the `main`-born design was retired (the 036 registry regression and the bookkeeping leak).

**Verification**

11. `make test` and `make smoke-test` from the worktree; `git diff --check`; `grep -rn "pending v" skills/` returns nothing.
12. `make -C installer prepare && make -C installer build && ./installer/dist/smaqit-extensions --install-global` from the worktree (the README's contributor loop; task 038 did the same), so that `task.complete 039` Phase 1 itself runs the new mechanism live.

## Known Issues Triage

**Triaged:** 2026-09-15
**Tools searched:** GitHub CLI (gh) → `cli/cli`, Git → `git/git`
**Result:** Advisory

### Advisory Issues
- [#9188 Piping `gh pr list -A ...` changes its output](https://github.com/cli/cli/issues/9188) — `cli/cli` — opened 2024-06-09 — bug, priority-3, gh-pr — the projected detail attributes the behavior to the `-A` author filter on a renamed repository whose remote still uses the old name, "not the JSON or jq options"; this task's registry read is `gh pr list --state open --limit 100 --json number,title` with no `-A`, and this repository is not renamed, so the feature dimension is not confirmed. Not blocking.
- [#13239 gh search prs --json missing mergeStateStatus and reviewDecision fields available in gh pr list](https://github.com/cli/cli/issues/13239) — `cli/cli` — opened 2026-04-20 — enhancement, gh-pr, gh-search, stale — corroborates preferring `gh pr list --json` over `gh search prs`; informational.
- [#13765 Add --json-default (or bare --json) to mirror default table columns in list commands](https://github.com/cli/cli/issues/13765) — `cli/cli` — opened 2026-07-01 — enhancement, gh-pr, gh-run, gh-issue, stale — unrelated to an explicit `--json number,title` field list; informational.
- Seven further open `enhancement` requests about `pr list` / `issue list` presentation (#14413, #846, #5983, #8890, #12829, #12306, #8415) — none touch `--json` field correctness; no action.

### Historical (Closed)
- [#14214 `issue view --comments --json` silently ignores `--comments`](https://github.com/cli/cli/issues/14214) — `cli/cli` — closed 2026-08-27 — a `--json` flag-interaction bug on a different command; no bearing on `pr list`.
- Nine closed items returned by the query were `suspected-spam` or empty-label noise (#14422, #14421, #14382, #14383, #14381, #14236, #14235, #14234, #14233); disregarded.

### Unresolvable Tools
- None

### Omitted Tools
- None — `git/git` was searched (open and closed, terms "fetch branch") and returned no issues. GitHub Actions appears in the research-map task block as documentation context for the PR-title trigger but is not a Technologies entry, so it was not searched.

### Search Warnings
- None (`incomplete_results: false` on all four searches).

## Acceptance Criteria

- [ ] `task-complete` Phase 1 writes the `## [X.Y.Z]` section on the task branch and never commits `CHANGELOG.md` to `main`
- [ ] Phase 1 contains no rebase and no force-push; a rejected branch push STOPs and reports
- [ ] `release-analysis` Step 1e and `release-approval` Step 4b derive claimed versions from open `Prepare release vX.Y.Z` PR titles via `gh pr list --json`, filtered client-side
- [ ] `task-start` creates the owner branch from freshly fetched `origin/main`
- [ ] The `(pending vX.Y.Z · PR #NNN)` convention is gone from every file under `skills/`, and a hermetic test guards its absence
- [ ] The three `RULES.md` copies are byte-identical and describe the new Phase 1 order
- [ ] Implementer bullets under `[Unreleased]` on the branch are folded into the release section, proven by a hermetic test
- [ ] `.smaqit/compendium.md` reflects the new mechanism and records why the `main`-born design was retired
- [ ] `make test` and `make smoke-test` pass clean
- [ ] The global install is refreshed from this build so `task.complete 039` Phase 1 exercises the new flow

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
| `skills/smaqit.task-complete/SKILL.md` | Modify — Phase 1 Steps 12-13 rewritten (on-branch changelog write, plain push), Local-Only Sessions, Step 17/21 text, Abandon Path collapsed; version bump |
| `skills/smaqit.task-start/SKILL.md` | Modify — Step 3 branches from fetched `origin/main`; version bump |
| `skills/smaqit.task-complete/references/RULES.md` | Modify — Phase 1 order and PR-title-as-claim rule |
| `skills/smaqit.task-start/references/RULES.md` | Modify — byte-identical copy |
| `skills/smaqit.task-list/references/RULES.md` | Modify — byte-identical copy |
| `skills/smaqit.release-prepare-files/SKILL.md` | Modify — Pending Entry Convention/Mode replaced by Task-Release Mode; version bump |
| `skills/smaqit.release-analysis/SKILL.md` | Modify — Step 1e claimed-version awareness via `gh pr list`, Step 2E/4/Notes text; version bump |
| `skills/smaqit.release-approval/SKILL.md` | Modify — Step 4b re-check via PR titles; version bump |
| `skills/smaqit.release-git-pr/SKILL.md` | Modify — Invocation-from-task-complete section; version bump |
| `tests/skills/test-task-complete-pr-lifecycle.sh` | Modify — replace pending-write/force-with-lease assertions |
| `tests/skills/test-release-analysis-pending-versions.sh` | Delete — renamed |
| `tests/skills/test-release-analysis-claimed-versions.sh` | Create — fold algorithm test, claim-awareness contract, no-`(pending v` guard |
| `Makefile` | Modify — test target rename |
| `.smaqit/compendium.md` | Modify — three entries updated, one added |

## Notes

The rejected first implementation (instruction-level guardrail in `task-start` Step 11, `AGENTS.template.md`, a smoke-test assertion, and a compendium entry) is preserved in the stash `task 039: discarded guardrail implementation (re-planned as structural fix)` on the task branch for reference and can be dropped once this task ships.

This task's own `task.complete 039` Phase 1 is the first live run of the redesigned mechanism: the global install must be refreshed from this worktree's build before invoking it, otherwise the installed (old) `task-complete` would run the pending-entry flow against skills that no longer document it.
