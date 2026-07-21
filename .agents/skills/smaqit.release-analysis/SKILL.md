---
name: smaqit.release-analysis
description: Collect changes, assess severity, and suggest next version for a release
metadata:
  version: "0.6.0"
---

# Release Analysis

Analyze repository changes since the last release, assess their severity, and suggest the next semantic version.

## When to use this skill

Use this skill at the start of a release workflow to:
- Collect all changes since the last release boundary commit
- Assess whether changes constitute a MAJOR, MINOR, or PATCH release
- Suggest the next semantic version based on change severity

## How to execute

### Step 1: Find the Release Boundary Commit

The release workflow always creates a commit named exactly `"Prepare release vX.Y.Z"` at every release point (hardcoded in `smaqit.release-git-pr` and `smaqit.release-git-local`). Use this commit as the **authoritative lower boundary** for the current release delta. It is more reliable than git tags (absent in shallow clones) and more precise than PR merge timestamps (which can be incorrectly ordered).

**Step 1a — Deepen the clone so all history is visible:**

```bash
git fetch --unshallow 2>/dev/null || git fetch --depth=2147483647 2>/dev/null || true
```

**Step 1b — Check whether HEAD itself is a "Prepare release" commit** (i.e., the agent is already on the release PR branch):

```bash
git log -1 --format="%s"
```

**Step 1c — Find the boundary SHA:**

```bash
# List every "Prepare release" commit in reverse-chronological order
git log --format="%H %s" | grep -iE "^[0-9a-f]+ Prepare release v[0-9]"
```

- **If HEAD is a "Prepare release" commit** — take the **second** entry from the list above (the one immediately before the current release).
- **Otherwise** — take the **first** entry.

Store the result as `<boundary-sha>`.

Confirm it with:
```bash
git log -1 --oneline "<boundary-sha>"
```

**Step 1d — Extract the last-released version** from the boundary commit message:
```bash
git log -1 --format="%s" "<boundary-sha>" | grep -oE "v[0-9]+\.[0-9]+\.[0-9]+"
```

Store as `<last-version>` (e.g., `v1.1.2`).

**Fallback (no "Prepare release" commits exist — new repository):**
```bash
git fetch --tags --quiet 2>/dev/null || true
git tag --sort=-v:refname | head -1
```
If tags are also empty, use `v0.0.0` as baseline and suggest `v0.1.0`.

### Step 2: Collect Changes Since the Boundary

Collect commits between `<boundary-sha>` and `HEAD`. This range is the authoritative delta for the current release.

**A. Merge commits (PR titles — high-level summaries):**

```bash
git log "<boundary-sha>..HEAD" --merges --pretty=format:"%h %s"
```

**B. Individual commits (feature details within PRs):**

```bash
git log "<boundary-sha>..HEAD" --no-merges --pretty=format:"%h %s"
```

**Filter out noise commits** from both lists before analysing:
- Lines matching `Initial plan` — release workflow setup commits, not changelog material
- Lines matching `Prepare release v` — release boundary markers themselves
- Lines matching `Merge pull request .*/copilot/release-` — the PR merge for the current release, not a feature

The remaining commits are the real changelog delta. Group related commits (individual commits + their merge commit) into a single changelog entry per PR.

**C. File changes analysis:**
Supplement the commit list with a diff to catch file-level context:

```bash
git diff "<boundary-sha>..HEAD" --stat --name-status
```

Extract key insights:
- New files added (especially new agents, skills, workflows)
- Modified core components (installers, configuration)
- Deleted functionality (potential breaking changes)

**D. Session history (if exists):**
Read markdown files in `.smaqit/history/` directory for additional context on completed work.

**E. `[Unreleased]` section in CHANGELOG.md:**
Read the existing `## [Unreleased]` section if present — use as a starting point but always cross-check against the commit list above, as this section is frequently incomplete.

### Step 2 Verification: Completeness check

After collecting commits, count non-noise merge commits in the range — each represents a PR that should have at least one changelog entry. If your `changes` list has fewer entries, review the commit messages and add what is missing.

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
latest_version: v0.2.0
suggested_version: v0.3.0
rationale: "New features added (release agent), no breaking changes detected"
```

**Output fields:**
- `changes`: Complete list of changes since the last release boundary, one entry per PR or meaningful commit. Use conventional changelog types: `Added`, `Changed`, `Fixed`, `Removed`, `Deprecated`, `Security`. Each entry must be a self-contained description suitable for pasting directly into `CHANGELOG.md`. Include a `reference` (PR number or commit SHA) for traceability.
- `severity`: MAJOR, MINOR, or PATCH
- `latest_version`: Version extracted from the boundary "Prepare release" commit (e.g., `v1.1.2`)
- `suggested_version`: Next version following semver rules
- `rationale`: Brief explanation of the severity assessment

**Important:** The `changes` list must be exhaustive — it represents the complete delta since the last release boundary. It is used in the next step to reconcile the `[Unreleased]` section of `CHANGELOG.md` before promoting it to the new version.

## Notes

- This skill only **analyzes and suggests** - it does not modify any files
- The suggested version is a recommendation that must be approved before use
- Session history files (`.smaqit/history/`) are optional - if they don't exist, rely on git log
- **"Prepare release" commits are the canonical boundary** — they are always created by the release skills and mark exact release points; use them in preference to git tags or PR timestamps
- **Shallow clones:** always deepen before querying git log; the boundary-commit approach still works as long as the previous "Prepare release" commit is reachable
- Focus on user-facing changes; internal implementation details should not drive severity
- When in doubt between severities, prefer conservative (e.g., MINOR over MAJOR)
- Filter out `Initial plan` commits, `Prepare release` commits, and release-PR merge commits from the delta — these are workflow noise, not changelog material
