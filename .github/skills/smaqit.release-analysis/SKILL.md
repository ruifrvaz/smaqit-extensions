---
name: smaqit.release-analysis
description: Collect changes, assess severity, and suggest next version for a release
metadata:
  version: "0.5.0"
---

# Release Analysis

Analyze repository changes since the last release, assess their severity, and suggest the next semantic version.

## When to use this skill

Use this skill at the start of a release workflow to:
- Collect all changes since the last git tag
- Assess whether changes constitute a MAJOR, MINOR, or PATCH release
- Suggest the next semantic version based on change severity

## How to execute

### Step 1: Find Latest Git Tag

**IMPORTANT:** Agent environments are often shallow/grafted clones with no local tags. Always fetch tags first.

```bash
# Step 1a: Fetch tags (recovers tags in shallow/grafted clones)
git fetch --tags --quiet 2>/dev/null || true

# Step 1b: Try to find the latest tag locally
git tag --sort=-v:refname | head -1
```

**If `git tag` returns empty** (shallow clone with no tag history), use the GitHub CLI as fallback:

```bash
# GitHub CLI fallback — get the latest release tag
gh release list --limit 1 --json tagName -q '.[0].tagName'
```

Store the result as `<last-tag>` (e.g., `v1.0.1`).

If no tags exist anywhere (new repository), use `v0.0.0` as the baseline and suggest `v0.1.0`.

### Step 2: Collect Changes

**IMPORTANT:** Collect changes from ALL available sources and cross-check them. In shallow/grafted clones, git log may be truncated — always use the GitHub CLI as a supplementary source.

Collect changes from four sources:

**A. Git commit history (primary source):**

Run two queries to capture the full picture:

```bash
# PR merge commits — high-level summaries (what shipped):
git log <last-tag>..HEAD --merges --pretty=format:"%h %s"

# Individual commits — details within each PR:
git log <last-tag>..HEAD --no-merges --pretty=format:"%h %s"
```

**If the git log output is empty or suspiciously short** (e.g., fewer commits than expected given the time since the last release), the clone is likely shallow. In that case:

```bash
# Try to deepen the clone
git fetch --unshallow 2>/dev/null || git fetch --depth=2147483647 2>/dev/null || true

# Re-run the git log queries
git log <last-tag>..HEAD --merges --pretty=format:"%h %s"
git log <last-tag>..HEAD --no-merges --pretty=format:"%h %s"
```

**B. GitHub CLI — merged PRs (mandatory fallback and cross-check):**

Even if git log returns results, always cross-check with `gh pr list` to catch any PRs that git log may have missed:

```bash
# Get all merged PRs since the last release tag
# Use the date of <last-tag> release as the lower bound
gh release view <last-tag> --json publishedAt -q '.publishedAt'

# Then list merged PRs after that date
gh pr list --state merged --base main --limit 50 \
  --json number,title,mergedAt \
  --jq 'sort_by(.mergedAt) | .[] | "#\(.number) \(.title) (merged \(.mergedAt[:10]))"'
```

This output is the **authoritative list of user-facing changes** — every line must appear in the `changes` output. Compare it against the git log results and add any missing entries.

If no `<last-tag>` exists, omit the date filter and list all merged PRs.

**C. File changes analysis:**
Analyze actual file modifications to supplement commit messages and verify coverage.

```bash
# If tags exist:
git diff <last-tag>..HEAD --stat --name-status

# If no tags exist (compare against empty tree):
git diff 4b825dc5c39fd418cd129ae01eb94d5aa75a7d7f..HEAD --stat --name-status
```

Extract key insights:
- New files added (especially features, agents, skills, workflows)
- Modified core components (installers, configuration)
- Deleted functionality (potential breaking changes)
- Number of files changed and scope of modifications

**D. Session history (if exists):**
Read markdown files in `.smaqit/history/` directory. These contain documented session work with completed tasks and decisions.

**E. `[Unreleased]` section in CHANGELOG.md:**
Read the existing `## [Unreleased]` section in `CHANGELOG.md` (if present). These are entries that were proactively maintained. Treat them as authoritative descriptions but cross-check them against the git log — the `[Unreleased]` section may be incomplete.

### Step 2 Verification: Cross-check completeness

**After collecting from all sources, verify completeness:**

1. Count the entries in `gh pr list` output → this is your **minimum expected entry count**
2. Count the entries in your `changes` list → this must be **≥** the PR count
3. If your changes list has fewer entries than merged PRs, find what's missing and add it

**Do not proceed to Step 3 if the `changes` list is missing any merged PRs.** Each PR merge must have at least one corresponding entry in `changes`.

### Step 3: Assess Change Severity

Analyze the collected changes from commit messages, file changes, and session history to determine severity level:

**MAJOR (X.0.0)** - Breaking changes:
- Removed features or commands
- Changed behavior that breaks existing usage
- Incompatible API changes
- Deleted files that were part of public API
- **Keywords to look for:** "Breaking", "Removed", "Incompatible"
- **File patterns:** Deletions of core functionality

**MINOR (0.X.0)** - New features, non-breaking changes:
- Added features, commands, or capabilities
- New functionality
- Deprecated features (warning, not removal)
- New files added (agents, skills, workflows)
- **Keywords to look for:** "Added", "New", "Deprecated"
- **File patterns:** New agents/, skills/ files

**PATCH (0.0.X)** - Bug fixes only:
- Fixed bugs or issues
- Documentation updates
- Internal refactoring with no user-facing changes
- **Keywords to look for:** "Fixed", "Corrected", "Bug"
- **File patterns:** Changes to existing files without new features

### Step 4: Suggest Next Version

Based on the assessed severity and latest tag, calculate the next semantic version:

- **MAJOR:** Increment X in vX.Y.Z (e.g., v1.2.3 → v2.0.0)
- **MINOR:** Increment Y in vX.Y.Z, reset Z to 0 (e.g., v1.2.3 → v1.3.0)
- **PATCH:** Increment Z in vX.Y.Z (e.g., v1.2.3 → v1.2.4)

**Special case:** If current version is 0.Y.Z:
- Breaking changes still increment Y, not X (0.Y.Z is pre-1.0 API)
- First stable release should be v1.0.0

## Output

Provide a structured summary in YAML format:

```yaml
changes:
  - type: Added
    description: "Release agent for automated workflow"
    reference: "#123"
  - type: Fixed
    description: "Bug in version detection"
    reference: "#124"
severity: MINOR
latest_tag: v0.2.0
suggested_version: v0.3.0
rationale: "New features added (release agent), no breaking changes detected"
```

**Output fields:**
- `changes`: Complete list of changes since the last tag, one entry per PR or meaningful commit. Use conventional changelog types: `Added`, `Changed`, `Fixed`, `Removed`, `Deprecated`, `Security`. Each entry must be a self-contained description suitable for pasting directly into `CHANGELOG.md`. Include a `reference` (PR number or commit SHA) for traceability.
- `severity`: MAJOR, MINOR, or PATCH
- `latest_tag`: Most recent git tag (or "none" if no tags exist)
- `suggested_version`: Next version following semver rules
- `rationale`: Brief explanation of the severity assessment

**Important:** The `changes` list must be exhaustive — it represents the complete delta since the last release tag. It is used in the next step to reconcile the `[Unreleased]` section of `CHANGELOG.md` before promoting it to the new version.

## Notes

- This skill only **analyzes and suggests** - it does not modify any files
- The suggested version is a recommendation that must be approved before use
- Session history files (`.smaqit/history/`) are optional - if they don't exist, rely on git log + gh CLI
- **Shallow/grafted clones are the norm in agent environments** — always run `git fetch --tags` first; always cross-check with `gh pr list` regardless
- **`gh pr list` is authoritative** — git log may be truncated, but `gh pr list --state merged --base main` always returns the complete history
- Focus on user-facing changes; internal implementation details should not drive severity
- When in doubt between severities, prefer conservative (e.g., MINOR over MAJOR)
- The empty tree SHA `4b825dc5c39fd418cd129ae01eb94d5aa75a7d7f` is a Git constant for comparing against an empty state
- **Completeness is mandatory:** every merged PR since the last release must appear in the `changes` list; the `[Unreleased]` section in CHANGELOG.md is a convenience but must not be the sole source
