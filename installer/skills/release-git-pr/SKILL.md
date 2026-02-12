---
name: release-git-pr
description: Execute git operations for PR-based releases (commit, push via report_progress)
metadata:
  version: "0.1.0"
---

# Release Git PR

Execute git operations required for PR-based releases: stage changes, commit to PR branch, and push via report_progress tool.

## When to use this skill

Use this skill for **PR-based releases** (running in CI/CD or agent workflow) after all files have been prepared. This skill:
- Commits release preparation changes to PR branch
- Pushes changes using `report_progress` tool (handles credentials internally)
- Documents post-merge tag creation instructions

**Do NOT use this skill for local releases** - use `release-git-local` instead.

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

### Step 2: Commit to PR Branch

Create commit with release preparation message:

```bash
git commit -m "Prepare release vX.Y.Z"
```

**Use "Prepare release" not "Release"** because the actual release happens after PR merge to main.

**Verify commit was created:**
```bash
git --no-pager log -1 --oneline
```

### Step 3: Push via report_progress

Use the `report_progress` tool to push changes to the PR branch:

**This tool:**
- Handles git credentials internally (no manual credential configuration needed)
- Automatically runs `git push`
- Updates the PR description with progress

**Do NOT:**
- Use `git push` directly (credentials not available in agent environment)
- Create git tags at this stage (tags must be created after merge to main)

### Step 4: Document Post-Merge Instructions

**CRITICAL:** Tags cannot be created on PR branches. After the PR is merged to `main`, someone must create and push the tag manually.

Provide clear post-merge instructions:

```markdown
## Post-Merge Actions Required

After this PR is merged to `main`, create the release tag:

### Commands to run:

```bash
git checkout main
git pull origin main
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin vX.Y.Z
```

### Why these steps are needed:

1. Git tags should point to commits on `main`, not PR branches
2. The tag push will trigger release workflows (GitHub Actions, etc.)
3. This ensures the release reflects the exact state merged to main

### Verification:

After pushing the tag, verify it appears in:
- GitHub releases page: `https://github.com/owner/repo/releases`
- Git remote tags: `git ls-remote --tags origin vX.Y.Z`
```

Include these instructions in the PR description or as a comment.

## Output

Provide a summary of PR operations:

```yaml
success: true
commit_sha: abc123def456
pr_updated: true
pr_branch: feature/release-v0.3.0
post_merge_instructions: |
  git checkout main
  git pull origin main
  git tag -a vX.Y.Z -m "Release vX.Y.Z"
  git push origin vX.Y.Z
```

**Output fields:**
- `success`: Boolean indicating all operations completed
- `commit_sha`: SHA of the release preparation commit
- `pr_updated`: Boolean indicating PR was updated successfully
- `pr_branch`: The feature branch containing release changes
- `post_merge_instructions`: Commands to run after merge

## Error Handling

| Error | Likely Cause | Suggested Action |
|-------|--------------|------------------|
| `nothing to commit` | Files unchanged or not staged | Verify changes were made and staged correctly |
| `report_progress` fails | PR update failed | Check PR status and retry |
| Already on main branch | Wrong workflow used | Use `release-git-local` skill for local releases |

## Critical Differences from release-git-local

| Aspect | release-git-local | release-git-pr |
|--------|-------------------|----------------|
| **Branch** | main | Feature/PR branch |
| **Commit message** | "Release vX.Y.Z" | "Prepare release vX.Y.Z" |
| **Tag creation** | ✅ Yes, immediately | ❌ No, after merge to main |
| **Push method** | `git push` directly | `report_progress` tool |
| **Git credentials** | User's local credentials | Handled by report_progress |
| **When to use** | Developer's local machine | CI/CD or agent workflow |

## Notes

- This skill is for **PR-based release workflows only**
- Tags are intentionally NOT created on PR branches
- Tag creation is deferred until after PR merge to main
- `report_progress` tool handles authentication - no need for credential setup
- Post-merge instructions must be clearly communicated to prevent missed tag creation
- The release is not complete until the tag is pushed to main after merge
- Consider adding a GitHub Actions workflow to automate post-merge tag creation
