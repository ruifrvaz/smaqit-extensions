---
name: smaqit.release-git-pr
description: Execute git operations for PR-based releases (commit, push, and enforce the post-merge automation PR title)
metadata:
  version: "0.3.1"
---

# Release Git PR

Execute git operations required for PR-based releases: stage changes, commit to PR branch, and push via `report_progress` tool (handles credentials internally).

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

### Step 4: Verify and Enforce PR Title for Post-Merge Automation

**CRITICAL:** This step is not optional. A wrong PR title causes the post-merge release workflow to skip all jobs silently.

Check the current PR title:
```bash
gh pr view --json title -q .title
```

The PR title **MUST** match one of these patterns:
- `Prepare release vX.Y.Z`
- `Release vX.Y.Z`

If the title does NOT match, **update it immediately**:
```bash
gh pr edit --title "Prepare release vX.Y.Z"
```

**Common failure patterns to watch for:**
- "Prepare release metadata for v1.0.4" ❌ (extra words before version)
- "fix: release prep v1.0.4" ❌ (wrong format)
- "chore: prepare v1.0.4 release" ❌ (wrong format)
- "Prepare release v1.0.4" ✅
- "Release v1.0.4" ✅

**Post-merge workflow automatically:**
1. Creates and pushes git tag `vX.Y.Z`
2. Creates a GitHub Release with the changelog excerpt as its notes

**No manual intervention required for the tag/release steps.** `.github/workflows/post-merge-release.yml` is installed by `smaqit-extensions install --scope project` / `update` (create-if-absent) with no build step; if this project has added its own build or artifact-upload steps to that workflow, they run too — check the file directly rather than assuming its contents.

Document in PR description:

```markdown
## Post-Merge Automation

When this PR is merged to `main`, the post-merge workflow will automatically:

✅ Create git tag `vX.Y.Z`
✅ Publish GitHub Release with the changelog excerpt

Workflow: `.github/workflows/post-merge-release.yml`
```

## Output

Provide a summary of PR operations:

```yaml
success: true
commit_sha: abc123def456
pr_updated: true
pr_branch: feature/release-v0.3.0
pr_title: "Prepare release vX.Y.Z"
post_merge_automation: true
```

**Output fields:**
- `success`: Boolean indicating all operations completed
- `commit_sha`: SHA of the release preparation commit
- `pr_updated`: Boolean indicating PR was updated successfully
- `pr_branch`: The feature branch containing release changes
- `pr_title`: The PR title that triggers post-merge automation
- `post_merge_automation`: Boolean indicating workflow will handle release

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
| **Push method** | `git push` directly | `report_progress` tool (handles credentials internally) |
| **Git credentials** | User's local credentials | Handled by report_progress |
| **When to use** | Developer's local machine | CI/CD or agent workflow |

## Notes

- This skill is for **PR-based release workflows only**
- Tags are intentionally NOT created on PR branches
- Complete release automation happens via post-merge workflow after PR merge
- Push authentication is handled by `report_progress` tool (handles credentials internally)
- PR title must match pattern for post-merge automation to trigger
- Release completes automatically after PR merge: tag + GitHub Release (plus any project-added build steps)
- See `.github/workflows/post-merge-release.yml` for workflow details
