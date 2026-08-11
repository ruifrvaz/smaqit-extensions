#!/usr/bin/env bash
# ==============================================================================
# Worktree Skill — Step 7: Build workspace file
# ==============================================================================
# Self-contained: reads current Git worktree state and writes or updates a root
# `.code-workspace` file with `main` plus all active non-primary worktrees.
# It always re-enumerates `git worktree list` so repeated runs are idempotent.
#
# Usage: bash 7_build_workspace.sh
# Output: path to the written workspace file.
# ==============================================================================
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"

# Use an existing root workspace when present; otherwise derive its name from
# the repository directory.
EXISTING_WORKSPACE="$(find "$REPO_ROOT" -maxdepth 1 -type f -name '*.code-workspace' -print -quit)"
if [ -n "$EXISTING_WORKSPACE" ]; then
  WORKSPACE_FILE="$EXISTING_WORKSPACE"
else
  PROJECT_NAME="$(basename "$REPO_ROOT")"
  WORKSPACE_FILE="$REPO_ROOT/$PROJECT_NAME.code-workspace"
fi

# Build the folders array starting with the primary repository.
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

# Exclude build output only. Workspace settings apply to every root, so hiding
# platform paths here would also hide them from the primary checkout and agents.
jq -n \
  --argjson folders "$folders" \
  '{folders: $folders, settings: {"files.exclude": {"**/bin/**": true, "**/obj/**": true}}}' \
  > "$WORKSPACE_FILE"

echo "$WORKSPACE_FILE"
