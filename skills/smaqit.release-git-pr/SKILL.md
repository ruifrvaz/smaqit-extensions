---
name: smaqit.release-git-pr
description: Execute git operations for PR-based releases (commit, push, and enforce the post-merge automation PR title)
metadata:
  version: "0.6.0"
---

# Release Git PR

Execute git operations required for PR-based releases: stage changes, commit to PR branch, and push via {{PUSH_METHOD_SUMMARY}}.

## When to use this skill

Use this skill for **PR-based releases** (running in CI/CD or agent workflow) after all files have been prepared. This skill:
- Commits release preparation changes to PR branch
- Pushes changes using {{PUSH_METHOD_SUMMARY}}
- Documents post-merge tag creation instructions

**Do NOT use this skill for local releases** - use `release-git-local` instead.

## Invocation from `smaqit.task-complete`

`task-complete`'s Phase 1 uses this skill twice. It runs Step 0 (the release workflow preflight) on its own, as its Step 10a, before it pushes anything. Later it invokes this skill for **PR-title verification only** (Step 4), after it has already pushed the branch and created the PR itself (its Step 11).

In that second invocation, **skip Steps 0-3 entirely**. Step 0 already ran, before the PR existed, which is the only point where its warning can still prevent a release-less merge:
- **Steps 1-2 (stage + commit `CHANGELOG.md`)** — implementation was already committed by `task-complete`'s Step 9, and this release's changelog section is authored by `task-complete` itself: its Step 12 writes the `## [X.Y.Z]` section directly on the task branch (via `smaqit.release-prepare-files`' Task-Release Mode) and its Step 13 commits it there. Attempting Steps 1-2 here would either double-commit that work or hit the "nothing to commit" error path.
- **Step 3 (push)** — `task-complete` owns pushing the branch, both at creation (its Step 11) and again after its changelog commit (its Step 13, a plain push — the branch is never rebased or force-pushed).

Step 4's title enforcement still matters and is the entire reason for the invocation: a title that does not match `Prepare release vX.Y.Z` makes `post-merge-release.yml` silently skip every job, so the task would appear complete while never actually releasing.

## How to execute

### Step 0: Release Workflow Preflight

`.github/workflows/post-merge-release.yml` is what turns a merged `Prepare release vX.Y.Z` PR into a tag and a GitHub Release. If the file is missing, the PR merges normally and nothing else happens: no tag, no Release, no error. `smaqit-extensions init` and `update` install it (create-if-absent), but a repository that never ran either, or ran a version that predates the workflow template, doesn't have it.

Check the git object on the base branch, not the working tree:

```bash
git fetch origin main
git cat-file -e origin/main:.github/workflows/post-merge-release.yml
```

The workflow only fires for PRs merged into `main` (`pull_request: [closed]`, `branches: [main]`), so `origin/main` is the branch that has to carry it. A filesystem check would pass for a copy that exists only on disk or only in a local commit, and that copy never runs on GitHub.

- **Exit status 0:** continue to Step 1.
- **Fetch failed:** the result is unknown, not missing. Report the fetch failure and don't warn about the workflow.
- **Non-zero `cat-file`:** warn before any release-titled PR is opened or pushed:

  > `.github/workflows/post-merge-release.yml` is not on `origin/main`. Merging this release PR will publish no tag and no GitHub Release. Run `smaqit-extensions init` (or `update`) to install the workflow, get it onto `main`, then continue.

  Then:
  - **Interactive run:** ask whether to stop or continue anyway. Continuing is reasonable when the project publishes releases some other way.
  - **Run that can't prompt** (auto-confirm CI or agent run): don't stop. Put the warning at the top of the PR description, above the Post-Merge Automation block, so the reviewer sees it before merging, and report `post_merge_automation: false`.

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

{{PUSH_STEP}}

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

**No manual intervention required for the tag/release steps**, provided Step 0 found `.github/workflows/post-merge-release.yml` on `origin/main`. The installed template has no build step; if this project has added its own build or artifact-upload steps to that workflow, they run too — check the file directly rather than assuming its contents.

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
- `post_merge_automation`: Boolean indicating workflow will handle release (`false` when Step 0 found no `post-merge-release.yml` on `origin/main`)

## Error Handling

| Error | Likely Cause | Suggested Action |
|-------|--------------|------------------|
| `nothing to commit` | Files unchanged or not staged | Verify changes were made and staged correctly |
| {{PUSH_FAILURE_ROW}} |
| Already on main branch | Wrong workflow used | Use `release-git-local` skill for local releases |
| `cat-file` non-zero for `origin/main:.github/workflows/post-merge-release.yml` | Repository never ran `smaqit-extensions init`/`update`, or ran a version without the workflow template | Warn per Step 0; fix with `smaqit-extensions init` or `update`, then get the file onto `main` |

## Critical Differences from release-git-local

| Aspect | release-git-local | release-git-pr |
|--------|-------------------|----------------|
| **Branch** | main | Feature/PR branch |
| **Commit message** | "Release vX.Y.Z" | "Prepare release vX.Y.Z" |
| **Tag creation** | ✅ Yes, immediately | ❌ No, after merge to main |
| **Push method** | `git push` directly | {{PUSH_METHOD_SUMMARY}} |
| **Git credentials** | User's local credentials | {{PUSH_CREDENTIAL_SOURCE}} |
| **When to use** | Developer's local machine | CI/CD or agent workflow |

## Notes

- This skill is for **PR-based release workflows only**
- Tags are intentionally NOT created on PR branches
- Complete release automation happens via post-merge workflow after PR merge
- Push authentication is handled by {{PUSH_METHOD_SUMMARY}}
- PR title must match pattern for post-merge automation to trigger
- Release completes automatically after PR merge: tag + GitHub Release (plus any project-added build steps)
- See `.github/workflows/post-merge-release.yml` for workflow details
