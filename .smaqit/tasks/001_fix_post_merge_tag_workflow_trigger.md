# Fix Post-Merge Tag Workflow Trigger Issue

**Status:** Completed  
**Created:** 2026-02-13  
**Completed:** 2026-02-13

## Description

The PR-based release workflow has a critical gap that prevents full automation:

1. The `smaqit.release.pr` agent creates a PR with title "Prepare release vX.Y.Z"
2. When the PR is merged, the post-merge tag workflow (`.github/workflows/post-merge-tag.yml`) creates the git tag
3. **PROBLEM:** The post-merge tag workflow uses `GITHUB_TOKEN`, which does not trigger subsequent workflows
4. **IMPACT:** The release workflow that should be triggered by the new tag never runs, so no GitHub Release is created and no binaries are built

This breaks the promise of "fully automated releases" described in the README.

## Root Cause

GitHub Actions has a built-in limitation: events created using `GITHUB_TOKEN` do not trigger new workflow runs. This prevents infinite workflow loops but also breaks our cascading workflow pattern.

## Solution Implemented

Merged both workflows into a single unified workflow (`.github/workflows/post-merge-release.yml`) that:
1. Triggers on PR merge (when title matches release pattern)
2. Extracts version from PR title
3. Creates and pushes git tag
4. Builds binaries for all platforms (Linux, macOS, Windows on amd64/arm64)
5. Creates GitHub Release with binaries and changelog

This eliminates the need for the tag push to trigger another workflow, solving the GITHUB_TOKEN limitation.

## Acceptance Criteria

- [x] Post-merge tag creation triggers the release workflow
- [x] Release workflow creates GitHub Release with binaries
- [x] Solution works in CI/CD context (Copilot Coding Agent)
- [x] No manual intervention required after PR merge
- [x] Documentation updated to reflect changes

## Changes Made

1. **Merged workflows:** Combined `post-merge-tag.yml` and `release.yml` into `post-merge-release.yml`
2. **Removed old workflow:** Deleted standalone `release.yml`
3. **Updated README:** Releases section now reflects unified workflow
4. **Job orchestration:** Added job dependencies (prepare → tag → build → release)

## Notes

- This issue affected v0.4.0 and any future releases via the PR workflow
- The local release workflow (`smaqit.release.local`) is unaffected as it uses local git operations
- Future releases will now complete entirely within a single workflow run
