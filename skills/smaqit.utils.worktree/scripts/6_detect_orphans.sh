#!/usr/bin/env bash
# ==============================================================================
# Worktree Skill — Step 6: Detect and remove orphan worktrees
# ==============================================================================
# Reads `git worktree list --porcelain`, checks each non-primary worktree
# against `git branch --list`, and removes it only when its branch is absent.
#
# Output: JSON summary of removed orphans and errors.
# ==============================================================================
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"

removed="{}"
errors="{}"
while IFS= read -r line; do
  case "$line" in
    worktree\ *)
      current_path="${line#worktree }"
      ;;
    branch\ refs/heads/*)
      branch="${line#branch refs/heads/}"
      # Skip the primary repository worktree.
      if [ "$current_path" = "$REPO_ROOT" ]; then
        continue
      fi
      # Test output, not exit status: `git branch --list` exits zero even when
      # no branch matches.
      if [ -z "$(git -C "$REPO_ROOT" branch --list "$branch")" ]; then
        if err_output="$(git -C "$REPO_ROOT" worktree remove "$current_path" 2>&1)"; then
          removed="$(echo "$removed" | jq --arg b "$branch" --arg p "$current_path" '. + {($b): $p}')"
        else
          errors="$(echo "$errors" | jq --arg b "$branch" --arg m "$err_output" '. + {($b): $m}')"
        fi
      fi
      ;;
  esac
done < <(git -C "$REPO_ROOT" worktree list --porcelain)

jq -n \
  --argjson removed "$removed" \
  --argjson errors "$errors" \
  '{removed: $removed, errors: $errors}'
