#!/usr/bin/env bash
# ==============================================================================
# Worktree Skill — Step 9: Resolve task lifecycle ownership
# ==============================================================================
# Resolves whether a task owns its Git lifecycle or joins an active parent task.
# Run this script from the primary checkout: task worktrees deliberately omit
# installed skill directories through sparse checkout.
#
# Usage:
#   9_resolve_task_lifecycle.sh --task 020 --purpose start [--requested-mode assisted]
#   9_resolve_task_lifecycle.sh --task 020 --purpose complete
#   9_resolve_task_lifecycle.sh --parent 020
#
# Output: JSON with kind (owner|child), branch, worktree, mode, and task_file.
# ==============================================================================
set -euo pipefail

task_id=""
parent_id=""
purpose="start"
requested_mode=""

usage() {
  echo "Usage: $0 (--task NNN [--purpose start|complete] [--requested-mode assisted|autonomous] | --parent NNN)" >&2
  exit 2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --task) task_id="${2:-}"; shift 2 ;;
    --parent) parent_id="${2:-}"; shift 2 ;;
    --purpose) purpose="${2:-}"; shift 2 ;;
    --requested-mode) requested_mode="${2:-}"; shift 2 ;;
    *) usage ;;
  esac
done

if { [ -z "$task_id" ] && [ -z "$parent_id" ]; } || { [ -n "$task_id" ] && [ -n "$parent_id" ]; }; then
  usage
fi
if ! [[ "$purpose" =~ ^(start|complete)$ ]]; then
  echo "Unsupported purpose: $purpose" >&2
  exit 2
fi

validate_id() {
  if ! [[ "$1" =~ ^[0-9]{3}$ ]]; then
    echo "Task identifiers must use the current NNN format: $1" >&2
    exit 2
  fi
}

validate_id "${task_id:-$parent_id}"

canonical_mode() {
  case "${1,,}" in
    ""|assisted) printf '%s\n' "Assisted" ;;
    autonomous) printf '%s\n' "Autonomous" ;;
    *) echo "Unsupported workflow mode: $1" >&2; exit 2 ;;
  esac
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mapfile -t worktree_lines < <(git -C "$SCRIPT_DIR" worktree list --porcelain)

worktree_paths=()
worktree_branches=()
current_path=""
current_branch=""
for line in "${worktree_lines[@]}"; do
  case "$line" in
    worktree\ *)
      if [ -n "$current_path" ]; then
        worktree_paths+=("$current_path")
        worktree_branches+=("$current_branch")
      fi
      current_path="${line#worktree }"
      current_branch=""
      ;;
    branch\ refs/heads/*) current_branch="${line#branch refs/heads/}" ;;
  esac
done
if [ -n "$current_path" ]; then
  worktree_paths+=("$current_path")
  worktree_branches+=("$current_branch")
fi

if [ "${#worktree_paths[@]}" -eq 0 ]; then
  echo "Unable to resolve registered Git worktrees." >&2
  exit 1
fi

primary_root="${worktree_paths[0]}"

task_file_in() {
  local root="$1" id="$2"
  local matches=()
  shopt -s nullglob
  matches=("$root/.smaqit/tasks/$id"_*.md)
  shopt -u nullglob
  if [ "${#matches[@]}" -gt 1 ]; then
    echo "Multiple task files found for $id in $root" >&2
    exit 1
  fi
  if [ "${#matches[@]}" -eq 1 ]; then
    printf '%s\n' "${matches[0]}"
  fi
}

task_status() {
  sed -n 's/^\*\*Status:\*\*[[:space:]]*//p' "$1" | head -1 | sed 's/[[:space:]]*$//'
}

task_mode() {
  local mode
  mode="$(sed -n 's/^\*\*Mode:\*\*[[:space:]]*//p' "$1" | head -1 | sed 's/[[:space:]]*$//')"
  canonical_mode "$mode"
}

task_parent() {
  local line value
  line="$(sed -n 's/^\*\*Parent:\*\*[[:space:]]*//p' "$1" | head -1 | sed 's/[[:space:]]*$//')"
  [ -z "$line" ] && return 0
  value="${line%%[[:space:]]*}"
  if ! [[ "$value" =~ ^[0-9]{3}$ ]]; then
    echo "Invalid Parent metadata in $1: $line" >&2
    return 1
  fi
  printf '%s\n' "$value"
}

task_branch_name() {
  local file="$1" id="$2" title slug
  title="$(sed -n '1s/^# //p' "$file")"
  slug="$(printf '%s' "$title" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
  printf 'task/%s-%s\n' "$id" "$slug"
}

find_active_task() {
  local id="$1" file expected_branch index
  file="$(task_file_in "$primary_root" "$id")"
  [ -n "$file" ] || return 1
  [ "$(task_status "$file")" = "In Progress" ] || return 1
  expected_branch="$(task_branch_name "$file" "$id")"
  for index in "${!worktree_branches[@]}"; do
    if [ "${worktree_branches[$index]}" = "$expected_branch" ]; then
      printf '%s\t%s\t%s\n' "${worktree_paths[$index]}" "$expected_branch" "$file"
      return 0
    fi
  done
  return 1
}

emit() {
  jq -n \
    --arg kind "$1" \
    --arg task "$2" \
    --arg parent "$3" \
    --arg branch "$4" \
    --arg worktree "$5" \
    --arg mode "$6" \
    --arg task_file "$7" \
    '{kind: $kind, task: $task, parent: (if $parent == "" then null else $parent end), branch: $branch, worktree: (if $worktree == "" then null else $worktree end), mode: $mode, task_file: $task_file}'
}

resolve_parent() {
  local id="$1" active parent_root parent_branch parent_file
  active="$(find_active_task "$id" || true)"
  if [ -z "$active" ]; then
    echo "Parent task $id must be In Progress in a registered worktree before a child can join it." >&2
    exit 1
  fi
  IFS=$'\t' read -r parent_root parent_branch parent_file <<< "$active"
  if [ -z "$parent_branch" ] || [ "$parent_branch" = "main" ]; then
    echo "Parent task $id has no usable non-main worktree branch." >&2
    exit 1
  fi
  local parent_parent
  parent_parent="$(task_parent "$parent_file")" || exit 1
  if [ -n "$parent_parent" ]; then
    echo "Nested parent tasks are not supported: parent task $id is itself a child." >&2
    exit 1
  fi
  printf '%s\t%s\t%s\n' "$parent_root" "$parent_branch" "$parent_file"
}

if [ -n "$parent_id" ]; then
  parent_info="$(resolve_parent "$parent_id")"
  IFS=$'\t' read -r owner_root owner_branch owner_file <<< "$parent_info"
  emit "child" "" "$parent_id" "$owner_branch" "$owner_root" "$(task_mode "$owner_file")" ""
  exit 0
fi

candidate_file="$(task_file_in "$primary_root" "$task_id")"
if [ -z "$candidate_file" ]; then
  echo "Task file not found for $task_id." >&2
  exit 1
fi

declared_parent="$(task_parent "$candidate_file")" || exit 1
if [ -z "$declared_parent" ]; then
  if [ "$purpose" = "complete" ]; then
    owner_info="$(find_active_task "$task_id" || true)"
    if [ -z "$owner_info" ]; then
      echo "Task $task_id must be In Progress in a registered worktree before completion." >&2
      exit 1
    fi
    IFS=$'\t' read -r owner_root owner_branch owner_file <<< "$owner_info"
    incomplete_children=()
    for child_file in "$primary_root"/.smaqit/tasks/*.md; do
      [ -f "$child_file" ] || continue
      child_id="$(basename "$child_file" | cut -d_ -f1)"
      if ! [[ "$child_id" =~ ^[0-9]{3}$ ]]; then
        echo "Warning: skipping malformed task filename: $child_file" >&2
        continue
      fi
      if ! child_parent="$(task_parent "$child_file")"; then
        echo "Warning: skipping $child_file — invalid Parent metadata" >&2
        continue
      fi
      if [ "$child_parent" = "$task_id" ] && [ "$(task_status "$child_file")" != "Completed" ]; then
        incomplete_children+=("$child_id")
      fi
    done
    if [ "${#incomplete_children[@]}" -gt 0 ]; then
      echo "Parent task $task_id cannot complete while child tasks remain unfinished: ${incomplete_children[*]}." >&2
      exit 1
    fi
    emit "owner" "$task_id" "" "$owner_branch" "$owner_root" "$(task_mode "$owner_file")" "$owner_file"
  else
    emit "owner" "$task_id" "" "$(task_branch_name "$candidate_file" "$task_id")" "" "$(canonical_mode "$requested_mode")" "$candidate_file"
  fi
  exit 0
fi

if [ "$declared_parent" = "$task_id" ]; then
  echo "Task $task_id cannot declare itself as its parent." >&2
  exit 1
fi

parent_info="$(resolve_parent "$declared_parent")"
IFS=$'\t' read -r owner_root owner_branch owner_file <<< "$parent_info"
effective_mode="$(task_mode "$owner_file")"
if [ -n "$requested_mode" ] && [ "$(canonical_mode "$requested_mode")" != "$effective_mode" ]; then
  echo "Child task $task_id must inherit parent task $declared_parent mode $effective_mode; requested mode conflicts." >&2
  exit 1
fi
emit "child" "$task_id" "$declared_parent" "$owner_branch" "$owner_root" "$effective_mode" "$candidate_file"
