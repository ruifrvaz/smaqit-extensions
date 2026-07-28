---
name: smaqit.release-approval
description: Obtain approval for suggested version (auto-confirm or interactive)
metadata:
  version: "0.2.0"
---

# Release Approval

Obtain approval for a suggested release version using either auto-confirm mode (for autonomous workflows) or interactive user confirmation.

## When to use this skill

Use this skill after analyzing changes and suggesting a version to:
- Check if the release has pre-approval via auto-confirm patterns
- Present the suggested version to the user for approval
- Validate the approved version format

## How to execute

### Step 1: Check for Auto-Confirm Patterns

Check the issue or task description for auto-confirm patterns:

**Pattern 1: Explicit pre-approved version**
```
**Approved version:** vX.Y.Z
```

**Pattern 2: Auto-confirm flag**
```
**Auto-confirm:** true
```

**Pattern 3: Version in issue/task title**
- Issue title contains version (e.g., "Release v0.3.0")
- Extract version from title using pattern `v\d+\.\d+\.\d+`

### Step 2: Determine Approval Mode

**If auto-confirm detected:**
1. Extract the pre-approved version
2. Log: "Auto-confirm mode: using pre-approved version vX.Y.Z"
3. Proceed directly to Step 4 (validation)

**Otherwise (interactive mode):**
1. Present the suggested version and changelog draft to user
2. Request explicit approval or allow version override
3. Example prompt:
   ```
   Latest tag: v0.5.0
   Change severity: MINOR
   Suggested version: v0.6.0
   
   Proceed with v0.6.0? (y/n or specify alternative version)
   ```

### Step 3: Handle User Response (Interactive Mode Only)

**If user approves (y/yes):**
- Use suggested version

**If user provides alternative version:**
- Use user-specified version
- Log: "Using user-specified version: vX.Y.Z"

**If user rejects (n/no):**
- Stop the release workflow
- Report: "Release cancelled by user"

### Step 4: Validate Approved Version

Regardless of approval mode, validate the version format:

**Valid formats:**
- `vX.Y.Z` (e.g., v1.2.3)
- `vX.Y.Z-suffix` (e.g., v1.2.3-beta, v0.5.0-rc.1)

**Invalid formats:**
- Missing 'v' prefix
- Non-numeric components (except suffix after hyphen)
- Missing components (e.g., v1.2)

**Validation rules:**
- Version must match regex: `^v\d+\.\d+\.\d+(-[a-zA-Z0-9.]+)?$`
- Version should follow semantic versioning (semver.org)

## Output

Provide the approved version and mode:

```yaml
approved_version: v0.3.0
mode: auto-confirm
source: issue_title
```

OR

```yaml
approved_version: v0.6.0
mode: interactive
source: user_approval
```

**Output fields:**
- `approved_version`: The version to use for the release (with 'v' prefix)
- `mode`: Either "auto-confirm" or "interactive"
- `source`: Where approval came from (issue_title, issue_body, user_approval, etc.)

## Error Handling

| Error | Action |
|-------|--------|
| Invalid version format | Stop and report: "Version must follow semver format: vX.Y.Z or vX.Y.Z-suffix" |
| User rejects in interactive mode | Stop and report: "Release cancelled by user" |
| Auto-confirm pattern found but version is invalid | Stop and report: "Pre-approved version is invalid: [version]" |
| Multiple conflicting auto-confirm patterns | Use the most explicit one (Approved version > issue title) |

## Notes

- Auto-confirm mode is designed for autonomous CI/CD workflows
- Interactive mode is for manual releases where user oversees the process
- The approved version may differ from the suggested version
- Validation happens regardless of approval mode
- This skill does not modify any files - it only determines and validates the version
