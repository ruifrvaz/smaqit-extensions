#!/usr/bin/env bash
# ==============================================================================
# Worktree Skill — Step 1: Gather branch info for user selection
# ==============================================================================
# Outputs a JSON structure with all local branches (with tracking info) and
# remote branches, including ahead/behind counts where applicable. The agent
# uses this to build the comparison table for the user.
#
# Output:
# {
#   "local": [
#     {"name": "main", "tracking": "origin/main", "ahead": 0, "behind": 0},
#     {"name": "feat/foo", "tracking": null, "ahead": null, "behind": null}
#   ],
#   "remote": ["origin/main", "origin/example"]
# }
#
# Usage: bash 1_present_branches.sh
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"

# Gather local branches. Parsing the complete `git branch -vv` output avoids
# Daisy's invalid leading comma when the current branch is the only branch.
local_json="["
sep=""
while IFS= read -r line; do
  # Strip the current-branch (*) or linked-worktree (+) marker.
  branch="$(echo "$line" | sed 's/^[*+ ]*//' | awk '{print $1}')"
  tracking=""
  if echo "$line" | grep -q '\[origin/'; then
    tracking="origin/$(echo "$line" | sed 's/.*\[origin\/\([^]]*\).*/\1/' | awk '{print $1}')"
  fi

  if [ -n "$tracking" ]; then
    counts="$(git -C "$REPO_ROOT" rev-list --left-right --count "$tracking...$branch" 2>/dev/null || echo "0 0")"
    behind="$(echo "$counts" | awk '{print $1}')"
    ahead="$(echo "$counts" | awk '{print $2}')"
    local_json="${local_json}${sep}{\"name\":\"${branch}\",\"tracking\":\"${tracking}\",\"ahead\":${ahead},\"behind\":${behind}}"
  else
    local_json="${local_json}${sep}{\"name\":\"${branch}\",\"tracking\":null,\"ahead\":null,\"behind\":null}"
  fi
  sep=","
done < <(git -C "$REPO_ROOT" branch -vv | head -50)
local_json="${local_json}]"

# Gather remote branches.
remote_json="["
sep=""
while IFS= read -r line; do
  remote_json="${remote_json}${sep}\"${line}\""
  sep=","
done < <(git -C "$REPO_ROOT" branch -r | grep -v 'origin/HEAD' | sed 's/^ *//')
remote_json="${remote_json}]"

# Output combined JSON.
jq -n \
  --argjson local "$local_json" \
  --argjson remote "$remote_json" \
  '{local: $local, remote: $remote}'
