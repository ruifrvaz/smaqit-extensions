---
name: smaqit.release-analysis
description: Collect changes, assess severity, and suggest next version for a release
metadata:
  version: "0.8.0"
---

# Release Analysis

Analyze repository changes since the last release, assess their severity, and suggest the next semantic version.

## When to use this skill

Use this skill at the start of a release workflow to:
- Collect all changes since the last release boundary commit
- Assess whether changes constitute a MAJOR, MINOR, or PATCH release
- Suggest the next semantic version based on change severity

## Modes

- **Batch mode (default)** — the traditional invocation: analyze `<boundary-sha>..HEAD` on the checked-out branch (typically `main` or a release-prep branch). Used by `release-git-local` and any manually-triggered batched release.
- **Task mode** — invoked by `smaqit.task-complete` before a task's own code has merged. Analyzes `<boundary-sha>..<task-branch>` instead of `HEAD`, and additionally applies the pending-version-awareness check in Step 1e so a concurrently-open sibling task's already-claimed version is never suggested again. The caller supplies `<task-branch>` explicitly; every other step is identical except where marked "Task mode only."

### Step 1: Find the Release Boundary Commit

The release workflows create exact release-marker commits in two compatible forms: `"Release vX.Y.Z"` for local releases and `"Prepare release vX.Y.Z"` for PR-based releases. Use the most recent marker of either form as the **authoritative lower boundary** for the current release delta. It is more reliable than git tags (absent in shallow clones) and more precise than PR merge timestamps (which can be incorrectly ordered).

**Step 1a — Fetch and deepen so all history is visible and current:**

```bash
git fetch origin main 2>/dev/null || true
git fetch --unshallow 2>/dev/null || git fetch --depth=2147483647 2>/dev/null || true
```

The explicit `git fetch origin main` is not optional, in either mode: without it, the boundary search below walks whatever `origin/main` your local refs happened to have cached, which can be stale by the time of a second, concurrent invocation — the exact bug that would otherwise let two sibling tasks compute the same "next" version. Always fetch immediately before searching, never rely on a fetch performed earlier in the session.

**Step 1b — Check whether HEAD itself is a release-marker commit** (Batch mode only; Task mode's `<task-branch>` is never itself a release-marker commit, skip this check):

```bash
git log -1 --format="%s"
```

**Step 1c — Find the boundary SHA:**

Search **`origin/main`'s history**, not local `HEAD` or the task branch — this is the fix for the staleness bug above, and applies identically in both modes:

```bash
# List every exact local or PR release marker in reverse-chronological order, from the fetched remote tip
git log origin/main --format="%H %s" | grep -iE "^[0-9a-f]+ (Prepare release|Release) v[0-9]+\.[0-9]+\.[0-9]+$"
```

- **Batch mode, HEAD is a release-marker commit** — take the **second** entry from the list above (the one immediately before the current release).
- **Otherwise (Batch mode without a marker at HEAD, or Task mode)** — take the **first** entry.

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

**Fallback (no release-marker commits exist — new repository):**
```bash
git fetch --tags --quiet 2>/dev/null || true
git tag --sort=-v:refname | head -1
```
If tags are also empty, use `v0.0.0` as baseline and suggest `v0.1.0`.

**Step 1e — Pending-version awareness (Task mode only):**

Read `## [Unreleased]` from `origin/main`'s current `CHANGELOG.md` (`git show origin/main:CHANGELOG.md`, not the local working tree, to stay consistent with the fresh fetch above) and collect every `(pending vX.Y.Z · PR #NNN)` annotation — see `smaqit.release-prepare-files`' Pending Entry Convention for the exact format. Each collected version is **already claimed** by another in-flight task's PR and must never be suggested again in Step 4, in addition to `<last-version>` itself. If the computed candidate collides with a claimed version, keep incrementing by the same severity step (e.g., PATCH: `.4`, `.5`, `.6`, ...) until landing on one that is neither tagged nor claimed.

### Step 2: Collect Changes Since the Boundary

Collect commits between `<boundary-sha>` and `HEAD` (Batch mode) or `<boundary-sha>` and `<task-branch>` (Task mode). This range is the authoritative delta for the current release.

**A. Merge commits (PR titles — high-level summaries; Batch mode typically has several, Task mode typically has none since the task branch hasn't merged anywhere yet):**

```bash
git log "<boundary-sha>..<HEAD-or-task-branch>" --merges --pretty=format:"%h %s"
```

**B. Individual commits (feature details within PRs):**

```bash
git log "<boundary-sha>..<HEAD-or-task-branch>" --no-merges --pretty=format:"%h %s"
```

**Filter out noise commits** from both lists before analysing:
- Lines matching `Initial plan` — release workflow setup commits, not changelog material
- Lines matching exact `Prepare release vX.Y.Z` or `Release vX.Y.Z` markers — release boundaries themselves
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

**Task mode only:** apply Step 1e's collision check to the candidate computed above. If it matches an already-claimed pending version, keep incrementing at the same severity step until the candidate is neither tagged nor claimed by another pending entry.

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
- `latest_version`: Version extracted from the boundary release-marker commit (e.g., `v1.1.2`)
- `suggested_version`: Next version following semver rules, adjusted past any pending-claimed collision in Task mode
- `rationale`: Brief explanation of the severity assessment
- `mode`: `batch` or `task` (Task mode also echoes `task_branch` and, if a collision was avoided, the claimed version(s) skipped)

**Important:** The `changes` list must be exhaustive — it represents the complete delta since the last release boundary. It is used in the next step to reconcile the `[Unreleased]` section of `CHANGELOG.md` before promoting it to the new version.

## Notes

- This skill only **analyzes and suggests** - it does not modify any files
- The suggested version is a recommendation that must be approved before use
- Session history files (`.smaqit/history/`) are optional - if they don't exist, rely on git log
- **Exact release-marker commits are the canonical boundary** — local releases use `"Release vX.Y.Z"` and PR-based releases use `"Prepare release vX.Y.Z"`; use the most recent marker of either form in preference to git tags or PR timestamps
- **Shallow clones:** always deepen before querying git log; the boundary-commit approach still works as long as the previous release-marker commit is reachable
- **Always fetch `origin/main` immediately before searching, never reuse an earlier fetch in the same session** — the boundary and pending-version checks (Step 1a, 1c, 1e) must reflect the remote's current tip, not a cached local ref, so two tasks completing minutes apart never compute the same version
- Focus on user-facing changes; internal implementation details should not drive severity
- When in doubt between severities, prefer conservative (e.g., MINOR over MAJOR)
- Filter out `Initial plan` commits, exact release-marker commits, and release-PR merge commits from the delta — these are workflow noise, not changelog material
