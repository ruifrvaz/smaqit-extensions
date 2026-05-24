# Project Init Scaffolding Release

**Date:** 2026-05-24
**Session focus:** Release v1.1.4 — smaqit.project-init directory scaffolding step
**Tasks completed:** None
**Tasks referenced:** None

---

## Actions Taken

- Identified that `.github/skills/smaqit.project-init/SKILL.md` had been edited directly (violating the repo rule that `.github/` must only be modified via `make sync`)
- Propagated changes from the edited `.github/` copy to the canonical source `skills/smaqit.project-init/SKILL.md`
- Bumped `smaqit.project-init` version `0.2.0 → 0.3.0`
- Ran `make sync` to bring source and synced copies into alignment
- Performed release analysis: change classified as MINOR (new non-breaking step added)
- Initial version suggestion was `v0.11.0` — user overrode to `v0.10.1` (local branch was unaware of remote state)
- Pull-rebase revealed remote had advanced to `v1.1.3` (382 objects fetched); CHANGELOG conflict resolved — remote content preserved, `[0.10.1]` entry inserted
- After push, user identified the versioning error: remote was at `v1.1.3` so release should have been `v1.1.4`
- Deleted incorrect `v0.10.1` tag (local + remote), corrected CHANGELOG entry from `[0.10.1]` to `[1.1.4]`, fixed comparison links, amended commit message, created `v1.1.4` annotated tag, force-pushed with `--force-with-lease`
- Final state: commit `be92fb9`, tag `v1.1.4` live on remote

## Problems Solved

- **Direct `.github/` edit:** Changes were made to the synced copy instead of the source. Fixed by back-propagating the diff to the source and re-running `make sync`.
- **Stale local branch:** Local was 382 objects behind remote (v0.10.0 locally vs v1.1.3 on remote). The release workflow must fetch tags before analysis to avoid this class of error.
- **Wrong version number:** `v0.10.1` was tagged and pushed before discovering the remote was at `v1.1.3`. Corrected to `v1.1.4` by deleting the wrong tag, amending the commit, and force-pushing.
- **Duplicate `[Unreleased]` link:** First CHANGELOG conflict resolution left two `[Unreleased]:` lines. Caught and fixed before the final push.

## Decisions Made

- **Version:** `v1.1.4` (PATCH bump from `v1.1.3` — single skill update, no new features at the repo level)
- **CHANGELOG placement:** `[1.1.4]` placed immediately after `[Unreleased]`, before `[1.1.3]`, in correct chronological order

## Files Modified

| File | Change |
|------|--------|
| `skills/smaqit.project-init/SKILL.md` | Added Step 6 (directory scaffold), updated description, bumped to v0.3.0 |
| `.github/skills/smaqit.project-init/SKILL.md` | Synced via `make sync` |
| `CHANGELOG.md` | Added `[1.1.4] - 2026-05-24` entry; updated comparison links |

## Next Steps

- **Process improvement:** Release workflow should always run `git fetch --tags` before checking the latest tag to avoid stale version errors when the local branch is behind remote
- Tasks 005–011 remain Not Started — next session should begin implementation (recommended order: 011 → 005 → 008 → 006 → 009 → 010 → 007)

## Session Metrics

- **Duration:** Short (release workflow only)
- **Releases completed:** 1 (v1.1.4)
- **Tags created/deleted:** 1 created (v1.1.4), 1 deleted (v0.10.1)
- **Commits:** 1 (amended)
- **Versioning corrections:** 1 (v0.10.1 → v1.1.4)
- **Commit:** `be92fb9` on `main`
