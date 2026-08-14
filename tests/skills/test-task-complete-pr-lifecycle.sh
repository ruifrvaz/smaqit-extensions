#!/usr/bin/env bash
# Hermetic checks for PR-gated task-complete: the two genuinely mechanical
# behaviors (bounded fetch-rebase-retry push, squash-merge-safe local branch
# deletion) exercised against real git fixtures, plus contract assertions on
# the documented Phase 1/Phase 2 procedure across every file it touches.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/smaqit-task-complete-pr.XXXXXX")"

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
  [ "$actual" = "$expected" ] || fail "$message (expected [$expected], got [$actual])"
}

# --- Mechanical test 1: bounded fetch-rebase-retry push loop ---------------

REMOTE="$FIXTURE_ROOT/remote.git"
CLONE_A="$FIXTURE_ROOT/clone-a"
CLONE_B="$FIXTURE_ROOT/clone-b"

git init --bare -b main "$REMOTE" >/dev/null
git clone --quiet "$REMOTE" "$CLONE_A"
git clone --quiet "$REMOTE" "$CLONE_B"
for clone in "$CLONE_A" "$CLONE_B"; do
  git -C "$clone" config user.email "test@example.invalid"
  git -C "$clone" config user.name "Smaqit Test"
done

printf 'seed\n' > "$CLONE_A/seed.txt"
git -C "$CLONE_A" add seed.txt
git -C "$CLONE_A" commit -q -m "seed"
git -C "$CLONE_A" push -q origin main
git -C "$CLONE_B" pull -q origin main

# Clone B pushes first, simulating a sibling task's metadata push landing
# between Clone A's fetch and its own push attempt.
printf 'b\n' > "$CLONE_B/b.txt"
git -C "$CLONE_B" add b.txt
git -C "$CLONE_B" commit -q -m "chore: start task 200"
git -C "$CLONE_B" push -q origin main

# Clone A now has a stale origin/main locally and its own pending commit —
# this is exactly task-start/task-complete's bounded retry loop from
# smaqit.task-start SKILL.md Step 8, run verbatim against the fixture.
printf 'a\n' > "$CLONE_A/a.txt"
git -C "$CLONE_A" add a.txt
git -C "$CLONE_A" commit -q -m "chore: start task 201"

(
  cd "$CLONE_A"
  for attempt in 1 2 3; do
    git push origin main >/dev/null 2>&1 && exit 0
    if [ "$attempt" -eq 3 ]; then
      echo "push failed after 3 attempts" >&2
      exit 1
    fi
    git fetch origin main >/dev/null 2>&1
    git rebase origin/main >/dev/null 2>&1 || { git rebase --abort; exit 1; }
  done
) || fail "bounded retry loop did not recover from a routine push collision"

git -C "$CLONE_A" fetch -q origin main
[ "$(git -C "$CLONE_A" rev-parse main)" = "$(git -C "$CLONE_A" rev-parse origin/main)" ] \
  || fail "clone A did not converge with origin/main after the retry loop"
LOG="$(git -C "$CLONE_A" log --oneline main)"
echo "$LOG" | grep -q "chore: start task 200" || fail "retry loop lost the sibling's commit (task 200)"
echo "$LOG" | grep -q "chore: start task 201" || fail "retry loop lost its own commit (task 201)"

# --- Mechanical test 2: -d refuses a squash-merged branch, -D doesn't ------

REPO="$FIXTURE_ROOT/squash-repo"
git init -q -b main "$REPO"
git -C "$REPO" config user.email "test@example.invalid"
git -C "$REPO" config user.name "Smaqit Test"
printf 'root\n' > "$REPO/root.txt"
git -C "$REPO" add root.txt
git -C "$REPO" commit -q -m "root"

git -C "$REPO" checkout -q -b task/999-example
printf 'feature\n' > "$REPO/feature.txt"
git -C "$REPO" add feature.txt
git -C "$REPO" commit -q -m "feat: implement task 999"
git -C "$REPO" checkout -q main

# Simulate a GitHub squash-merge: a brand-new commit with the same content,
# never sharing history with the branch tip — this is the exact case
# smaqit.task-complete's Phase 2 must handle after `gh pr view` confirms
# MERGED, since git's own -d ancestry check cannot recognize it.
git -C "$REPO" merge --squash task/999-example >/dev/null
git -C "$REPO" commit -q -m "feat: implement task 999 (squash)"

if git -C "$REPO" branch -d task/999-example >/dev/null 2>&1; then
  fail "git branch -d unexpectedly succeeded on a squash-merged branch — the scenario this design depends on no longer holds"
fi
git -C "$REPO" branch -D task/999-example >/dev/null 2>&1 \
  || fail "git branch -D must force-delete a squash-merged branch once GitHub's own PR state already confirmed the merge"
git -C "$REPO" branch --list task/999-example | grep -q . \
  && fail "branch still present after -D"

echo "[PASS] bounded retry push loop and squash-safe branch deletion"

# --- Mechanical test 3: a child task never resolves as an owner ------------
# task-complete's Step 3a/8 branch entirely on the resolver's `kind` field —
# a child never reaches Phase 1 or Phase 2 only because 9_resolve_task_lifecycle.sh
# returns kind=="child" for it under --purpose complete. That call path is
# untested by test-parent-task-lifecycle.sh (which only exercises --purpose
# complete on the parent/owner), so exercise it directly here.

CHILD_ROOT="$FIXTURE_ROOT/child-lifecycle-project"
CHILD_WORKTREE_SCRIPTS="$FIXTURE_ROOT/child-global-skills/smaqit.utils.worktree/scripts"
mkdir -p "$CHILD_WORKTREE_SCRIPTS" "$CHILD_ROOT/.smaqit/tasks"
for script in 3_compute_slugs 4_enumerate_worktrees 5_create_worktrees 7_build_workspace 9_resolve_task_lifecycle; do
  cp "$SOURCE_ROOT/skills/smaqit.utils.worktree/scripts/${script}.sh" "$CHILD_WORKTREE_SCRIPTS/"
done
chmod +x "$CHILD_WORKTREE_SCRIPTS"/*.sh

git -C "$CHILD_ROOT" init -q -b main
git -C "$CHILD_ROOT" config user.email "test@example.invalid"
git -C "$CHILD_ROOT" config user.name "Smaqit Test"
{
  printf '# Owner\n\n**Status:** In Progress\n**Mode:** Assisted\n'
} > "$CHILD_ROOT/.smaqit/tasks/300_owner.md"
{
  printf '# Child\n\n**Status:** In Progress\n**Mode:** Assisted\n**Parent:** 300\n'
} > "$CHILD_ROOT/.smaqit/tasks/301_child.md"
git -C "$CHILD_ROOT" add .smaqit/tasks
git -C "$CHILD_ROOT" commit -q -m "seed owner and child tasks"

(
  cd "$CHILD_ROOT"
  owner_slug_json="$(bash "$CHILD_WORKTREE_SCRIPTS/3_compute_slugs.sh" task/300-owner)"
  existing_json="$(bash "$CHILD_WORKTREE_SCRIPTS/4_enumerate_worktrees.sh")"
  git branch task/300-owner main
  printf '%s' "$owner_slug_json" | bash "$CHILD_WORKTREE_SCRIPTS/5_create_worktrees.sh" --existing "$existing_json" >/dev/null
  bash "$CHILD_WORKTREE_SCRIPTS/7_build_workspace.sh" >/dev/null
)

child_complete_result="$(cd "$CHILD_ROOT" && bash "$CHILD_WORKTREE_SCRIPTS/9_resolve_task_lifecycle.sh" --task 301 --purpose complete)"
child_kind="$(jq -r '.kind' <<< "$child_complete_result")"
[ "$child_kind" = "child" ] \
  || fail "task-complete's own routing depends on this: a child task under --purpose complete must resolve as kind=child, never owner — got kind=$child_kind"

echo "[PASS] a child task's completion resolves as kind=child, never owner — Phase 1/2 are unreachable for it"

# --- Mechanical test 4: an owner with Status "PR Open" still resolves ------
# Found live: 9_resolve_task_lifecycle.sh's find_active_task() originally
# hardcoded a check for Status == "In Progress" — correct for Phase 1, but
# task-complete's Phase 2 re-invokes this same resolver while Status is
# "PR Open", and the hardcoded check rejected it outright ("Task NNN must be
# In Progress in a registered worktree before completion"), even though the
# owner's worktree/branch is still fully registered and valid. Exercise both
# accepted statuses against the same owner fixture, and confirm the
# parent-join path (resolve_parent, used only by --parent/child-start) still
# requires strictly "In Progress" — a task that already has its PR open must
# not accept a new child joining it.

owner_task_file="$CHILD_ROOT/.smaqit/tasks/300_owner.md"

# The child (301) fixture from test 3 above is still declared under parent
# 300 and still "In Progress" — mark it Completed so it stops blocking 300's
# own completion, matching the resolver's declared-children gate.
sed -i 's/^\*\*Status:\*\*.*/**Status:** Completed/' "$CHILD_ROOT/.smaqit/tasks/301_child.md"

pr_open_result="$(cd "$CHILD_ROOT" && bash "$CHILD_WORKTREE_SCRIPTS/9_resolve_task_lifecycle.sh" --task 300 --purpose complete)"
assert_eq "$(jq -r '.kind' <<< "$pr_open_result")" "owner" "owner with Status In Progress still resolves as owner (baseline)"

sed -i 's/^\*\*Status:\*\*.*/**Status:** PR Open/' "$owner_task_file"
pr_open_result="$(cd "$CHILD_ROOT" && bash "$CHILD_WORKTREE_SCRIPTS/9_resolve_task_lifecycle.sh" --task 300 --purpose complete)"
assert_eq "$(jq -r '.kind' <<< "$pr_open_result")" "owner" "owner with Status PR Open must still resolve as owner for Phase 2 (--purpose complete)"

if bash "$CHILD_WORKTREE_SCRIPTS/9_resolve_task_lifecycle.sh" --parent 300 >/dev/null 2>&1; then
  fail "a task with Status PR Open must not accept a new child joining it via --parent — its worktree is about to be cleaned up"
fi

sed -i 's/^\*\*Status:\*\*.*/**Status:** In Progress/' "$owner_task_file"

echo "[PASS] Phase 2 resolves an owner whose Status is PR Open; child-join still requires strict In Progress"

# --- Contract assertions: Phase 1 / Phase 2 / mode gating -------------------

TASK_COMPLETE="$SOURCE_ROOT/skills/smaqit.task-complete/SKILL.md"
TASK_START="$SOURCE_ROOT/skills/smaqit.task-start/SKILL.md"
WORKTREE_SKILL="$SOURCE_ROOT/skills/smaqit.utils.worktree/SKILL.md"

assert_contains "$TASK_COMPLETE" '## Phase 1 — Commit, push, open PR' "task-complete documents Phase 1"
assert_contains "$TASK_COMPLETE" '## Phase 2 — Verify merge, clean up' "task-complete documents Phase 2"
assert_contains "$TASK_COMPLETE" 'gh pr merge <PR#> --merge' "Autonomous mode self-merges with an explicit merge-commit strategy"
assert_contains "$TASK_COMPLETE" 'gh pr view <PR#> --json state,mergedAt' "Phase 2 verifies merge exclusively via gh pr view"

# The PR must actually get created by something. An earlier draft delegated
# this to release-git-pr, which only ever *verifies* an existing PR's title
# (gh pr view) — leaving no step that opened one.
assert_contains "$TASK_COMPLETE" 'gh pr create --base main' "Phase 1 actually creates the PR"

# The pending annotation names the PR, so the PR has to exist first. Assert
# the ordering by line number, not just presence.
pr_create_line="$(rg -n --fixed-strings 'gh pr create --base main' "$TASK_COMPLETE" | head -1 | cut -d: -f1)"
pending_write_line="$(rg -n --fixed-strings 'Push the pending `CHANGELOG.md` entry directly to `main`' "$TASK_COMPLETE" | head -1 | cut -d: -f1)"
[ -n "$pr_create_line" ] && [ -n "$pending_write_line" ] || fail "could not locate PR-create and pending-entry steps for ordering check"
[ "$pr_create_line" -lt "$pending_write_line" ] \
  || fail "PR creation must precede writing the pending CHANGELOG entry — the annotation names the PR number"

# Without a promotion commit on the branch, the merged PR carries no changelog
# change: post-merge-release.yml's awk finds no '## [X.Y.Z]' section (empty
# release notes) and the pending annotation never clears from main.
assert_contains "$TASK_COMPLETE" 'Promote the entry on the PR' "Phase 1 promotes the pending entry on the PR branch"
assert_contains "$TASK_COMPLETE" '--force-with-lease' "the post-rebase branch push uses --force-with-lease, never bare --force"

# Phase 2 is reached by skipping the Step 4 mode check, so it must re-assert
# its own gate or Assisted-mode tasks would self-complete after a merge.
assert_contains "$TASK_COMPLETE" 'Re-check mode enforcement' "Phase 2 re-checks the mode gate independently"
assert_contains "$TASK_COMPLETE" 'go to the **Abandon Path**' "the phase gate routes to the abandon path"
assert_contains "$TASK_COMPLETE" 'git branch -D "<branch-name>"' "Phase 2 force-deletes the local branch"
assert_contains "$TASK_COMPLETE" 'Never run `git push origin --delete' "Phase 2 documents never deleting the remote branch"
assert_contains "$TASK_COMPLETE" 'Owner, Status `PR Open`' "Phase gate branches on Status for owners"
assert_contains "$TASK_COMPLETE" '## Abandon Path' "abandon path is documented"
assert_contains "$TASK_COMPLETE" 'Never reuse the version it claimed' "abandon path never reuses a burned version"
assert_contains "$TASK_COMPLETE" 'explicit user request before *each* phase' "Assisted mode gates each phase independently"
assert_contains "$TASK_START" 'Push this commit to `origin/main` immediately' "task-start pushes metadata immediately"
assert_contains "$TASK_START" 'git rebase --abort; break; }' "task-start never auto-resolves a rebase conflict"
assert_contains "$WORKTREE_SKILL" 'Force-delete the **local** branch only: `git branch -D' "worktree cleanup docs match task-complete's -D policy"
assert_contains "$WORKTREE_SKILL" 'Never delete the remote branch' "worktree cleanup docs never delete the remote branch"

# --- Contract assertions: RULES.md synced across all three copies ---------

RULES_COMPLETE="$SOURCE_ROOT/skills/smaqit.task-complete/references/RULES.md"
RULES_START="$SOURCE_ROOT/skills/smaqit.task-start/references/RULES.md"
RULES_LIST="$SOURCE_ROOT/skills/smaqit.task-list/references/RULES.md"

diff -q "$RULES_COMPLETE" "$RULES_START" >/dev/null || fail "task-start's RULES.md has drifted from task-complete's"
diff -q "$RULES_COMPLETE" "$RULES_LIST" >/dev/null || fail "task-list's RULES.md has drifted from task-complete's"
assert_contains "$RULES_COMPLETE" 'PR Open → In Progress  (cannot regress once the PR exists' "RULES.md documents the PR Open status transitions"
assert_contains "$RULES_COMPLETE" 'A child task never enters it' "RULES.md documents PR Open as owner-only"

# --- Contract assertions: templates and PLANNING.md carry the new status ---

for template in \
  "$SOURCE_ROOT/.smaqit/templates/task.template.md" \
  "$SOURCE_ROOT/installer/templates/task.template.md"
do
  assert_contains "$template" 'Not Started | In Progress | PR Open | Completed | Abandoned | Blocked' "$template documents the PR Open status"
  assert_contains "$template" '**PR:** #NNN' "$template documents the PR field"
done
assert_contains "$SOURCE_ROOT/skills/smaqit.task-create/assets/TASK_TEMPLATE.md" '**PR:** #NNN' "task-create's template documents the PR field"
# .smaqit/tasks/PLANNING.md is intentionally excluded from every task worktree's
# sparse checkout (task state lives only on the primary checkout) — it is not
# part of this repo's source tree from here, so it is not asserted against.

echo "[PASS] task-complete PR-gated lifecycle contract"
