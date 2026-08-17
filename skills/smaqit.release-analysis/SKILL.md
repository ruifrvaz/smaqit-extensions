---
name: smaqit.release-analysis
description: Collect changes, assess severity, and suggest next version for a release
metadata:
  version: "0.9.0"
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

**Every release is tagged `vX.Y.Z`**, whichever flow produced it: `release-git-local` tags directly, and `post-merge-release.yml` tags on a merged release PR. Tags are therefore the **authoritative lower boundary** for the current release delta, and the only marker that survives both release eras.

Release-marker *commits* are not. They exist in two forms — `"Release vX.Y.Z"` (local) and `"Prepare release vX.Y.Z"` (PR-based) — but since the PR-gated per-task release model shipped, that exact string only ever appears as a **PR title**. The merge commit GitHub actually writes reads `Merge pull request #NNN from owner/branch`, which no marker pattern matches. A repository that has released through both eras therefore has a marker-commit history that silently stops at its last pre-PR-gated release. The regex is retained below only as a fallback for a repository with no tags at all.

**Step 1a — Fetch and deepen so all history and tags are visible and current:**

```bash
git fetch origin main 2>/dev/null || true
git fetch --tags --force --quiet 2>/dev/null || true
git fetch --unshallow 2>/dev/null || git fetch --depth=2147483647 2>/dev/null || true
```

Fetching tags is **not optional** — it is what makes the tag-based boundary reliable in the shallow clones that originally motivated preferring commits over tags. `--force` prevents a moved tag leaving a stale local ref.

The explicit `git fetch origin main` is not optional, in either mode: without it, the boundary search below walks whatever `origin/main` your local refs happened to have cached, which can be stale by the time of a second, concurrent invocation — the exact bug that would otherwise let two sibling tasks compute the same "next" version. Always fetch immediately before searching, never rely on a fetch performed earlier in the session.

**Step 1b — Check whether the analysis tip is itself the latest release** (Batch mode only; Task mode's `<task-branch>` is never itself a released commit, skip this check):

```bash
git describe --tags --exact-match origin/main 2>/dev/null
```

A match means `origin/main`'s tip *is* the most recent release, so that tag must not also serve as the delta's lower bound — Step 1c steps back one tag.

**Step 1c — Find the boundary SHA:**

Resolve against **`origin/main`**, not local `HEAD` or the task branch — this is the fix for the staleness bug above, and applies identically in both modes:

```bash
# Most recent release tag reachable from the fetched remote tip
git describe --tags --abbrev=0 origin/main
```

- **Batch mode, the tip is itself tagged** (Step 1b matched) — take the **next-older** tag instead:
  ```bash
  git describe --tags --abbrev=0 "$(git describe --tags --abbrev=0 origin/main)^"
  ```
- **Otherwise (Batch mode with an untagged tip, or Task mode)** — use the tag from the command above.

Dereference the chosen tag to its commit and store that as `<boundary-sha>`:
```bash
git rev-list -n1 "<tag>"
```
`git rev-list -n1` resolves annotated and lightweight tags identically, so both tagging styles work unchanged.

Confirm it with:
```bash
git log -1 --oneline "<boundary-sha>"
```

**Step 1d — Determine the last-released version.**

This is a **separate lookup from Step 1c**, not a re-read of the boundary commit — the two answer different questions and can legitimately disagree:

```bash
git tag --merged origin/main --sort=-v:refname | head -1
```

Store as `<last-version>` (e.g., `v1.1.2`).

Step 1c asks *"where does this release's delta begin?"* — answered by the **topologically latest** reachable tag. Step 1d asks *"what version must the next one exceed?"* — answered by the **highest-numbered** reachable tag. Under the per-task release model, each task's PR claims its version before merging and PRs merge in review order, not version order, so tags land out of numeric sequence by design. If PR #200 claims v2.1.0 and merges first, then PR #201 claims v2.0.1 and merges second, the topologically latest tag is `v2.0.1` while the highest is `v2.1.0`. Deriving the version baseline from the boundary commit would then suggest `v2.0.2` — **below the already-released v2.1.0**. Step 1e's pending-claim check does not catch this: by then the colliding version is released and promoted, no longer a pending annotation.

**Fallback 1 (no tags — a repository that has only ever released via marker commits):**
```bash
git log origin/main --format="%H %s" | grep -iE "^[0-9a-f]+ (Prepare release|Release) v[0-9]+\.[0-9]+\.[0-9]+$"
```
Take the second entry when Batch mode's tip is itself a marker commit, the first otherwise; use its SHA as `<boundary-sha>` and parse `<last-version>` from its message with `grep -oE "v[0-9]+\.[0-9]+\.[0-9]+"`.

**Fallback 2 (neither tags nor markers — new repository):** use `v0.0.0` as baseline and suggest `v0.1.0`.

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
- `latest_version`: Highest release version reachable from `origin/main`, from Step 1d's own lookup (e.g., `v1.1.2`) — not re-read from the boundary commit, which can name a lower version when tags land out of order
- `suggested_version`: Next version following semver rules, adjusted past any pending-claimed collision in Task mode
- `rationale`: Brief explanation of the severity assessment
- `mode`: `batch` or `task` (Task mode also echoes `task_branch` and, if a collision was avoided, the claimed version(s) skipped)

**Important:** The `changes` list must be exhaustive — it represents the complete delta since the last release boundary. It is used in the next step to reconcile the `[Unreleased]` section of `CHANGELOG.md` before promoting it to the new version.

## Notes

- This skill only **analyzes and suggests** - it does not modify any files
- The suggested version is a recommendation that must be approved before use
- Session history files (`.smaqit/history/`) are optional - if they don't exist, rely on git log
- **Release tags are the canonical boundary** — every release is tagged `vX.Y.Z` regardless of which flow produced it, so tags are the only marker that spans both the batch and PR-gated eras. Marker commits (`"Release vX.Y.Z"`, `"Prepare release vX.Y.Z"`) are a fallback for tagless repositories only: under the PR-gated model that string exists solely as a PR title, and the merge commit GitHub writes (`Merge pull request #NNN from …`) matches no marker pattern
- **`<boundary-sha>` and `<last-version>` are separate lookups** (Steps 1c and 1d) — topologically latest reachable tag for the delta, highest-numbered reachable tag for the version baseline. They diverge whenever tags land out of numeric order, which the per-task release model produces by design
- **Shallow clones:** always deepen *and* `git fetch --tags --force` before resolving; the tag-based boundary depends on tags being present locally, which is precisely what the fetch guarantees
- **Always fetch `origin/main` immediately before searching, never reuse an earlier fetch in the same session** — the boundary and pending-version checks (Step 1a, 1c, 1e) must reflect the remote's current tip, not a cached local ref, so two tasks completing minutes apart never compute the same version
- Focus on user-facing changes; internal implementation details should not drive severity
- When in doubt between severities, prefer conservative (e.g., MINOR over MAJOR)
- Filter out `Initial plan` commits, exact release-marker commits, and release-PR merge commits from the delta — these are workflow noise, not changelog material
