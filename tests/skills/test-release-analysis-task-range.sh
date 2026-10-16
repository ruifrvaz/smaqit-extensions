#!/usr/bin/env bash
# Hermetic checks for smaqit.release-analysis' Task-mode change range: a
# reference implementation of Step 2's revision list, exercised against fixture
# repositories, plus contract assertions on the skills that document it.
#
# The bug this guards against: Task mode once analyzed only
# <boundary-sha>..<task-branch>. A PR merged into main after the task branch was
# created (e.g. an interim PR carrying part of the task's work) is part of the
# release the task's PR triggers, but was missing from its changes list.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RELEASE_ANALYSIS="$SOURCE_ROOT/skills/smaqit.release-analysis/SKILL.md"
TASK_COMPLETE="$SOURCE_ROOT/skills/smaqit.task-complete/SKILL.md"
FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/smaqit-task-range.XXXXXX")"

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

assert_eq() {
  local actual="$1" expected="$2" message="$3"
  [ "$actual" = "$expected" ] || fail "$message — expected [$expected], got [$actual]"
}

# --- Fixture helpers -------------------------------------------------------

git_init_fixture() {
  local repo="$1"
  mkdir -p "$repo"
  git -C "$repo" init -q -b main
  git -C "$repo" config user.email "test@example.com"
  git -C "$repo" config user.name "Fixture"
  git -C "$repo" config commit.gpgsign false
  git -C "$repo" config tag.gpgsign false
}

commit() {
  local repo="$1" message="$2"
  echo "$RANDOM-$message" >> "$repo/log.txt"
  git -C "$repo" add -A
  git -C "$repo" commit -q -m "$message"
}

# A merged PR with GitHub's default merge message: subject line, blank line,
# then the PR title as the body.
merge_pr() {
  local repo="$1" number="$2" branch="$3" title="$4"
  git -C "$repo" checkout -q -b "$branch" main
  commit "$repo" "$title (work)"
  git -C "$repo" checkout -q main
  git -C "$repo" merge -q --no-ff -m "Merge pull request #${number} from owner/${branch}" -m "$title" "$branch"
}

# --- Reference implementation of Step 2 (Task mode) ------------------------

# `main` stands in for origin/main in these single-repo fixtures.
task_range_subjects() {
  local repo="$1" boundary="$2" branch="$3"
  git -C "$repo" log "^$boundary" "$branch" main --pretty=format:"%s"
}
main_not_on_branch_merges() {
  local repo="$1" boundary="$2" branch="$3"
  git -C "$repo" log "^$boundary" "^$branch" main --merges --pretty=format:"%s"
}
old_range_subjects() {
  local repo="$1" boundary="$2" branch="$3"
  git -C "$repo" log "$boundary..$branch" --pretty=format:"%s"
}
boundary_of() { git -C "$1" rev-list -n1 "$(git -C "$1" describe --tags --abbrev=0 main)"; }

# --- Scenario 1: an interim PR merged into main after the branch was created --

R1="$FIXTURE_ROOT/interim"
git_init_fixture "$R1"
commit "$R1" "initial"
git -C "$R1" tag v1.0.0
git -C "$R1" branch task/1 main
git -C "$R1" checkout -q task/1
commit "$R1" "feat: task work"
git -C "$R1" checkout -q main
merge_pr "$R1" 10 registry "Register the new host"

B1="$(boundary_of "$R1")"
range1="$(task_range_subjects "$R1" "$B1" task/1)"
printf '%s\n' "$range1" | grep -qx "feat: task work" || fail "Task-mode range includes the task branch's own commits"
printf '%s\n' "$range1" | grep -qx "Merge pull request #10 from owner/registry" || fail "Task-mode range includes an interim main merge the branch lacks"
assert_eq "$(main_not_on_branch_merges "$R1" "$B1" task/1)" "Merge pull request #10 from owner/registry" "the completeness list names the interim merge"
old_range_subjects "$R1" "$B1" task/1 | grep -q "pull request #10" && fail "fixture no longer reproduces the bug: the old range already saw the interim merge"

# --- Scenario 2: the branch predates the latest tag ------------------------
# Changes released under v1.1.0 must not be counted again.

R2="$FIXTURE_ROOT/older-branch"
git_init_fixture "$R2"
commit "$R2" "initial"
git -C "$R2" tag v1.0.0
git -C "$R2" branch task/2 main
git -C "$R2" checkout -q task/2
commit "$R2" "feat: task work"
git -C "$R2" checkout -q main
merge_pr "$R2" 20 already-released "Prepare release v1.1.0"
git -C "$R2" tag v1.1.0
merge_pr "$R2" 21 interim "Interim fix"

B2="$(boundary_of "$R2")"
range2="$(task_range_subjects "$R2" "$B2" task/2)"
printf '%s\n' "$range2" | grep -q "pull request #20" && fail "Task-mode range must exclude a PR already released before the boundary"
printf '%s\n' "$range2" | grep -qx "Merge pull request #21 from owner/interim" || fail "Task-mode range includes the post-boundary interim merge"
printf '%s\n' "$range2" | grep -qx "feat: task work" || fail "Task-mode range keeps a pre-boundary branch's own commits"

# --- Scenario 3: a release PR merged but not yet tagged --------------------
# Its merge body carries the release title; Step 2 must stop rather than fold it in.

R3="$FIXTURE_ROOT/untagged-release"
git_init_fixture "$R3"
commit "$R3" "initial"
git -C "$R3" tag v1.0.0
git -C "$R3" branch task/3 main
merge_pr "$R3" 30 other-task "Prepare release v1.1.0"
B3="$(boundary_of "$R3")"
git -C "$R3" log "^$B3" "^task/3" main --pretty=format:"%b" | grep -qE '^(Prepare release|Release) v[0-9]+\.[0-9]+\.[0-9]+$' \
  || fail "an untagged release merge is detectable from its merge body"

# --- Contract assertions ---------------------------------------------------

assert_contains "$RELEASE_ANALYSIS" '^<boundary-sha> <task-branch> origin/main' "release-analysis documents the Task-mode union range"
assert_contains "$RELEASE_ANALYSIS" 'git log "^<boundary-sha>" "^<task-branch>" origin/main' "release-analysis lists main commits missing from the task branch"
assert_contains "$RELEASE_ANALYSIS" '`main_since_boundary`' "release-analysis output names main merges beyond the task branch"
assert_contains "$RELEASE_ANALYSIS" 'Stop and report it' "release-analysis stops on a merged-but-untagged release"
assert_contains "$TASK_COMPLETE" 'main_since_boundary' "task-complete describes the Task-mode range consistently"
rg -q --fixed-strings 'computes severity/version from `<boundary-sha>..<task-branch>`' "$TASK_COMPLETE" \
  && fail "task-complete still describes the branch-only range"

echo "[PASS] release-analysis Task-mode change range"
