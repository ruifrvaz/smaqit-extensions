#!/usr/bin/env bash
# ==============================================================================
# Worktree Skill — Step 5: Create missing worktrees
# ==============================================================================
# Accepts a JSON branch→slug map on stdin and an existing branch→path map
# through --existing. Creates worktrees only for branches without one.
#
# Usage:
#   echo '{"feat/foo":"project-wt-feat-foo"}' \
#     | bash 5_create_worktrees.sh --existing '{"demo/bar":"/path/to/wt"}'
#
# Output: JSON summary of created, skipped, and failed branches.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
REPO_PARENT="$(dirname "$REPO_ROOT")"

existing_json="{}"
if [ "${1:-}" = "--existing" ]; then
  existing_json="${2:-}"
fi

# Read the branch→slug mapping from stdin.
input_json="$(cat)"
created="{}"
skipped="{}"
errors="{}"

# Iterate over every selected branch.
for branch in $(echo "$input_json" | jq -r 'keys[]'); do
  slug="$(echo "$input_json" | jq -r --arg b "$branch" '.[$b]')"
  wt_path="$REPO_PARENT/$slug"
  existing_path="$(echo "$existing_json" | jq -r --arg b "$branch" '.[$b] // ""')"

  if [ -n "$existing_path" ]; then
    skipped="$(echo "$skipped" | jq --arg b "$branch" --arg p "$existing_path" '. + {($b): $p}')"
    continue
  fi

  if [ -e "$wt_path" ]; then
    errors="$(echo "$errors" | jq --arg b "$branch" --arg m "Target already exists: $wt_path" '. + {($b): $m}')"
    continue
  fi

  # Create the worktree and capture stderr for branch-specific reporting.
  if err_output="$(git -C "$REPO_ROOT" worktree add --checkout "$wt_path" "$branch" 2>&1)"; then
    # Use sparse checkout so generated scaffolding remains
    # available from the primary workspace folder but is excluded from task
    # worktrees to prevent duplicate skill and agent discovery. Canonical root
    # sources such as skills/, agents/, scripts/, and installer/ remain present.
    git -C "$wt_path" sparse-checkout init --cone 2>/dev/null || true
    git -C "$wt_path" sparse-checkout set --no-cone \
      '/*' \
      '!.github/agents/' \
      '!.github/skills/' \
      '!.github/workflows/' \
      '!.agents/' \
      '!.codex/' \
      '!.claude/' \
      2>/dev/null || true
    created="$(echo "$created" | jq --arg b "$branch" --arg p "$wt_path" '. + {($b): $p}')"
  else
    errors="$(echo "$errors" | jq --arg b "$branch" --arg m "$err_output" '. + {($b): $m}')"
  fi
done

jq -n \
  --argjson created "$created" \
  --argjson skipped "$skipped" \
  --argjson errors "$errors" \
  '{created: $created, skipped: $skipped, errors: $errors}'
