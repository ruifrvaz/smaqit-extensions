---
name: release-git-local
description: Execute git operations (commit, tag, push) for local releases
metadata:
  version: "0.1.0"
---

# Release Git Local

Execute all git operations required for a local release: stage changes, commit, create annotated tag, and push to remote.

## When to use this skill

Use this skill for **local releases** (running on a developer's machine) after all files have been prepared. This skill:
- Commits release changes to main branch
- Creates annotated git tag
- Pushes commit and tag to remote repository

**Do NOT use this skill for PR-based releases** - use `release-git-pr` instead.

## How to execute

### Step 1: Stage Changes

Stage CHANGELOG.md and any confirmed version files:

```bash
git add CHANGELOG.md
```

If version files were updated:
```bash
git add package.json pyproject.toml
```

**Verify staged changes:**
```bash
git --no-pager diff --cached --name-only
```

### Step 2: Commit Changes

Create commit with release message:

```bash
git commit -m "Release vX.Y.Z"
```

**Verify commit was created:**
```bash
git --no-pager log -1 --oneline
```

### Step 3: Create Annotated Tag

Create an annotated tag (not lightweight):

```bash
git tag -a vX.Y.Z -m "Release vX.Y.Z"
```

**Why annotated tags?**
- Contain metadata (tagger, date, message)
- Recommended for releases by git best practices
- Required by many CI/CD systems for release triggers

**Verify tag was created:**
```bash
git --no-pager tag -l vX.Y.Z
```

### Step 4: Push Commit to Remote

Push the commit to the remote repository:

```bash
git push origin main
```

**Replace `main` with current branch if different.**

### Step 5: Push Tag to Remote

Push the tag to trigger release workflows:

```bash
git push origin vX.Y.Z
```

**Important:** Tag push must be separate from commit push for most CI/CD systems to detect release events.

### Step 6: Verify Success

Confirm both commit and tag are on remote:

```bash
git ls-remote --tags origin vX.Y.Z
git ls-remote origin main
```

## Output

Provide a summary of git operations:

```yaml
success: true
commit_sha: abc123def456
tag: vX.Y.Z
branch: main
remote_url: https://github.com/owner/repo.git
```

**Output fields:**
- `success`: Boolean indicating all operations completed
- `commit_sha`: SHA of the release commit
- `tag`: The git tag created and pushed
- `branch`: Branch that was pushed to
- `remote_url`: Remote repository URL

## Error Handling

| Error | Likely Cause | Suggested Action |
|-------|--------------|------------------|
| `nothing to commit` | Files unchanged or not staged | Verify changes were made and staged correctly |
| `tag 'vX.Y.Z' already exists` | Tag created in previous attempt | Delete local tag: `git tag -d vX.Y.Z`, then retry |
| `rejected - non-fast-forward` | Remote has commits not in local | Pull latest: `git pull origin main`, then retry |
| `Permission denied (publickey)` | SSH key not configured | Configure git credentials or use HTTPS |
| `remote: Permission to repo denied` | No push access to repository | Verify repository permissions |
| `fatal: tag 'vX.Y.Z' already exists` on remote | Tag already pushed previously | Version conflict - check CHANGELOG.md |

**Recovery steps:**

**If commit succeeded but tag creation failed:**
```bash
# Fix the issue, then resume from Step 3
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin vX.Y.Z
```

**If commit and tag succeeded but push failed:**
```bash
# Fix the issue, then resume from Step 4
git pull origin main  # if non-fast-forward
git push origin main
git push origin vX.Y.Z
```

**If tag already exists locally:**
```bash
git tag -d vX.Y.Z  # Delete local tag
# Then retry from Step 3
```

## Notes

- This skill is for **local development releases only**
- For PR-based workflows, use `release-git-pr` skill instead
- All operations happen on the local machine with standard git credentials
- Both commit and tag must be pushed for release to be complete
- Tag push typically triggers CI/CD release workflows (GitHub Actions, etc.)
- Never force push (`-f`) release commits or tags
- If any step fails, stop immediately and report the error - do not continue
