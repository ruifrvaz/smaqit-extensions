#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/smaqit-worktree-layout.XXXXXX")"

cleanup() {
  rm -rf -- "$fixture_root"
}
trap cleanup EXIT

fail() {
  echo "[ERROR] $*" >&2
  exit 1
}

assert_exists() {
  test -e "$1" || fail "Expected path to exist: $1"
}

assert_missing() {
  test ! -e "$1" || fail "Expected path to be excluded: $1"
}

create_fixture_repo() {
  local repo="$1"
  mkdir -p \
    "$repo/.github/agents" \
    "$repo/.github/skills" \
    "$repo/.github/workflows" \
    "$repo/.claude/agents" \
    "$repo/.claude/commands" \
    "$repo/.claude/skills" \
    "$repo/.agents/skills" \
    "$repo/.codex/agents"
  cp -R "$repo_root/skills/smaqit.utils.worktree/scripts" \
    "$repo/.agents/skills/smaqit.utils.worktree-scripts"
  touch \
    "$repo/.github/agents/generated.md" \
    "$repo/.github/skills/generated.md" \
    "$repo/.github/workflows/project.yml" \
    "$repo/.claude/agents/generated.md" \
    "$repo/.claude/commands/generated.md" \
    "$repo/.claude/skills/generated.md" \
    "$repo/.agents/skills/generated.md" \
    "$repo/.codex/agents/generated.toml" \
    "$repo/project.txt"
  git -C "$repo" init -q -b main
  git -C "$repo" config user.email test@example.invalid
  git -C "$repo" config user.name test
  git -C "$repo" add .
  git -C "$repo" commit -qm fixture
}

run_creation() {
  local repo="$1"
  local branch="$2"
  local slug="$3"
  git -C "$repo" branch "$branch" main
  printf '{"%s":"%s"}' "$branch" "$slug" \
    | bash "$repo/.agents/skills/smaqit.utils.worktree-scripts/5_create_worktrees.sh" --existing '{}'
}

fixture_repo="$fixture_root/repo"
fixture_branch='task/019-layout'
fixture_slug='repo-wt-task-019-layout'
fixture_worktree="$fixture_root/$fixture_slug"
create_fixture_repo "$fixture_repo"

creation_json="$(run_creation "$fixture_repo" "$fixture_branch" "$fixture_slug")"
jq -e '.errors == {} and (.created | has("task/019-layout"))' <<<"$creation_json" >/dev/null

assert_exists "$fixture_repo/.github/agents/generated.md"
assert_exists "$fixture_repo/.claude/skills/generated.md"
git -C "$fixture_repo" sparse-checkout list >/dev/null 2>&1 && fail "Primary checkout became sparse"

assert_exists "$fixture_worktree/.github/workflows/project.yml"
assert_exists "$fixture_worktree/project.txt"
assert_missing "$fixture_worktree/.github/agents"
assert_missing "$fixture_worktree/.github/skills"
assert_missing "$fixture_worktree/.claude/agents"
assert_missing "$fixture_worktree/.claude/commands"
assert_missing "$fixture_worktree/.claude/skills"
assert_missing "$fixture_worktree/.agents/skills"
assert_missing "$fixture_worktree/.codex/agents"

bash "$fixture_repo/.agents/skills/smaqit.utils.worktree-scripts/7_build_workspace.sh" >/dev/null
workspace_file="$fixture_repo/repo.code-workspace"
assert_exists "$workspace_file"
jq -e '.settings["files.exclude"] == {"**/bin/**": true, "**/obj/**": true}' "$workspace_file" >/dev/null \
  || fail "Workspace hides platform paths"
jq -e '.folders | length == 2 and .[0].name == "main" and .[1].name == "task/019-layout"' "$workspace_file" >/dev/null \
  || fail "Workspace folders do not reflect the created worktree"

failure_repo="$fixture_root/failure-repo"
failure_branch='task/019-sparse-failure'
failure_slug='failure-repo-wt-task-019-sparse-failure'
failure_worktree="$fixture_root/$failure_slug"
create_fixture_repo "$failure_repo"
mkdir -p "$fixture_root/bin"
real_git="$(command -v git)"
cat > "$fixture_root/bin/git" <<'EOF'
#!/usr/bin/env bash
for arg in "$@"; do
  if [ "$arg" = "sparse-checkout" ]; then
    for next in "$@"; do
      if [ "$next" = "set" ]; then
        echo "simulated sparse configuration failure" >&2
        exit 1
      fi
    done
  fi
done
exec "$SMAQIT_REAL_GIT" "$@"
EOF
chmod +x "$fixture_root/bin/git"

failure_json="$(PATH="$fixture_root/bin:$PATH" SMAQIT_REAL_GIT="$real_git" run_creation "$failure_repo" "$failure_branch" "$failure_slug")"
jq -e '.created == {} and (.errors | has("task/019-sparse-failure"))' <<<"$failure_json" >/dev/null
assert_exists "$failure_worktree/.github/agents/generated.md"
assert_exists "$failure_worktree/.claude/skills/generated.md"
git -C "$failure_worktree" sparse-checkout list >/dev/null 2>&1 && fail "Failure fallback left worktree sparse"

echo "[PASS] Worktree sparse layout and workspace visibility"
