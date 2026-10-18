#!/usr/bin/env bash
# Hermetic checks for the release workflow preflight: the git-object check that
# task-complete (Step 10a), release-git-pr (Step 0) and release-git-local
# (Step 3a) run before a release PR is opened or a tag is pushed, exercised
# against fixture repositories, plus contract assertions on the skills and the
# release-pr agent that document it.
#
# The bug this guards against: a repository without
# .github/workflows/post-merge-release.yml followed the full
# `Prepare release vX.Y.Z` convention, merged the PR, and silently got no tag
# and no GitHub Release. Nothing in the chain checked for the file.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TASK_COMPLETE="$SOURCE_ROOT/skills/smaqit.task-complete/SKILL.md"
TASK_START="$SOURCE_ROOT/skills/smaqit.task-start/SKILL.md"
GIT_PR="$SOURCE_ROOT/skills/smaqit.release-git-pr/SKILL.md"
GIT_LOCAL="$SOURCE_ROOT/skills/smaqit.release-git-local/SKILL.md"
RELEASE_PR_AGENT="$SOURCE_ROOT/agents/smaqit.release.pr.agent.md"
WORKFLOW=".github/workflows/post-merge-release.yml"
FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/smaqit-release-preflight.XXXXXX")"

cleanup() {
  rm -rf "$FIXTURE_ROOT"
}
trap cleanup EXIT

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

assert_contains() {
  local file="$1" pattern="$2" message="$3"
  rg -q --fixed-strings -- "$pattern" "$file" || fail "$message — expected [$pattern] in $file"
}

assert_not_contains() {
  local file="$1" pattern="$2" message="$3"
  if rg -q --fixed-strings -- "$pattern" "$file"; then
    fail "$message — unexpected [$pattern] in $file"
  fi
}

line_of() {
  local file="$1" pattern="$2"
  rg -n --fixed-strings -- "$pattern" "$file" | head -1 | cut -d: -f1
}

# Reference implementation of the documented check. Exit 0 = present.
workflow_present() {
  local repo="$1" rev="$2"
  git -C "$repo" cat-file -e "$rev:$WORKFLOW" 2>/dev/null
}

# --- Fixture helpers -------------------------------------------------------

configure() {
  local repo="$1"
  git -C "$repo" config user.email "test@example.com"
  git -C "$repo" config user.name "Fixture"
  git -C "$repo" config commit.gpgsign false
}

ORIGIN="$FIXTURE_ROOT/origin.git"
CLONE="$FIXTURE_ROOT/clone"

git init -q --bare -b main "$ORIGIN"
git clone -q "$ORIGIN" "$CLONE" 2>/dev/null
configure "$CLONE"
git -C "$CLONE" checkout -q -b main
echo "seed" > "$CLONE/README.md"
git -C "$CLONE" add -A
git -C "$CLONE" commit -q -m "seed"
git -C "$CLONE" push -q origin main
git -C "$CLONE" fetch -q origin main

# 1. Missing everywhere: the incident's repository.
workflow_present "$CLONE" origin/main \
  && fail "a repository with no workflow file must fail the preflight"

# 2. On disk only: a filesystem check would pass, but GitHub never sees it.
mkdir -p "$CLONE/.github/workflows"
echo "name: Post-Merge Release" > "$CLONE/$WORKFLOW"
[ -f "$CLONE/$WORKFLOW" ] || fail "fixture setup: workflow file should exist on disk"
workflow_present "$CLONE" origin/main \
  && fail "an uncommitted workflow file must still fail the preflight"

# 3. Committed locally, not pushed: still not on the base branch the PR merges into.
git -C "$CLONE" add "$WORKFLOW"
git -C "$CLONE" commit -q -m "add release workflow"
workflow_present "$CLONE" HEAD \
  || fail "release-git-local's HEAD check must pass once the commit being tagged contains the workflow"
workflow_present "$CLONE" origin/main \
  && fail "a workflow committed only locally must fail the origin/main preflight"

# 4. A task branch created before the workflow reached main, checked out in a
#    sparse worktree that leaves out .github/: the object check is independent
#    of what the worktree has on disk.
git -C "$CLONE" branch --no-track task/001-demo origin/main
TASK_WT="$FIXTURE_ROOT/clone-wt-task-001-demo"
git -C "$CLONE" worktree add -q "$TASK_WT" task/001-demo
git -C "$TASK_WT" sparse-checkout set --no-cone '/*' '!.github/' >/dev/null

# 5. Pushed to main: present for every worktree once origin/main is fetched.
git -C "$CLONE" push -q origin main
git -C "$TASK_WT" fetch -q origin main
[ -e "$TASK_WT/$WORKFLOW" ] && fail "fixture setup: sparse task worktree should not have the workflow on disk"
workflow_present "$TASK_WT" origin/main \
  || fail "the preflight must pass from a task worktree once origin/main carries the workflow, whatever the worktree has on disk"

# --- Contract assertions ---------------------------------------------------

assert_contains "$GIT_PR" '### Step 0: Release Workflow Preflight' "release-git-pr documents the preflight as Step 0"
assert_contains "$GIT_PR" 'git cat-file -e origin/main:.github/workflows/post-merge-release.yml' "release-git-pr checks the git object on origin/main"
assert_contains "$GIT_PR" 'Run `smaqit-extensions init` (or `update`)' "release-git-pr's warning names the fix"
assert_contains "$GIT_PR" 'top of the PR description' "release-git-pr surfaces the warning in the PR when it can't prompt"
step0_line="$(line_of "$GIT_PR" '### Step 0: Release Workflow Preflight')"
step1_line="$(line_of "$GIT_PR" '### Step 1: Stage Changes')"
[ "$step0_line" -lt "$step1_line" ] || fail "release-git-pr's preflight must come before staging"

assert_contains "$TASK_COMPLETE" '10a. **Release workflow preflight.**' "task-complete runs the preflight as Step 10a"
assert_contains "$TASK_COMPLETE" "Run \`smaqit.release-git-pr\`'s Step 0" "task-complete reuses release-git-pr's preflight"
assert_contains "$TASK_COMPLETE" '**Autonomous mode:** stop and report.' "task-complete stops an Autonomous run rather than self-merging a release-less PR"
version_line="$(line_of "$TASK_COMPLETE" "10. **Compute this task's release version.**")"
preflight_line="$(line_of "$TASK_COMPLETE" '10a. **Release workflow preflight.**')"
push_line="$(line_of "$TASK_COMPLETE" 'git -C "<worktree>" push -u origin "<branch-name>"')"
[ "$version_line" -lt "$preflight_line" ] && [ "$preflight_line" -lt "$push_line" ] \
  || fail "task-complete's preflight must sit between version computation and the first push"

assert_contains "$GIT_LOCAL" '### Step 3a: Release Workflow Preflight' "release-git-local documents the preflight"
assert_contains "$GIT_LOCAL" 'git cat-file -e HEAD:.github/workflows/post-merge-release.yml' "release-git-local checks the commit being tagged"
local_preflight_line="$(line_of "$GIT_LOCAL" '### Step 3a: Release Workflow Preflight')"
tag_line="$(line_of "$GIT_LOCAL" '### Step 4: Create Annotated Tag')"
[ "$local_preflight_line" -lt "$tag_line" ] || fail "release-git-local's preflight must come before tagging"

assert_contains "$RELEASE_PR_AGENT" 'Runs its release workflow preflight (Step 0) first' "release-pr agent documents the preflight"

# No release skill or agent may state the workflow's presence as a given.
for file in "$GIT_PR" "$GIT_LOCAL" "$RELEASE_PR_AGENT"; do
  assert_not_contains "$file" 'is installed by `smaqit-extensions install --scope project` / `update`' "presence must be checked, not assumed"
  assert_not_contains "$file" '(installed by `smaqit-extensions install --scope project` / `update`' "presence must be checked, not assumed"
  assert_not_contains "$file" 'deploy `.github/workflows/post-merge-release.yml` automatically' "presence must be checked, not assumed"
done

# Isolated subagent worktrees can't see uncommitted Assisted-mode work.
assert_contains "$TASK_START" 'never in an isolated worktree of its own' "task-start warns against isolated subagent worktrees"
assert_contains "$TASK_COMPLETE" 'Work a subagent did in an isolated worktree of its own' "task-complete's commit step names the isolated-worktree gap"

echo "[PASS] release workflow preflight"
