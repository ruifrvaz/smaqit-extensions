#!/usr/bin/env bash
# Compact GitHub REST client for smaqit.utils.triage-issues.
# Emits only the fields the triage decision needs; diagnostics go to stderr.
set -euo pipefail

API_BASE="${SMAQIT_GITHUB_API_BASE:-https://api.github.com}"
API_BASE="${API_BASE%/}"

fail() {
  printf 'triage GitHub helper: %s\n' "$*" >&2
  exit 1
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

fetch_json() {
  local path="$1"
  local response_file status
  response_file="$(mktemp)"
  trap 'rm -f "$response_file"' RETURN

  if ! status="$(curl --silent --show-error --location --output "$response_file" --write-out '%{http_code}' \
    -H 'Accept: application/vnd.github+json' -- "$API_BASE$path")"; then
    fail 'request failed'
  fi

  [[ "$status" =~ ^2[0-9][0-9]$ ]] || fail "HTTP $status"
  jq -e . "$response_file" >/dev/null 2>&1 || fail 'response was not valid JSON'
  cat "$response_file"
}

resolve() {
  local tool="$1" encoded
  encoded="$(urlencode "$tool")"
  fetch_json "/search/repositories?q=$encoded&per_page=1&page=1" \
    | jq -ce '{full_name: (.items[0].full_name // null)}'
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

  fetch_json "/search/issues?q=$encoded&per_page=10&page=1" \
    | jq -ce --arg state "$state" '{
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
      }'
}

detail() {
  local repo="$1" number="$2"
  validate_repo "$repo"
  [[ "$number" =~ ^[1-9][0-9]*$ ]] || fail 'issue number must be a positive integer'

  fetch_json "/repos/$repo/issues/$number" \
    | jq -ce '{
        number,
        title,
        labels: [(.labels // [])[] | .name],
        html_url,
        state,
        created_at,
        closed_at,
        body_excerpt: ((.body // "")[0:1500])
      }'
}

usage() {
  printf 'Usage: %s resolve <tool> | search <owner/repo> <open|closed> [terms...] | detail <owner/repo> <number>\n' "${0##*/}" >&2
  exit 2
}

require_dependencies
[[ $# -ge 1 ]] || usage

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
