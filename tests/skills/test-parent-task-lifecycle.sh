#!/usr/bin/env bash
# Hermetic contract and topology checks for parent-owned task lifecycles.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/smaqit-parent-lifecycle.XXXXXX")"
PRIMARY_ROOT="$FIXTURE_ROOT/project"
# Installed outside the fixture repo, mirroring the real global-install
# topology (~/.claude/skills/, ~/.agents/skills/) where scripts never live
# inside the project they operate on. Installing them under $PRIMARY_ROOT
# instead would let the old SCRIPT_DIR/BASH_SOURCE-based resolution
# accidentally succeed, masking a regression of that bug. Every invocation
# below therefore runs with cwd already at $PRIMARY_ROOT (see the `cd` after
# fixture setup) since the scripts resolve the repo root from the caller's
# working directory, not from their own path.
WORKTREE_SCRIPTS="$FIXTURE_ROOT/global-skills/smaqit.utils.worktree/scripts"

cleanup() {
  rm -rf "$FIXTURE_ROOT"
}
trap cleanup EXIT

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

assert_eq() {
  local actual="$1" expected="$2" message="$3"
  [ "$actual" = "$expected" ] || fail "$message (expected $expected, got $actual)"
}

assert_contains() {
  local file="$1" pattern="$2" message="$3"
  rg -q --fixed-strings "$pattern" "$file" || fail "$message"
}

assert_fails() {
  local expected="$1"
  shift
  local output
  if output="$("$@" 2>&1)"; then
    fail "Command unexpectedly succeeded: $*"
  fi
  printf '%s' "$output" | rg -q --fixed-strings "$expected" || fail "Expected failure text: $expected"
}

write_task() {
  local path="$1" id="$2" title="$3" status="$4" parent="${5:-}" mode="${6:-Assisted}"
  mkdir -p "$(dirname "$path")"
  {
    printf -- '---\n'
    printf 'status: %s\n' "$status"
    printf 'mode: %s\n' "$mode"
    if [ -n "$parent" ]; then
      printf 'parent: "%s"\n' "$parent"
    fi
    printf -- '---\n\n'
    printf '# %s\n' "$title"
  } > "$path"
}

mkdir -p "$WORKTREE_SCRIPTS" "$PRIMARY_ROOT/.smaqit/tasks"
cp "$SOURCE_ROOT/skills/smaqit.utils.worktree/scripts/3_compute_slugs.sh" "$WORKTREE_SCRIPTS/"
cp "$SOURCE_ROOT/skills/smaqit.utils.worktree/scripts/4_enumerate_worktrees.sh" "$WORKTREE_SCRIPTS/"
cp "$SOURCE_ROOT/skills/smaqit.utils.worktree/scripts/5_create_worktrees.sh" "$WORKTREE_SCRIPTS/"
cp "$SOURCE_ROOT/skills/smaqit.utils.worktree/scripts/7_build_workspace.sh" "$WORKTREE_SCRIPTS/"
cp "$SOURCE_ROOT/skills/smaqit.utils.worktree/scripts/9_resolve_task_lifecycle.sh" "$WORKTREE_SCRIPTS/"
chmod +x "$WORKTREE_SCRIPTS"/*.sh

write_task "$PRIMARY_ROOT/.smaqit/tasks/100_feature_cycle.md" 100 "Feature Cycle" "Not Started"
write_task "$PRIMARY_ROOT/.smaqit/tasks/101_spec_revalidation.md" 101 "Spec Revalidation" "Not Started" 100
write_task "$PRIMARY_ROOT/.smaqit/tasks/102_development.md" 102 "Development" "Not Started" 100
write_task "$PRIMARY_ROOT/.smaqit/tasks/103_self_parent.md" 103 "Self Parent" "Not Started" 103
write_task "$PRIMARY_ROOT/.smaqit/tasks/104_invalid_parent.md" 104 "Invalid Parent" "Not Started" "invalid"
write_task "$PRIMARY_ROOT/.smaqit/tasks/bad_prefix_task.md" "n/a" "Bad Prefix Task" "Not Started"

git -C "$PRIMARY_ROOT" init -b main >/dev/null
git -C "$PRIMARY_ROOT" config user.email "test@example.invalid"
git -C "$PRIMARY_ROOT" config user.name "Smaqit Test"
git -C "$PRIMARY_ROOT" add .
git -C "$PRIMARY_ROOT" commit -m "fixture: parent task files" >/dev/null

# From here on, cwd is the primary checkout for every worktree-script
# invocation below, matching how an agent actually invokes an installed
# global script from within the target project.
cd "$PRIMARY_ROOT"

[ ! -e "$SOURCE_ROOT/.smaqit/templates/task.template.md" ] || fail ".smaqit/templates/task.template.md should have been retired"
assert_contains "$SOURCE_ROOT/skills/smaqit.task-create/assets/TASK_TEMPLATE.md" 'parent: "NNN"' "creation task template documents parent metadata"
assert_contains "$SOURCE_ROOT/skills/smaqit.task-start/SKILL.md" "9_resolve_task_lifecycle.sh" "task-start invokes lifecycle resolver"
assert_contains "$SOURCE_ROOT/skills/smaqit.task-complete/SKILL.md" "Report completion and stop" "task-complete exits before child cleanup"
assert_contains "$SOURCE_ROOT/skills/smaqit.task-list/SKILL.md" "shares the parent's branch/worktree" "task-list documents child ownership"

git -C "$PRIMARY_ROOT" branch task/100-feature-cycle main
parent_slug_json="$(bash "$WORKTREE_SCRIPTS/3_compute_slugs.sh" task/100-feature-cycle)"
existing_json="$(bash "$WORKTREE_SCRIPTS/4_enumerate_worktrees.sh")"
printf '%s' "$parent_slug_json" | bash "$WORKTREE_SCRIPTS/5_create_worktrees.sh" --existing "$existing_json" >/dev/null
bash "$WORKTREE_SCRIPTS/7_build_workspace.sh" >/dev/null

PARENT_ROOT="$FIXTURE_ROOT/project-wt-task-100-feature-cycle"
[ -d "$PARENT_ROOT" ] || fail "parent worktree was not created"
[ -e "$PARENT_ROOT/.smaqit/tasks" ] && fail ".smaqit/tasks/ was not excluded from the parent worktree"

# Task state lives exclusively on primary — every mutation below targets
# $PRIMARY_ROOT, never $PARENT_ROOT, since the linked worktree never has a
# copy of .smaqit/tasks/ to write to.
sed -i 's/^status:.*/status: In Progress/' "$PRIMARY_ROOT/.smaqit/tasks/100_feature_cycle.md"

child_result="$(bash "$WORKTREE_SCRIPTS/9_resolve_task_lifecycle.sh" --task 101 --purpose start)"
assert_eq "$(jq -r '.kind' <<< "$child_result")" "child" "child task is resolved as child"
assert_eq "$(jq -r '.parent' <<< "$child_result")" "100" "child parent is returned"
assert_eq "$(jq -r '.branch' <<< "$child_result")" "task/100-feature-cycle" "child reuses parent branch"
assert_eq "$(jq -r '.worktree' <<< "$child_result")" "$PARENT_ROOT" "child reuses parent worktree"
assert_eq "$(jq -r '.mode' <<< "$child_result")" "Assisted" "child inherits parent mode"
assert_eq "$(jq -r '.task_file' <<< "$child_result")" "$PRIMARY_ROOT/.smaqit/tasks/101_spec_revalidation.md" "child task file resolves on primary"

parent_create_result="$(bash "$WORKTREE_SCRIPTS/9_resolve_task_lifecycle.sh" --parent 100)"
assert_eq "$(jq -r '.kind' <<< "$parent_create_result")" "child" "child creation resolves active parent"
assert_fails "must inherit parent task 100 mode Assisted" bash "$WORKTREE_SCRIPTS/9_resolve_task_lifecycle.sh" --task 101 --purpose start --requested-mode autonomous
assert_fails "cannot declare itself as its parent" bash "$WORKTREE_SCRIPTS/9_resolve_task_lifecycle.sh" --task 103 --purpose start
assert_fails "Invalid Parent metadata" bash "$WORKTREE_SCRIPTS/9_resolve_task_lifecycle.sh" --task 104 --purpose start
assert_fails "Parent task 999 must be In Progress" bash "$WORKTREE_SCRIPTS/9_resolve_task_lifecycle.sh" --parent 999

# --- Pre-v1.18.0 bold-markdown files are rejected, never mis-parsed --------
# Found in review: every extractor returns empty for a frontmatter-less file,
# and empty is indistinguishable from "legitimately absent" — so an old-format
# CHILD silently resolved as a standalone owner (parent null, mode defaulted)
# and exited 0, which would hand it its own branch and worktree. --purpose
# start is the path that regressed; complete/--parent already failed, but for
# the wrong reason. All three must now reject with the migration message.
legacy_dir="$PRIMARY_ROOT/.smaqit/tasks"
printf '# Legacy Child\n\n**Status:** In Progress\n**Mode:** Autonomous\n**Parent:** 100\n' > "$legacy_dir/150_legacy_child.md"
printf '# Legacy Owner\n\n**Status:** In Progress\n**Mode:** Assisted\n' > "$legacy_dir/151_legacy_owner.md"

assert_fails "no YAML frontmatter block" bash "$WORKTREE_SCRIPTS/9_resolve_task_lifecycle.sh" --task 150 --purpose start
assert_fails "no YAML frontmatter block" bash "$WORKTREE_SCRIPTS/9_resolve_task_lifecycle.sh" --task 151 --purpose start
assert_fails "no YAML frontmatter block" bash "$WORKTREE_SCRIPTS/9_resolve_task_lifecycle.sh" --task 151 --purpose complete

legacy_out="$(bash "$WORKTREE_SCRIPTS/9_resolve_task_lifecycle.sh" --task 150 --purpose start 2>/dev/null || true)"
[ -z "$legacy_out" ] || fail "an old-format child must emit no resolution at all, got: $legacy_out"

rm -f "$legacy_dir/150_legacy_child.md" "$legacy_dir/151_legacy_owner.md"

# --- Quoted frontmatter values parse identically to unquoted ---------------
# The schema quotes dates and parent IDs, so `status: "In Progress"` is
# equally valid YAML; it must not silently fail to match the unquoted form.
printf -- '---\nstatus: "In Progress"\nmode: "Assisted"\nparent: "100"\n---\n\n# Quoted Child\n' \
  > "$legacy_dir/160_quoted_child.md"
quoted_result="$(bash "$WORKTREE_SCRIPTS/9_resolve_task_lifecycle.sh" --task 160 --purpose start)"
assert_eq "$(jq -r '.kind' <<< "$quoted_result")" "child" "quoted frontmatter still resolves a child as a child"
assert_eq "$(jq -r '.parent' <<< "$quoted_result")" "100" "quoted parent value is unquoted on read"
assert_eq "$(jq -r '.mode' <<< "$quoted_result")" "Assisted" "quoted mode value is unquoted on read"
rm -f "$legacy_dir/160_quoted_child.md"

assert_eq "$(git -C "$PRIMARY_ROOT" branch --format='%(refname:short)' | { rg '^task/' || true; } | wc -l | tr -d ' ')" "1" "no child branches were created"
assert_eq "$(git -C "$PRIMARY_ROOT" worktree list --porcelain | rg '^worktree ' | wc -l | tr -d ' ')" "2" "only main and parent worktrees are registered"
assert_eq "$(jq '.folders | length' "$PRIMARY_ROOT/project.code-workspace")" "2" "workspace contains main and parent only"

assert_fails "cannot complete while child tasks remain unfinished" bash "$WORKTREE_SCRIPTS/9_resolve_task_lifecycle.sh" --task 100 --purpose complete
sed -i 's/^status:.*/status: Completed/' "$PRIMARY_ROOT/.smaqit/tasks/101_spec_revalidation.md"
sed -i 's/^status:.*/status: Completed/' "$PRIMARY_ROOT/.smaqit/tasks/102_development.md"

# 104 (invalid Parent) and bad_prefix_task.md (non-NNN filename) stay in place
# through completion — the child-scan loop must skip both with a warning
# instead of aborting, which is why they were never deleted like the old
# fixture did.
complete_stderr="$FIXTURE_ROOT/complete.stderr"
owner_result="$(bash "$WORKTREE_SCRIPTS/9_resolve_task_lifecycle.sh" --task 100 --purpose complete 2>"$complete_stderr")"
assert_eq "$(jq -r '.kind' <<< "$owner_result")" "owner" "parent is lifecycle owner"
assert_eq "$(jq -r '.worktree' <<< "$owner_result")" "$PARENT_ROOT" "parent completion uses registered worktree"
assert_contains "$complete_stderr" "skipping malformed task filename" "child-scan warns instead of aborting on a non-NNN filename"
assert_contains "$complete_stderr" "invalid Parent metadata" "child-scan warns instead of aborting on invalid Parent metadata"

git -C "$PRIMARY_ROOT" add .smaqit/tasks
git -C "$PRIMARY_ROOT" commit -m "test: complete parent task on primary" >/dev/null
git -C "$PRIMARY_ROOT" merge task/100-feature-cycle --no-ff -m "merge: parent fixture" >/dev/null
git -C "$PRIMARY_ROOT" worktree remove "$PARENT_ROOT"
git -C "$PRIMARY_ROOT" branch -d task/100-feature-cycle >/dev/null
bash "$WORKTREE_SCRIPTS/7_build_workspace.sh" >/dev/null
assert_eq "$(git -C "$PRIMARY_ROOT" worktree list --porcelain | rg '^worktree ' | wc -l | tr -d ' ')" "1" "parent cleanup leaves one worktree"
assert_eq "$(git -C "$PRIMARY_ROOT" branch --format='%(refname:short)' | { rg '^task/' || true; } | wc -l | tr -d ' ')" "0" "parent cleanup leaves no task branch"
assert_eq "$(jq '.folders | length' "$PRIMARY_ROOT/project.code-workspace")" "1" "parent cleanup rebuilds one-folder workspace"

write_task "$PRIMARY_ROOT/.smaqit/tasks/110_standalone.md" 110 "Standalone Task" "Not Started"
git -C "$PRIMARY_ROOT" add .smaqit/tasks/110_standalone.md
git -C "$PRIMARY_ROOT" commit -m "fixture: standalone task" >/dev/null
standalone_start="$(bash "$WORKTREE_SCRIPTS/9_resolve_task_lifecycle.sh" --task 110 --purpose start --requested-mode autonomous)"
assert_eq "$(jq -r '.kind' <<< "$standalone_start")" "owner" "standalone task remains owner"
assert_eq "$(jq -r '.branch' <<< "$standalone_start")" "task/110-standalone-task" "standalone branch naming remains compatible"

echo "[PASS] Parent-owned task lifecycle contract and topology"
