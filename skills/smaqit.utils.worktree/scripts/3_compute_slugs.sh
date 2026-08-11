#!/usr/bin/env bash
# ==============================================================================
# Worktree Skill — Step 3: Compute worktree slugs for selected branches
# ==============================================================================
# Accepts branch names as arguments and outputs a JSON branch → slug map.
#
# Slug rules:
#   - Replace non-alphanumeric chars (except /, -, .) with -
#   - Replace / with -
#   - Lowercase
#   - Prefix with "<project>-wt-"
#
# Usage: bash 3_compute_slugs.sh feat/hindsight demo/user-identity
# ==============================================================================
set -euo pipefail

if [ $# -eq 0 ]; then
  echo "{}"
  exit 0
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
PROJECT_NAME="$(basename "$REPO_ROOT")"

result="{"
sep=""
for branch in "$@"; do
  slug="${PROJECT_NAME}-wt-$(echo "$branch" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9/.-]/-/g' \
    | sed 's|/|-|g')"
  result="${result}${sep}\"${branch}\":\"${slug}\""
  sep=", "
done
result="${result}}"

echo "$result"
