#!/usr/bin/env bash
# ==============================================================================
# Worktree Skill — Step 4: Enumerate existing worktrees
# ==============================================================================
# Reads `git worktree list --porcelain` and outputs a JSON map of
# branch → worktree_path for every worktree except the primary repository.
#
# Output: {"feat/foo":"/path/to/wt","demo/bar":"/path/to/other-wt"}
# ==============================================================================
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"

result="{"
sep=""
while IFS= read -r line; do
  case "$line" in
    worktree\ *)
      current_path="${line#worktree }"
      ;;
    branch\ refs/heads/*)
      branch="${line#branch refs/heads/}"
      # Skip the primary repository worktree.
      if [ "$current_path" != "$REPO_ROOT" ]; then
        result="${result}${sep}\"${branch}\":\"${current_path}\""
        sep=", "
      fi
      ;;
  esac
done < <(git -C "$REPO_ROOT" worktree list --porcelain)

echo "${result}}"
