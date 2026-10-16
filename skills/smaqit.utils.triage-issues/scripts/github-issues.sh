#!/usr/bin/env bash
# Compact GitHub REST client for smaqit.utils.triage-issues.
# Emits only the fields the triage decision needs; diagnostics go to stderr.
set -euo pipefail

DEFAULT_API_BASE='https://api.github.com'
API_BASE="${SMAQIT_GITHUB_API_BASE:-$DEFAULT_API_BASE}"
API_BASE="${API_BASE%/}"

# Exit statuses: 1 general failure, 2 usage, 3 rate limited.
fail() {
  printf 'triage GitHub helper: %s\n' "$*" >&2
  exit 1
}

fail_rate_limited() {
  printf 'triage GitHub helper: rate limited: %s\n' "$*" >&2
  exit 3
}

require_dependencies() {
  command -v curl >/dev/null 2>&1 || fail 'curl is required'
  command -v jq >/dev/null 2>&1 || fail 'jq is required'
}

urlencode() {
  jq -rn --arg value "$1" '$value | @uri'
}

validate_repo() {
  [[ "$1" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || fail 'repository must be owner/repo'
}

# Token precedence: SMAQIT_GITHUB_TOKEN, then (only for the default API base)
# GH_TOKEN, GITHUB_TOKEN, `gh auth token`. Ambient credentials are never sent
# to an overridden SMAQIT_GITHUB_API_BASE.
resolve_token() {
  if [[ -n "${SMAQIT_GITHUB_TOKEN:-}" ]]; then
    printf '%s' "$SMAQIT_GITHUB_TOKEN"
  elif [[ "$API_BASE" != "$DEFAULT_API_BASE" ]]; then
    return 0
  elif [[ -n "${GH_TOKEN:-}" ]]; then
    printf '%s' "$GH_TOKEN"
  elif [[ -n "${GITHUB_TOKEN:-}" ]]; then
    printf '%s' "$GITHUB_TOKEN"
  elif command -v gh >/dev/null 2>&1; then
    gh auth token 2>/dev/null || true
  fi
}

header_value() {
  local name="$1" file="$2"
  awk -v name="$name" '
    { line = $0; sub(/\r$/, "", line) }
    line ~ /^HTTP\// { found = "" }
    tolower(substr(line, 1, length(name) + 1)) == tolower(name) ":" {
      value = substr(line, length(name) + 2); gsub(/^[ \t]+|[ \t]+$/, "", value); found = value
    }
    END { if (found != "") print found }' "$file"
}

rate_limit_check() {
  local status="$1" headers_file="$2" remaining reset retry_after detail
  remaining="$(header_value x-ratelimit-remaining "$headers_file")"
  retry_after="$(header_value retry-after "$headers_file")"
  [[ "$status" == 429 || ( "$status" == 403 && ( "$remaining" == 0 || -n "$retry_after" ) ) ]] || return 0

  detail="HTTP $status"
  [[ -n "$remaining" ]] && detail+=", X-RateLimit-Remaining: $remaining"
  reset="$(header_value x-ratelimit-reset "$headers_file")"
  if [[ "$reset" =~ ^[0-9]+$ ]]; then
    detail+=", resets at $(jq -rn --argjson t "$reset" '$t | todate')"
  fi
  [[ -n "$retry_after" ]] && detail+=", retry after ${retry_after}s"
  [[ -n "$TOKEN" ]] || detail+='; request was unauthenticated (set GH_TOKEN or run gh auth login)'
  fail_rate_limited "$detail"
}

fetch_json() {
  local path="$1"
  local response_file headers_file status
  response_file="$(mktemp)"
  headers_file="$(mktemp)"
  trap 'rm -f "$response_file" "$headers_file"' RETURN

  # The token reaches curl through a stdin config, never the argument list.
  local -a curl_args=(--silent --show-error --location --output "$response_file" --dump-header "$headers_file"
    --write-out '%{http_code}' -H 'Accept: application/vnd.github+json')
  if [[ -n "$TOKEN" ]]; then
    status="$(printf 'header = "Authorization: Bearer %s"\n' "$TOKEN" \
      | curl --config - "${curl_args[@]}" -- "$API_BASE$path")" || fail 'request failed'
  else
    status="$(curl "${curl_args[@]}" -- "$API_BASE$path")" || fail 'request failed'
  fi

  rate_limit_check "$status" "$headers_file"
  [[ "$status" =~ ^2[0-9][0-9]$ ]] || fail "HTTP $status"
  jq -e . "$response_file" >/dev/null 2>&1 || fail 'response was not valid JSON'
  cat "$response_file"
}

resolve() {
  local tool="$1" encoded
  encoded="$(urlencode "$tool")"
  local json
  json="$(fetch_json "/search/repositories?q=$encoded&per_page=1&page=1")" || exit $?
  jq -ce '{full_name: (.items[0].full_name // null)}' <<<"$json"
}

search() {
  local repo="$1" state="$2"
  shift 2
  validate_repo "$repo"
  [[ "$state" == 'open' || "$state" == 'closed' ]] || fail 'state must be open or closed'

  local terms query encoded
  terms="$*"
  query="repo:$repo is:issue"
  [[ -n "$terms" ]] && query+=" $terms"
  query+=" state:$state"
  encoded="$(urlencode "$query")"

  local json
  json="$(fetch_json "/search/issues?q=$encoded&per_page=10&page=1")" || exit $?
  jq -ce --arg state "$state" '{
        incomplete_results: (.incomplete_results // false),
        items: [(.items // [])[:10][] | {
          number,
          title,
          labels: [(.labels // [])[] | .name],
          html_url,
          state: (.state // $state),
          created_at,
          closed_at
        }]
      }' <<<"$json"
}

detail() {
  local repo="$1" number="$2"
  validate_repo "$repo"
  [[ "$number" =~ ^[1-9][0-9]*$ ]] || fail 'issue number must be a positive integer'

  local json
  json="$(fetch_json "/repos/$repo/issues/$number")" || exit $?
  jq -ce '{
        number,
        title,
        labels: [(.labels // [])[] | .name],
        html_url,
        state,
        created_at,
        closed_at,
        body_excerpt: ((.body // "")[0:1500])
      }' <<<"$json"
}

usage() {
  cat >&2 <<EOF
Usage: ${0##*/} resolve <tool> | search <owner/repo> <open|closed> [terms...] | detail <owner/repo> <number>

Output (compact JSON on stdout):
  resolve  {"full_name": "owner/repo" | null}
  search   {"incomplete_results": bool, "items": [{"number", "title", "labels": [names],
            "html_url", "state", "created_at", "closed_at"}]}   (at most 10 items)
  detail   {"number", "title", "labels": [names], "html_url", "state", "created_at",
            "closed_at", "body_excerpt"}   (excerpt at most 1,500 characters)

Exit status: 0 success, 1 failure, 2 usage, 3 rate limited. Diagnostics go to stderr;
on any non-zero status stdout is empty and must not be read as an empty result.

Authentication: SMAQIT_GITHUB_TOKEN, else (default API base only) GH_TOKEN,
GITHUB_TOKEN, or \`gh auth token\`. Unauthenticated requests are allowed.
EOF
  exit 2
}

[[ $# -ge 1 ]] || usage
require_dependencies
TOKEN="$(resolve_token)"

case "$1" in
  resolve)
    [[ $# -eq 2 ]] || usage
    resolve "$2"
    ;;
  search)
    [[ $# -ge 3 ]] || usage
    search "${@:2}"
    ;;
  detail)
    [[ $# -eq 3 ]] || usage
    detail "$2" "$3"
    ;;
  *)
    usage
    ;;
esac
