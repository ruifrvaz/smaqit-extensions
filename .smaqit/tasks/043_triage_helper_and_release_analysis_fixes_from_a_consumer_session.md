---
status: Not Started
created: "2026-10-16"
---

# Triage Helper and Release-Analysis Fixes From a Consumer Session

## Description

Found while a consumer project (Magnificah infrastructure, its session 024, 2026-10-14 → 16) ran
the task lifecycle three times (`task.start` → triage → `task.complete`). Three skills that live in
this repository behaved in ways that produced wrong records downstream. Priority: Medium.

**1. `smaqit.utils.triage-issues` — the output key is unnamed.** `SKILL.md` Step 6 (line 101) says
the helper "emits compact JSON only: at most ten issues, each containing number, title, …, plus
`incomplete_results`", but never names the list's key. The helper actually prints
`{"incomplete_results": …, "items": [...]}`. The consuming agent read `.issues`, got nothing, and
recorded two triages as empty ("Clear", then "helper unreliable") although every search had
returned results — one of them relevant open issues. Name the exact output shape (top-level keys
and per-item fields) in Step 6 and in the helper's own usage text.

**2. `smaqit.utils.triage-issues` — unauthenticated searches hit the rate limit.**
`scripts/github-issues.sh` calls the GitHub REST API with plain `curl` (lines 27–33) and no token.
GitHub allows 10 unauthenticated search requests per minute; a full run (up to 5 repositories × an
open and a closed search, plus `resolve` calls) reaches it, and later searches fail. In the
consumer session the second half of a run came back as failures that were indistinguishable at a
glance from empty results. Use a token when one is available (`GH_TOKEN`/`GITHUB_TOKEN`, or
`gh auth token`) and/or pace the calls; make a rate-limit response (HTTP 403/429 with
`X-RateLimit-Remaining: 0`) an explicit search warning per Step 8, never an empty `items` list.

**3. `smaqit.release-analysis` — Task mode misses PRs merged into `main` after the branch's last
sync.** Step 2 (line 109) collects `<boundary-sha>..<task-branch>`. When a task ships some of its
changes through interim PRs (here registry PRs merged while the task branch sat behind `main`),
those merges are part of the same release but not on the task branch, so the `changes` list missed
them and had to be completed by hand. In Task mode, also collect `origin/main` merges since the
boundary that are not yet on the task branch (or analyze the merge result
`<boundary-sha>..(origin/main ∪ task-branch)`), and say so in the Step 2 verification.

**4. `smaqit.task-start` — the task branch tracks `origin/main`.** Step 3 (line 71) creates the
branch with `git branch "<branch>" origin/main`, which sets `origin/main` as its upstream ("set up
to track 'origin/main'"). A bare `git push` from the task worktree would then target `main`.
Use `git branch --no-track "<branch>" origin/main` (and let the first push set the upstream to the
same-named remote branch).

## Issue Triage Context

**Mode:** Auto
**Technologies:** GitHub REST API, GitHub CLI, git, jq, curl
**Platforms/Environments:** GitHub
**Features/Integrations:** GitHub issue search, search rate limiting, git worktrees, release tagging
**Versions/Constraints:** GitHub search limit 10 requests/min unauthenticated, 30/min authenticated

## Design Decisions

TBD — to be confirmed during assessment (token source and precedence; pacing vs. auth only;
whether Task mode analyzes the merge result or adds a second range).

## Implementation Steps

1. `skills/smaqit.utils.triage-issues/SKILL.md` Step 6: document the helper's exact JSON shape
   (`incomplete_results`, `items[]` with `number`, `title`, `labels`, `html_url`, `state`,
   `created_at`, `closed_at`); mirror it in the helper's usage/help text.
2. `skills/smaqit.utils.triage-issues/scripts/github-issues.sh`: send `Authorization: Bearer` when
   a token is available; detect rate-limit responses and exit with a clear diagnostic the skill
   records as a search warning; optional pacing between searches.
3. `skills/smaqit.release-analysis/SKILL.md` Step 2 (Task mode): include `origin/main` merges since
   the boundary not reachable from the task branch; extend the completeness check.
4. `skills/smaqit.task-start/SKILL.md` Step 3: `git branch --no-track`.
5. Regenerate the installer copies (`installer/skills-claude/…`) as this repository's build does;
   add or update tests under `tests/` for the helper (output shape, rate-limit warning).
6. Release; consumers pick it up through their normal smaqit upgrade.

## Known Issues Triage

[Populated by smaqit.task-start via smaqit.utils.triage-issues. Do not edit manually.]

## Acceptance Criteria

- [ ] `smaqit.utils.triage-issues` documents the helper's exact output shape, and a consumer reading `items` gets the results
- [ ] The helper authenticates when a token is available, and a rate-limited request is reported as a search warning, never as an empty result; covered by a test
- [ ] `smaqit.release-analysis` Task mode includes `origin/main` merges since the boundary that are not on the task branch, and its completeness check names them
- [ ] `smaqit.task-start` creates the task branch without tracking `origin/main`
- [ ] Installer copies regenerated and released

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
| `skills/smaqit.utils.triage-issues/SKILL.md` | Modify |
| `skills/smaqit.utils.triage-issues/scripts/github-issues.sh` | Modify |
| `skills/smaqit.release-analysis/SKILL.md` | Modify |
| `skills/smaqit.task-start/SKILL.md` | Modify |
| `installer/skills-claude/{smaqit.utils.triage-issues,smaqit.release-analysis,smaqit.task-start}` | Regenerate |
| `tests/…` (triage helper) | Create / Modify |

## Notes

- Evidence from the consumer: two task triage records corrected after a re-run with the right key
  returned NetBird issues #5726/#5757/#5579 and cert-manager #5917; the first unpaced re-run hit the
  search rate limit on its second half.
- The installed `~/.claude/skills/smaqit.utils.triage-issues` was byte-identical to this source on
  2026-10-16.
