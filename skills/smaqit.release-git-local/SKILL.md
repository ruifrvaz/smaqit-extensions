---
name: smaqit.release-git-local
description: Execute git operations (commit, tag, push) for local releases
metadata:
  version: "0.2.0"
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

### Step 1: Check for Uncommitted Work

Check if there are uncommitted changes beyond release preparation files:

```bash
git status --porcelain
```

**If working tree has changes:**
1. Analyze changes and group by logical purpose
2. Commit each group separately (see Step 1a)
3. Then continue with release commit (Step 2)

**If only CHANGELOG.md and version files changed:**
- Skip to Step 2 directly

### Step 1a: Commit Unreleased Work (If Needed)

**CRITICAL:** Group changes by purpose, not by file type. Each commit should represent one logical change.

**Analyze all changed files:**
```bash
git --no-pager diff --name-status
git status --short
```

**Common grouping patterns:**

**Pattern 1: Feature + Documentation**
```bash
# New feature with related docs
git add src/new_feature.js docs/api.md
git commit -m "Add new feature X"
```

**Pattern 2: Bug Fix**
```bash
# Bug fix with tests
git add src/buggy_module.js tests/buggy_module.test.js
git commit -m "Fix issue with Y"
```

**Pattern 3: Refactoring/Reorganization**
```bash
# Moved files or restructured
git add -u old_location/  # stages deletions
git add new_location/
git commit -m "Refactor: move Z to new location"
```

**Pattern 4: Build/Infrastructure**
```bash
# Build, CI/CD, or tooling changes
git add .github/workflows/ Makefile
git commit -m "Update build workflow"
```

**Guidelines for grouping:**
- Each commit should be independently understandable
- Related changes belong together (implementation + tests + docs)
- Separate different logical changes into different commits
- Use descriptive commit messages explaining "why", not just "what"
- Prefix with type if helpful: `feat:`, `fix:`, `refactor:`, `docs:`, `chore:`

**Example workflow with multiple commit groups:**
```bash
# Group 1: Infrastructure changes
git add Makefile .github/workflows/
git commit -m "chore: update sync workflow for new structure"

# Group 2: Feature implementation
git add skills/ installer/Makefile
git add -u session-*/ task-*/ test-*/ release-*/  # stages deletions
git commit -m "refactor: consolidate skills into skills/ directory"

# Group 3: Bug fix
git add .github/workflows/post-merge-release.yml
git add -u .github/workflows/post-merge-tag.yml .github/workflows/release.yml
git add agents/smaqit.release.pr.agent.md .github/agents/ README.md
git commit -m "fix: merge workflows to resolve GITHUB_TOKEN trigger issue"

# Group 4: Documentation/support
git add .smaqit/
git commit -m "feat: add task tracking system"

# Now ready for Step 2 (release commit)
```

**After committing work, verify clean state:**
```bash
git status --porcelain  # Should be empty or only show CHANGELOG/version files
```

### Step 2: Stage Release Preparation Files

Stage ONLY the release preparation changes:

```bash
git add CHANGELOG.md
```

If version files were updated:
```bash
git add package.json pyproject.toml installer/main.go
```

**Verify staged changes contain ONLY release preparation:**
```bash
git --no-pager diff --cached --name-status
```

Expected output should be minimal (2-3 files max).

### Step 3: Commit Release Preparation

Create commit with release message:

```bash
git commit -m "Release vX.Y.Z"
```

**Verify commit was created:**
```bash
git --no-pager log -1 --oneline
```

### Step 4: Create Annotated Tag

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

### Step 5: Push Commits to Remote

Push the commit to the remote repository:

```bash
git push origin main
```

**Replace `main` with current branch if different.**

### Step 6: Push Tag to Remote

Push the tag to trigger release workflows:

```bash
git push origin vX.Y.Z
```

**Important:** Tag push must be separate from commit push for most CI/CD systems to detect release events.

### Step 7: Verify Success

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
- **Commits should be grouped logically, not dumped together** - each commit tells a story
- Release preparation (CHANGELOG + version) should be its own separate commit
- Both commit and tag must be pushed for release to be complete
- Tag push typically triggers CI/CD release workflows (GitHub Actions, etc.)
- Never force push (`-f`) release commits or tags
- If any step fails, stop immediately and report the error - do not continue
- Good commit hygiene makes git history useful for understanding project evolution
