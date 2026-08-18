#!/usr/bin/env bash
# ==============================================================================
# Worktree Skill — Step 7: Build workspace file
# ==============================================================================
# Self-contained: reads current Git worktree state and writes or updates a root
# `.code-workspace` file with `main` plus all active non-primary worktrees.
# It always re-enumerates `git worktree list` so repeated runs are idempotent.
# Any pre-existing `folders` entry this script doesn't own (not `.`, not a
# `../<project>-wt-*` worktree slug) and any `settings` key beyond the managed
# `files.exclude` block are read back from the existing file and preserved,
# rather than being discarded on every regeneration.
#
# Usage: bash 7_build_workspace.sh
# Output: path to the written workspace file.
# ==============================================================================
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
PROJECT_NAME="$(basename "$REPO_ROOT")"

# Use an existing root workspace when present; otherwise derive its name from
# the repository directory.
EXISTING_WORKSPACE="$(find "$REPO_ROOT" -maxdepth 1 -type f -name '*.code-workspace' -print -quit)"
if [ -n "$EXISTING_WORKSPACE" ]; then
  WORKSPACE_FILE="$EXISTING_WORKSPACE"
else
  WORKSPACE_FILE="$REPO_ROOT/$PROJECT_NAME.code-workspace"
fi

# Build the managed folders array: the primary repository plus every active
# worktree. This portion is always fully regenerated from Git state.
folders='[{"name": "main", "path": "."}'
while IFS= read -r line; do
  case "$line" in
    worktree\ *)
      current_path="${line#worktree }"
      ;;
    branch\ refs/heads/*)
      branch="${line#branch refs/heads/}"
      if [ "$current_path" != "$REPO_ROOT" ]; then
        # Use the actual registered worktree path rather than recomputing it.
        rel="$(realpath --relative-to="$REPO_ROOT" "$current_path")"
        folders="$folders, {\"name\": \"$branch\", \"path\": \"$rel\"}"
      fi
      ;;
  esac
done < <(git -C "$REPO_ROOT" worktree list --porcelain)
folders="$folders]"

# Read whatever the existing file already holds, so anything this script
# doesn't own can be preserved. A first run (no existing file) has nothing to
# preserve — jq's `//` defaults cover that case.
if [ -f "$WORKSPACE_FILE" ]; then
  existing_content="$(cat "$WORKSPACE_FILE")"
else
  existing_content='{}'
fi

# Preserve foreign folders (anything not `.` and not a managed worktree slug)
# and any settings key beyond the managed files.exclude block. Exclude build
# output only — workspace settings apply to every root, so hiding platform
# paths here would also hide them from the primary checkout and agents.
jq -n \
  --argjson folders "$folders" \
  --argjson existing "$existing_content" \
  --arg project "$PROJECT_NAME" \
  '
  ($existing.folders // []) as $existing_folders
  | ($existing_folders | map(select((.path == "." or (.path | startswith("../" + $project + "-wt-"))) | not))) as $foreign_folders
  | (($existing.settings // {}) * {"files.exclude": {"**/bin/**": true, "**/obj/**": true}}) as $merged_settings
  | {folders: ($folders + $foreign_folders), settings: $merged_settings}
  ' \
  > "$WORKSPACE_FILE"

echo "$WORKSPACE_FILE"
