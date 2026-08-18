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

# Install scripts outside any fixture repo, mirroring the real global-install
# topology (~/.claude/skills/, ~/.agents/skills/) where installed scripts never
# live inside the project repo they operate on. Copying them under a fixture
# repo instead would let the old SCRIPT_DIR/BASH_SOURCE-based resolution
# accidentally succeed, masking a regression of that bug.
global_scripts="$fixture_root/global-skills/smaqit.utils.worktree-scripts"
mkdir -p "$(dirname "$global_scripts")"
cp -R "$repo_root/skills/smaqit.utils.worktree/scripts" "$global_scripts"

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
  # A tracked placeholder workspace file, committed before any worktree is
  # created, so a regression that stops excluding it from sparse checkout
  # would actually show up in the new worktree's checkout.
  echo '{"folders": [{"name": "main", "path": "."}], "settings": {}}' \
    > "$repo/$(basename "$repo").code-workspace"
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
    | (cd "$repo" && bash "$global_scripts/5_create_worktrees.sh" --existing '{}')
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
assert_missing "$fixture_worktree/repo.code-workspace"

(cd "$fixture_repo" && bash "$global_scripts/7_build_workspace.sh") >/dev/null
workspace_file="$fixture_repo/repo.code-workspace"
assert_exists "$workspace_file"
jq -e '.settings["files.exclude"] == {"**/bin/**": true, "**/obj/**": true}' "$workspace_file" >/dev/null \
  || fail "Workspace hides platform paths"
jq -e '.folders | length == 2 and .[0].name == "main" and .[1].name == "task/019-layout"' "$workspace_file" >/dev/null \
  || fail "Workspace folders do not reflect the created worktree"

# Inject content this script doesn't own — a manually-added sibling repo
# folder and a custom setting — then remove the worktree and rebuild. Both
# must survive; only the removed worktree's own folder entry should drop.
jq '.folders += [{"name": "local-llm", "path": "../local-llm"}] | .settings["myCustomSetting"] = true' \
  "$workspace_file" > "$workspace_file.tmp"
mv "$workspace_file.tmp" "$workspace_file"

git -C "$fixture_repo" worktree remove "$fixture_worktree"
git -C "$fixture_repo" branch -D "$fixture_branch" >/dev/null

(cd "$fixture_repo" && bash "$global_scripts/7_build_workspace.sh") >/dev/null
jq -e '.folders | length == 2
    and (map(.name) | index("main") != null)
    and (map(.name) | index("local-llm") != null)
    and (map(.name) | index("task/019-layout") | not)' "$workspace_file" >/dev/null \
  || fail "Foreign folder did not survive workspace regeneration, or the removed worktree's entry lingered"
jq -e '.settings["myCustomSetting"] == true
    and .settings["files.exclude"] == {"**/bin/**": true, "**/obj/**": true}' "$workspace_file" >/dev/null \
  || fail "Foreign setting did not survive workspace regeneration"

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
