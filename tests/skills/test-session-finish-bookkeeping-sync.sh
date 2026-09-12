#!/usr/bin/env bash
# Hermetic checks for session-finish's protected-branch bookkeeping-sync
# fallback: the refspec push mechanics (create-then-update a remote branch
# with no local branch ever created), the merge-based reconciliation once
# that PR merges (tolerating local main ahead, aborting cleanly on a genuine
# conflict), and contract assertions on the documented fallback.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/smaqit-session-finish-sync.XXXXXX")"

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

# --- Mechanical test 1: refspec push creates then force-with-lease-updates -
# the remote sync branch, with no local branch ever created -----------------

REMOTE="$FIXTURE_ROOT/remote.git"
PRIMARY="$FIXTURE_ROOT/primary"

git init --bare -b main "$REMOTE" >/dev/null
git clone --quiet "$REMOTE" "$PRIMARY"
git -C "$PRIMARY" config user.email "test@example.invalid"
git -C "$PRIMARY" config user.name "Smaqit Test"
printf 'seed\n' > "$PRIMARY/seed.txt"
git -C "$PRIMARY" add seed.txt
git -C "$PRIMARY" commit -q -m "seed"
git -C "$PRIMARY" push -q origin main

# Simulate local main accumulating bookkeeping ahead of origin/main — exactly
# what task 036 produces every session — that a direct push would carry.
printf 'bookkeeping-1\n' > "$PRIMARY/planning.txt"
git -C "$PRIMARY" add planning.txt
git -C "$PRIMARY" commit -q -m "chore: start task 900"

(
  cd "$PRIMARY"
  git fetch origin chore/session-bookkeeping-sync 2>/dev/null || true
  git push --force-with-lease origin main:refs/heads/chore/session-bookkeeping-sync
) || fail "first refspec push did not create the remote sync branch"

[ -z "$(git -C "$PRIMARY" branch --list chore/session-bookkeeping-sync)" ] \
  || fail "a local branch was created for the sync push — it must never be"

git -C "$PRIMARY" fetch -q origin chore/session-bookkeeping-sync
[ "$(git -C "$PRIMARY" rev-parse main)" = "$(git -C "$PRIMARY" rev-parse origin/chore/session-bookkeeping-sync)" ] \
  || fail "remote sync branch does not match local main after the first push"

# A later session adds more bookkeeping; the same command must update the
# existing remote branch in place via force-with-lease, not fail or duplicate.
printf 'bookkeeping-2\n' > "$PRIMARY/planning2.txt"
git -C "$PRIMARY" add planning2.txt
git -C "$PRIMARY" commit -q -m "chore: complete task 900"

(
  cd "$PRIMARY"
  git fetch origin chore/session-bookkeeping-sync 2>/dev/null || true
  git push --force-with-lease origin main:refs/heads/chore/session-bookkeeping-sync
) || fail "second refspec push did not update the existing remote sync branch"

git -C "$PRIMARY" fetch -q origin chore/session-bookkeeping-sync
[ "$(git -C "$PRIMARY" rev-parse main)" = "$(git -C "$PRIMARY" rev-parse origin/chore/session-bookkeeping-sync)" ] \
  || fail "remote sync branch was not updated to local main's new tip"
LOG="$(git -C "$PRIMARY" log --oneline origin/chore/session-bookkeeping-sync)"
echo "$LOG" | grep -q "chore: start task 900" || fail "sync branch lost the first bookkeeping commit"
echo "$LOG" | grep -q "chore: complete task 900" || fail "sync branch lost the second bookkeeping commit"

echo "[PASS] refspec push creates then force-with-lease-updates the sync branch, no local branch ever created"

# --- Mechanical test 2: reconciliation merges origin/main, tolerating local -
# main ahead, and aborts cleanly on a genuine conflict -----------------------
# Same shape as task 036's own task-complete Step 17 test, reused here since
# Step 7's post-merge reconciliation follows the identical fetch+merge policy.

MERGER="$FIXTURE_ROOT/merger-clone"
git clone --quiet "$REMOTE" "$MERGER"
git -C "$MERGER" config user.email "test@example.invalid"
git -C "$MERGER" config user.name "Smaqit Test"
printf 'feature\n' > "$MERGER/feature.txt"
git -C "$MERGER" add feature.txt
git -C "$MERGER" commit -q -m "chore: sync session bookkeeping (merged PR)"
git -C "$MERGER" push -q origin main

# Primary's local main is still ahead with its own unpushed bookkeeping from
# the mechanical test above, on a history divergent from origin/main's tip.
(
  cd "$PRIMARY"
  git fetch -q origin main
  git merge -q origin/main
) || fail "reconciliation did not converge local main ahead of origin/main with a real remote merge"

LOG="$(git -C "$PRIMARY" log --oneline main)"
echo "$LOG" | grep -q "chore: complete task 900" || fail "reconciliation lost the primary checkout's own unpushed bookkeeping"
echo "$LOG" | grep -q "chore: sync session bookkeeping (merged PR)" || fail "reconciliation did not bring in the merged sync PR's commit"

echo "[PASS] reconciliation merges origin/main into local main across unpushed bookkeeping"

# A genuine conflict — both sides touching the same file — must never
# auto-resolve; the reconciliation policy requires `git merge --abort`.
CONFLICT_REMOTE="$FIXTURE_ROOT/conflict-remote.git"
CONFLICT_PRIMARY="$FIXTURE_ROOT/conflict-primary"
CONFLICT_MERGER="$FIXTURE_ROOT/conflict-merger"

git init --bare -b main "$CONFLICT_REMOTE" >/dev/null
git clone --quiet "$CONFLICT_REMOTE" "$CONFLICT_PRIMARY"
git -C "$CONFLICT_PRIMARY" config user.email "test@example.invalid"
git -C "$CONFLICT_PRIMARY" config user.name "Smaqit Test"
printf 'line1\n' > "$CONFLICT_PRIMARY/shared.txt"
git -C "$CONFLICT_PRIMARY" add shared.txt
git -C "$CONFLICT_PRIMARY" commit -q -m "seed"
git -C "$CONFLICT_PRIMARY" push -q origin main

git clone --quiet "$CONFLICT_REMOTE" "$CONFLICT_MERGER"
git -C "$CONFLICT_MERGER" config user.email "test@example.invalid"
git -C "$CONFLICT_MERGER" config user.name "Smaqit Test"
printf 'line1\nremote change\n' > "$CONFLICT_MERGER/shared.txt"
git -C "$CONFLICT_MERGER" add shared.txt
git -C "$CONFLICT_MERGER" commit -q -m "remote edit"
git -C "$CONFLICT_MERGER" push -q origin main

printf 'line1\nlocal change\n' > "$CONFLICT_PRIMARY/shared.txt"
git -C "$CONFLICT_PRIMARY" add shared.txt
git -C "$CONFLICT_PRIMARY" commit -q -m "local edit"

(
  cd "$CONFLICT_PRIMARY"
  git fetch -q origin main
  if git merge -q origin/main >/dev/null 2>&1; then
    echo "merge unexpectedly succeeded on a genuine conflict" >&2
    exit 1
  fi
  git merge --abort
) || fail "a genuine merge conflict must abort cleanly, never auto-resolve"

[ -z "$(git -C "$CONFLICT_PRIMARY" status --porcelain)" ] \
  || fail "git merge --abort must leave a clean working tree"

echo "[PASS] reconciliation aborts cleanly on a genuine conflict"

# --- Contract assertions ----------------------------------------------------

SESSION_FINISH="$SOURCE_ROOT/skills/smaqit.session-finish/SKILL.md"

assert_contains "$SESSION_FINISH" 'chore/session-bookkeeping-sync' "the reused sync branch name is documented"
assert_contains "$SESSION_FINISH" 'GH006' "protected-branch rejection is classified by GitHub's own error wording"
assert_contains "$SESSION_FINISH" 'never self-merge' "session-finish never self-merges the sync PR"
assert_contains "$SESSION_FINISH" '--force-with-lease origin main:refs/heads/chore/session-bookkeeping-sync' "the refspec push command is documented exactly"
assert_contains "$SESSION_FINISH" 'chore: sync session bookkeeping' "the sync PR title is documented"
assert_contains "$SESSION_FINISH" 'never matches' "the sync PR title is confirmed to avoid the release-trigger pattern"
assert_contains "$SESSION_FINISH" 'Never reclassify a 403/permission rejection' "a 403 is never treated as the protected-branch case"
assert_contains "$SESSION_FINISH" 'git merge --abort' "reconciliation aborts cleanly on a genuine conflict"
assert_contains "$SESSION_FINISH" 'never delete or close the branch/PR' "the sync branch/PR is never deleted or closed"

# The sync PR title must not match post-merge-release.yml's own trigger regex,
# so merging it never spuriously tags a release.
SYNC_TITLE="chore: sync session bookkeeping"
echo "$SYNC_TITLE" | grep -qE '^(Prepare release|Release) v[0-9]+\.[0-9]+\.[0-9]+$' \
  && fail "the sync PR title matches the release-trigger pattern — it would spuriously tag a release"

echo "[PASS] session-finish bookkeeping-sync fallback contract"
