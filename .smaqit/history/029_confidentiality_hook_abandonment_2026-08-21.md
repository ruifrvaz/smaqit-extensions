# Confidentiality Hook Abandonment

**Date:** 2026-08-21
**Session focus:** Started task 035 (a git pre-commit hook scanning staged content for credential/PII/financial-figure patterns, ported from `agentic-cms`'s `ac-classify` heuristic floor), fully implemented and opened its release PR, then abandoned it before merge after a live design discussion surfaced a structural conflict with `agentic-cms`'s own classification hook.
**Tasks completed:** None
**Tasks abandoned:** 035 — Confidentiality Pre-Commit Hook (Cross-Domain Secrets/PII Scanner)
**Tasks referenced:** None else touched

## Actions Taken

- Started with `smaqit.session-start` (spanning from the prior day's session-finish); task 035 was already created and fully speced with unusually detailed Design Decisions.
- Ran `smaqit.task-start 035`: resolved as owner, created branch/worktree, ran issue triage (Historical only — one closed `golang/go` `go:embed`+Windows path-matching issue, not directly applicable; Bash resolved to an unrelated namesake repo and was skipped).
- Implemented the hook: `installer/hooks/pre-commit-confidentiality.sh` (bash 3.2/POSIX-ERE, macOS-compatible, no `\s`/`\b`/associative arrays) and `installer/hooks/confidentiality-scan-ignore`, plus `installConfidentialityHook`/`installConfidentialityGitHook` in `installer/main.go` implementing three distinct update semantics (force-overwrite script, seed-once exclude-list, namespaced-managed-block `.git/hooks/pre-commit` logic — create fresh / idempotent replace / append-after-foreign-content). Added the companion skill `smaqit.hooks.confidentiality-scan` bundling its own copy of the script for standalone manual invocation.
- User asked whether the installer's default install path meant the hook would install globally on every repo. It doesn't (confirmed via code + a live CLI run), but the question surfaced that `update` on an already-`init`'d project would silently gain the hook — refactored to a new opt-in `--with-hooks` flag threaded through `scaffoldProject`, `installProject`, `checkAndReInit`, and the re-exec'd subprocess in `checkAndReInitWithBinary`, with dedicated tests for the flag parsing and forwarding.
- Wrote 14 new Go tests (fresh install, reinstall-preserves-ignore-list, append-not-clobber, idempotent-replace, planted-credential blocks/ignore-list respected, delta-scoping, `--with-hooks` parsing and subprocess forwarding). `go build`/`go vet`/`gofmt`/`go test ./...`/`make smoke-test` all verified green repeatedly, plus a live end-to-end CLI check of default-vs-`--with-hooks` behavior.
- Ran `task.complete 035`: wrote Findings, checked off all 8 acceptance criteria, computed the release version via `release-analysis` Task mode (v2.1.0, MINOR), opened PR #131 (`Prepare release v2.1.0`), pushed the pending `CHANGELOG.md` entry to `main`, promoted it on the branch. Stopped per Assisted mode's Phase 1 gate.
- User then asked an analytical question: does `agentic-cms`'s own classifier hook still add value once this one exists? Investigation of `agentic-cms`'s `ac-classify` (read directly from the sibling repo) showed it's a content-*governance* system (C0–C3 ratings, staleness detection, hash-bound acks, index/log bleed-check), not a flat secret scanner — genuinely different from the new coarse net.
- Follow-up question exposed the real problem: on a project running both hooks, a `docs/`/`wiki/` page that `ac-classify` rates and acknowledges as legitimately sensitive would be permanently re-blocked by the new hook anyway, since the two tools share no ack/allow state — a standing per-page maintenance burden, not a one-time integration cost.
- User decided to abandon task 035 on that basis. Closed PR #131 (one 403 PAT-permission interruption on `gh pr close --comment`, handled per the repo's standing PAT-switch instruction — hard-stopped, retried after user confirmation), removed the pending `CHANGELOG.md` entry from `main` (v2.1.0 never used), marked the task `Abandoned` with the reasoning recorded in Findings, corrected the now-stale "agentic-cms task 012 shrinks to tier-1" follow-up note, moved the `PLANNING.md` entry to a new Abandoned Tasks table, removed the worktree, rebuilt the workspace file, and force-deleted the local branch (remote kept as an audit trail).

## Problems Solved

- **None shipped** — the task's own detection logic and installer wiring worked correctly (verified by 14 passing tests and a live CLI run), but the underlying premise (a second, independent secret/PII/financial gate layered onto a project that may already run `agentic-cms`'s classification hook) was determined to be net-negative before merge.
- **Real implementation bug found and fixed mid-task, now moot but instructive**: the script initially hardcoded its ignore-file path one directory level shallower than where the installer actually wrote it — caught only by a Go integration test exercising the real installed artifact, not by an earlier hand-placed manual bash test.

## Decisions Made

- **Wired the (now-abandoned) hook into both `scaffoldProject` and `installProject`**, not just `installProject` as the task file literally said — `installProject` never calls `scaffoldProject` internally, so wiring only there would have made the hook unreachable from real `init`/`update` usage, repeating the exact mixup task 033 fixed. Moot now, but the underlying lesson (verify a literal instruction against the actual call graph) still applies to future tasks.
- **Pivoted to an opt-in `--with-hooks` flag** rather than always-on scaffolding, once a live question surfaced that `update` on an existing project must never silently gain new commit-time behavior.
- **Abandoned rather than redesigned.** Considered options (shared ack state, deferring to `ac-classify`'s rating, narrowing scope to non-docs/wiki paths only) but concluded the maintenance burden of coordinating two independent gates over the same content wasn't worth it — the existing `ac-classify` tool already owns confidentiality governance for `agentic-cms` projects, and this hook's original motivation (catching secrets *outside* docs/wiki) doesn't need a second competing gate mechanism to justify existing on its own, narrower terms; it was scoped as "the general cross-project net" specifically because it was meant to also cover the overlap case, and that's exactly the part that doesn't hold up.

## Files Modified

- `installer/hooks/pre-commit-confidentiality.sh`, `installer/hooks/confidentiality-scan-ignore` — created, then abandoned in the closed PR (not present on `main`)
- `installer/main.go`, `installer/main_test.go` — `installConfidentialityHook`/`installConfidentialityGitHook`, `--with-hooks` flag plumbing, 14 new tests — created, then abandoned in the closed PR (not present on `main`)
- `skills/smaqit.hooks.confidentiality-scan/` — companion skill — created, then abandoned in the closed PR (not present on `main`)
- `README.md`, `Makefile` — documentation/skill-list updates for the above — created, then abandoned in the closed PR (not present on `main`)
- `.smaqit/tasks/035_confidentiality_pre_commit_hook.md` — started, implemented, completed (Phase 1), then abandoned; Findings and Notes updated to record the abandonment reasoning
- `.smaqit/tasks/PLANNING.md` — task 035 lifecycle, new "Abandoned Tasks" table (first entry in this project)
- `.smaqit/references/project-research.md` — task 035 block (Go/Bash/git-hooks/githooks URLs)
- `CHANGELOG.md` — pending v2.1.0 entry added then removed; no net change on `main`
- `smaqit-extensions.code-workspace` — regenerated across worktree create/remove cycles

## Next Steps

- Tasks 028, 002, 007, 010 remain Not Started, untouched this session.
- No follow-up filed in `agentic-cms` — the originally-planned "task 012 shrinks to tier-1" effect does not apply, since this hook never shipped. `agentic-cms`'s own task 012 (classifier scope beyond docs/wiki) is unaffected and remains a live option in that repo if its owner still wants to pursue it independently.
- No new follow-up filed in this repo.

## Session Metrics

- **Duration:** Full session, single continuous thread
- **Tasks completed:** 0
- **Tasks abandoned:** 1 (035) — fully implemented and PR-opened, then reversed on design grounds before merge
- **Releases shipped:** 0 (v2.1.0 was claimed then released back unused)
- **Tests written:** 14 new Go tests, all passing at abandonment time (verified via the closed PR's CI-equivalent local runs, not merged)
- **403 PAT interruptions handled:** 1 (`gh pr close --comment`), per standing instruction (hard-stop, no diagnosis, retry on confirmation)
