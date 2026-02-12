---
name: release-analysis
description: Collect changes, assess severity, and suggest next version for a release
metadata:
  version: "0.1.0"
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

Run `git tag --sort=-v:refname` to list existing tags in descending version order.

```bash
git tag --sort=-v:refname | head -1
```

If no tags exist, the repository is at version 0.0.0 and the suggested version will be v0.1.0.

### Step 2: Collect Changes

Collect changes from two sources:

**A. Git commit history:**
```bash
git log <last-tag>..HEAD --pretty=format:"%s"
```

If no tags exist:
```bash
git log --pretty=format:"%s"
```

**B. Session history (if exists):**
Read markdown files in `.smaqit/history/` directory. These contain documented session work with completed tasks and decisions.

### Step 3: Assess Change Severity

Analyze the collected changes to determine severity level:

**MAJOR (X.0.0)** - Breaking changes:
- Removed features or commands
- Changed behavior that breaks existing usage
- Incompatible API changes
- **Keywords to look for:** "Breaking", "Removed", "Incompatible"

**MINOR (0.X.0)** - New features, non-breaking changes:
- Added features, commands, or capabilities
- New functionality
- Deprecated features (warning, not removal)
- **Keywords to look for:** "Added", "New", "Deprecated"

**PATCH (0.0.X)** - Bug fixes only:
- Fixed bugs or issues
- Documentation updates
- Internal refactoring with no user-facing changes
- **Keywords to look for:** "Fixed", "Corrected", "Bug"

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
- `changes`: List of changes with type, description, and optional reference
- `severity`: MAJOR, MINOR, or PATCH
- `latest_tag`: Most recent git tag (or "none" if no tags exist)
- `suggested_version`: Next version following semver rules
- `rationale`: Brief explanation of the severity assessment

## Notes

- This skill only **analyzes and suggests** - it does not modify any files
- The suggested version is a recommendation that must be approved before use
- Session history files (`.smaqit/history/`) are optional - if they don't exist, rely solely on git log
- Focus on user-facing changes; internal implementation details should not drive severity
- When in doubt between severities, prefer conservative (e.g., MINOR over MAJOR)
