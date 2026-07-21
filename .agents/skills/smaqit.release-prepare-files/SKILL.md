---
name: smaqit.release-prepare-files
description: Validate git state and prepare all files (CHANGELOG.md, version files) for release
metadata:
  version: "0.5.0"
---

# Release Prepare Files

Validate the repository state and prepare all necessary files for a release, including CHANGELOG.md and optional version files.

## When to use this skill

Use this skill after obtaining version approval and before executing git operations to:
- Validate git working tree is clean
- Verify correct branch
- Finalize CHANGELOG.md with approved version
- Optionally sync version files (package.json, etc.)

## How to execute

### Step 1: Validate Git State

**A. Verify current branch:**
```bash
git branch --show-current
```
- **For local releases:** Should be `main` or user-specified release branch
- **For PR-based releases:** Feature branch is acceptable
- If not on main (local release): Warn and request confirmation

**B. Check version doesn't exist in CHANGELOG.md:**
```bash
grep "## \\[X.Y.Z\\]" CHANGELOG.md
```
- Replace X.Y.Z with actual version (e.g., `grep "## \\[0.3.0\\]" CHANGELOG.md`)
- If version already exists: Stop and report "Version X.Y.Z already exists in CHANGELOG.md"

**Note:** Uncommitted changes are acceptable - they will be handled during git operations step.

### Step 2: Finalize CHANGELOG.md

**A. Collect all changes since last release (reconciliation source):**

The release workflow always creates a commit named exactly `"Prepare release vX.Y.Z"`. Use this commit as the **authoritative boundary** — it is more reliable than git tags (absent in shallow clones) and more precise than PR merge timestamps (which can be incorrectly ordered).

**Step 2A-1 — Deepen the clone so the boundary commit is reachable:**
```bash
git fetch --unshallow 2>/dev/null || git fetch --depth=2147483647 2>/dev/null || true
```

**Step 2A-2 — Find the boundary SHA:**
```bash
# List all "Prepare release" commits, most recent first
git log --format="%H %s" | grep -iE "^[0-9a-f]+ Prepare release v[0-9]"
```
- **If HEAD is a "Prepare release" commit** (agent is on the release PR branch) — take the **second** entry.
- **Otherwise** — take the **first** entry.

Store as `<boundary-sha>`. Confirm:
```bash
git log -1 --oneline "<boundary-sha>"
```

**Step 2A-3 — Collect commits after the boundary:**
```bash
# PR merge commits (high-level summaries):
git log "<boundary-sha>..HEAD" --merges --pretty=format:"%h %s"

# Individual commits (feature details):
git log "<boundary-sha>..HEAD" --no-merges --pretty=format:"%h %s"
```

**Filter out noise commits** from both lists before analysing:
- Lines matching `Initial plan` — release workflow setup commits
- Lines matching `Prepare release v` — release boundary markers themselves
- Lines matching `Merge pull request .*/copilot/release-` — release PR merges

The remaining commits are the real changelog delta.

**Fallback (no "Prepare release" commits found):** use git tags:
```bash
git fetch --tags --quiet 2>/dev/null || true
git tag --sort=-v:refname | head -1
# Then: git log <last-tag>..HEAD --merges/--no-merges
```

**B. Reconcile `[Unreleased]` section with collected changes:**

Build the authoritative list of changes using the commit delta from Step 2A and the `smaqit.release-analysis` `changes` list. The `[Unreleased]` section is a starting point only — treat it as incomplete.

For each non-noise commit found in the git log range:
1. Check if it is already described in `[Unreleased]`
2. If **not represented**, add an entry under the appropriate category (`Added`, `Changed`, `Fixed`, `Removed`, `Deprecated`, `Security`)

**Minimum completeness check before moving on:**
- Count non-noise merge commits in the range (each is a PR that shipped): call this N
- Your CHANGELOG section for this version must have **at least N entries**
- If your count is lower, look at each merge commit title and add the missing descriptions

The result should document every meaningful change — not just the version number bump.

**C. Move reconciled `[Unreleased]` content to new version section:**

Find the `## [Unreleased]` section and move its content to a new version section with current date (YYYY-MM-DD):

```markdown
## [Unreleased]

(empty or minimal content)

## [X.Y.Z] - YYYY-MM-DD
### Added
- Feature X

### Fixed
- Bug Y
```

**D. Update comparison links at bottom of CHANGELOG.md:**

Update the link structure:
```markdown
[Unreleased]: https://github.com/owner/repo/compare/vX.Y.Z...HEAD
[X.Y.Z]: https://github.com/owner/repo/releases/tag/vX.Y.Z
[Previous]: https://github.com/owner/repo/releases/tag/vPrevious
```

**E. If creating CHANGELOG.md from scratch:**

Use Keep a Changelog format:
```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [X.Y.Z] - YYYY-MM-DD
### Added
- Initial release

[Unreleased]: https://github.com/owner/repo/compare/vX.Y.Z...HEAD
[X.Y.Z]: https://github.com/owner/repo/releases/tag/vX.Y.Z
```

### Step 3: Optionally Sync Version Files

**A. Ask user for version files:**

Common version files by ecosystem:
- JavaScript/Node.js: `package.json`
- Python: `pyproject.toml`, `setup.py`, `__init__.py`
- Rust: `Cargo.toml`
- Go: Version constant in main package
- Ruby: Gemspec or version.rb

**B. If repository has obvious version file:**
- Propose it and ask for confirmation
- Example: "I found package.json with version field. Update it to X.Y.Z?"

**C. If user confirms version files:**
1. Update version strings in each file
2. **Important:** Remove 'v' prefix for version files (use `X.Y.Z`, not `vX.Y.Z`)
3. Verify consistency across all files

**Example updates:**

`package.json`:
```json
{
  "version": "0.3.0"
}
```

`pyproject.toml`:
```toml
[project]
version = "0.3.0"
```

**D. If user declines or no version files exist:**
- Skip this step
- Only CHANGELOG.md will be modified

### Step 4: Verify All Changes

Before completing:
1. Confirm CHANGELOG.md has new version section
2. Confirm CHANGELOG.md comparison links are updated
3. Confirm version files (if any) have consistent versions
4. List all files that will be committed

## Output

Provide a summary of files prepared:

```yaml
files_modified:
  - CHANGELOG.md
  - package.json
validation_passed: true
version_synced: true
```

**Output fields:**
- `files_modified`: List of files changed during preparation
- `validation_passed`: Boolean indicating all validations passed
- `version_synced`: Boolean indicating if version files were updated

## Error Handling

| Error | Suggested Action |
|-------|------------------|
| Version already exists in CHANGELOG.md | Stop and report: "Version X.Y.Z already exists" |
| Not on main branch (local release) | Warn and request confirmation before proceeding |
| Version file has different format | Ask user how to update it (may need custom logic) |
| CHANGELOG.md doesn't exist | Create from scratch using Keep a Changelog template |

## Notes

- This skill modifies files but does NOT commit them (git operations are separate)
- All file modifications are reversible with `git checkout`
- Version files are optional - CHANGELOG.md is the only required file
- Keep a Changelog format uses version WITHOUT 'v' prefix in headers (e.g., `## [0.3.0]`), but git tags use 'v' prefix (e.g., `v0.3.0`)
- For PR-based releases, validation rules are slightly relaxed (feature branch OK)
- **"Prepare release" commits are the canonical boundary** — always deepen the clone first; locate the previous "Prepare release" commit and use its SHA as the lower bound for `git log`
- **Reconciliation is mandatory:** always cross-check `[Unreleased]` against the commit delta before promoting; the `[Unreleased]` section is often incomplete or empty
- Uncommitted changes in working tree are acceptable - `release-git-local` handles commit grouping