#!/usr/bin/env bash
# ==============================================================================
# Worktree Skill — Step 2: Validate prerequisites
# ==============================================================================
# Checks that Git and jq are on PATH and the current directory is a Git
# repository. Exits on the first failed prerequisite.
# ==============================================================================
set -euo pipefail

command -v git >/dev/null 2>&1 || { echo "git is required."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is required."; exit 1; }
git rev-parse --git-dir >/dev/null 2>&1 || { echo "Not a git repository."; exit 1; }

echo "Prerequisites ok — git, jq available, git repository detected."
