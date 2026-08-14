#!/usr/bin/env bash
# Inspect, project, and upsert one keyed task block without exposing a full research map.
set -euo pipefail

fail() { echo "task map: $*" >&2; exit 2; }
command_name="${1:-}"
shift || true

case "$command_name" in
  status)
    [ "$#" -eq 3 ] || fail "usage: task-map.sh status <map> <task-id> <fingerprint>"
    map_file="$1"; task_id="$2"; fingerprint="$3"
    [ -f "$map_file" ] || { jq -cn --arg status missing '{status: $status}'; exit 0; }
    found="$(awk -v task="^##[[:space:]]+Task[[:space:]]+$task_id[[:space:]]+—" -v fingerprint="$fingerprint" '
      $0 ~ task { in_task = 1; next }
      in_task && /^##[[:space:]]+/ { in_task = 0 }
      in_task && /^\*\*Context fingerprint:\*\*/ {
        value = $0; sub(/^\*\*Context fingerprint:\*\*[[:space:]]*/, "", value)
        print value; exit
      }
    ' "$map_file")"
    if [ -z "$found" ]; then
      jq -cn --arg status missing '{status: $status}'
    elif [ "$found" = "$fingerprint" ]; then
      jq -cn --arg status match --arg fingerprint "$found" '{status: $status, fingerprint: $fingerprint}'
    else
      jq -cn --arg status mismatch --arg fingerprint "$found" '{status: $status, fingerprint: $fingerprint}'
    fi
    ;;
  select)
    [ "$#" -eq 3 ] || fail "usage: task-map.sh select <map> <task-id> <fingerprint>"
    map_file="$1"; task_id="$2"; fingerprint="$3"
    [ -f "$map_file" ] || fail "map file not found"
    status="$(bash "$0" status "$map_file" "$task_id" "$fingerprint" | jq -r '.status')"
    [ "$status" = match ] || fail "task block is $status"
    awk -v task="^##[[:space:]]+Task[[:space:]]+$task_id[[:space:]]+—" '
      $0 ~ task { in_task = 1 }
      in_task && /^##[[:space:]]+/ && $0 !~ task { exit }
      in_task { print }
    ' "$map_file"
    ;;
  upsert)
    [ "$#" -eq 3 ] || fail "usage: task-map.sh upsert <map> <task-id> <block-file>"
    map_file="$1"; task_id="$2"; block_file="$3"
    [ -f "$map_file" ] || fail "map file not found"
    [ -f "$block_file" ] || fail "block file not found"
    case "$(head -n 1 "$block_file")" in "## Task $task_id — "*) ;; *) fail "block header must identify task $task_id" ;; esac
    temp_file="$(mktemp "${TMPDIR:-/tmp}/smaqit-task-map.XXXXXX")"
    trap 'rm -f "$temp_file"' EXIT
    awk -v task="^##[[:space:]]+Task[[:space:]]+$task_id[[:space:]]+—" '
      $0 ~ task { skip = 1; next }
      skip && /^##[[:space:]]+/ { skip = 0 }
      !skip { print }
    ' "$map_file" >"$temp_file"
    printf '\n' >>"$temp_file"
    sed -n '1,$p' "$block_file" >>"$temp_file"
    mv "$temp_file" "$map_file"
    trap - EXIT
    ;;
  *) fail "unknown command: $command_name" ;;
esac
