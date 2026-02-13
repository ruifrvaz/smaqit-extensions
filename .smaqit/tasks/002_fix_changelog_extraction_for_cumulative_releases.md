# Fix Changelog Extraction for Cumulative Releases

**Status:** Not Started  
**Created:** 2026-02-13

## Description

The release workflow extracts changelog notes for GitHub Releases, but only includes the single version section. When multiple versions are released without creating GitHub Releases (e.g., v0.4.0, v0.4.1, v0.4.2 fixing the workflow itself), the final release should include cumulative changes since the last **successful** release.

**Current behavior:**
- v0.4.2 release notes only show v0.4.2 changes
- Missing v0.4.0 and v0.4.1 changes that users need to see

**Expected behavior:**
- Detect last release tag with published GitHub Release
- Extract all changelog sections between last published release and current version
- Include cumulative changes in release notes

**Example:**
- Last published release: v0.3.0
- Current release: v0.4.2
- Should include: v0.4.2 + v0.4.1 + v0.4.0 sections

## Root Cause

Workflow extracts changelog using:
```bash
awk "/## \[${VERSION}\]/{flag=1;next}/## \[/{flag=0}flag" CHANGELOG.md
```

This only captures the current version section, not cumulative changes since last published release.

## Acceptance Criteria

- [ ] Workflow detects last release tag with published GitHub Release (via GitHub API)
- [ ] Extracts all changelog sections from current version back to last published
- [ ] Release notes include cumulative changes for all unpublished versions
- [ ] Works correctly when current version is first release after published release
- [ ] Handles case where no previous release exists

## Potential Solutions

**Option A: GitHub API Query**
- Query GitHub Releases API for latest published release
- Extract all versions between that and current
- Combine changelog sections

**Option B: Git Tags + Release Metadata**
- Check git tags for releases
- Use release workflow run history to detect which succeeded
- Extract cumulative changelog

**Option C: CHANGELOG.md Marker**
- Add comment marker in CHANGELOG for "last published"
- Update marker when release completes successfully
- Extract everything after marker

**Recommended: Option A** (most reliable, uses source of truth)

## Implementation Notes

Workflow location: `.github/workflows/post-merge-release.yml`

Current step:
```yaml
- name: Extract changelog for this version
  id: changelog
  run: |
    VERSION="${{ needs.prepare.outputs.version }}"
    awk "/## \[${VERSION}\]/{flag=1;next}/## \[/{flag=0}flag" CHANGELOG.md > release_notes.md
```

Needs enhancement to:
1. Query GitHub API for latest published release
2. Parse CHANGELOG.md for all versions since that release
3. Combine sections into release_notes.md

## Edge Cases

- First release ever (no previous published release)
- Current version already has published release (workflow retry)
- Multiple sequential failed releases
- Changelog format changes between versions

## Related

- Task 001: Fixed workflow trigger (enabled releases to work)
- This resolves the consequence of having 3 releases before workflow was fixed
