#!/usr/bin/env bash
# .smaqit/hooks/pre-commit-confidentiality.sh — confidentiality scan gate.
#
# Installed and force-overwritten by `smaqit-extensions init`/`update` on
# every run — pattern and bug fixes must propagate, so do not hand-edit this
# file; edits are lost on the next install. To exclude a path, add it to
# .smaqit/hooks/confidentiality-scan-ignore instead (seeded once, never
# overwritten again).
#
# Scans staged content (`git show :<path>`, not the working tree) for
# credential, PII, and financial-figure patterns and blocks the commit
# (non-zero exit) on any hit, reporting file, line, and category — never the
# matched text itself. Delta-scoped: only files actually part of this commit
# are checked (git diff --cached --diff-filter=ACM), so a pre-existing
# violation elsewhere in the tree never blocks an unrelated commit.
#
# This is a coarse, cross-project, cross-language net — not a content-aware
# classifier. A hit's remediation is: exclude the path after review, remove
# the sensitive content, or bypass with `git commit --no-verify` (the next
# scan still reports it).
#
# Requires bash 3.2+ (the macOS system default) — no associative arrays, no
# `${var,,}`, no `mapfile`/`readarray`, no globstar.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

IGNORE_FILE=".smaqit/hooks/confidentiality-scan-ignore"

# Built-in excludes: VCS internals, common build/dependency directories, and
# lockfiles — their long hash-like strings are a concrete false-positive
# source against the credential patterns below. A project adds its own
# exclusions via IGNORE_FILE instead of editing this list.
DEFAULT_EXCLUDE_REGEX='(^|/)\.git/|(^|/)node_modules/|(^|/)vendor/|(^|/)\.venv/|(^|/)venv/|(^|/)__pycache__/|(^|/)dist/|(^|/)build/|(^|/)target/|(^|/)\.next/|(^|/)package-lock\.json$|(^|/)yarn\.lock$|(^|/)Cargo\.lock$|(^|/)go\.sum$'

# Pattern set ported (independently reimplemented, not shared code) from
# agentic-cms's ac-classify heuristic floor — parallel indexed arrays, since
# bash 3.2 has no associative arrays. Each entry: category, grep case flag
# ("i" or ""), ERE pattern. The floor's contract is recall, not precision —
# patterns are intentionally broad; a false positive is resolved via
# IGNORE_FILE, never by narrowing a pattern here.
PATTERN_CATEGORIES=(CREDENTIAL CREDENTIAL CREDENTIAL CREDENTIAL CREDENTIAL FINANCIAL FINANCIAL FINANCIAL FINANCIAL FINANCIAL PII PII)
PATTERN_FLAGS=(     ""         ""         ""         ""         "i"       ""        ""        ""        ""        "i"       ""  "")
PATTERN_REGEX=(
  '-----BEGIN [A-Z ]*PRIVATE KEY-----'
  'sk-[A-Za-z0-9]{16,}'
  'AKIA[0-9A-Z]{16}'
  'gh[pousr]_[A-Za-z0-9]{20,}'
  "(api[_-]?key|secret|password|token)[[:space:]]*[:=][[:space:]]*[\"']?[A-Za-z0-9_-]{12,}"
  '[$€£][[:space:]]?[0-9][0-9,]*(\.[0-9]+)?'
  '[0-9][0-9,]*(\.[0-9]+)?[[:space:]]?[$€£]'
  '(USD|EUR|GBP|CHF|JPY|CNY|CAD|AUD|NZD|SEK|NOK|DKK|BRL|INR|MXN|ZAR)[[:space:]]?[0-9][0-9,]*(\.[0-9]+)?'
  '[0-9][0-9,]*(\.[0-9]+)?[[:space:]]?(USD|EUR|GBP|CHF|JPY|CNY|CAD|AUD|NZD|SEK|NOK|DKK|BRL|INR|MXN|ZAR)'
  '[0-9][0-9,]*(\.[0-9]+)?[[:space:]](dollars|euros|pounds|francs|yen)'
  '[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+\.[A-Za-z]{2,}'
  '[0-9]{3}-[0-9]{2}-[0-9]{4}'
)

is_excluded() {
  local path="$1"
  if [[ "$path" =~ $DEFAULT_EXCLUDE_REGEX ]]; then
    return 0
  fi
  [ -f "$IGNORE_FILE" ] || return 1

  local pattern
  while IFS= read -r pattern || [ -n "$pattern" ]; do
    pattern="${pattern%$'\r'}"
    [ -z "$pattern" ] && continue
    case "$pattern" in
      \#*) continue ;;
    esac
    if [ "${pattern%/}" != "$pattern" ]; then
      case "$path" in
        "${pattern}"*|*"/${pattern}"*) return 0 ;;
      esac
    else
      case "$path" in
        $pattern|*/$pattern) return 0 ;;
      esac
    fi
  done <"$IGNORE_FILE"
  return 1
}

is_binary() {
  local path="$1" numstat added
  numstat="$(git diff --cached --numstat --diff-filter=ACM -- "$path" 2>/dev/null || true)"
  added="${numstat%%$'\t'*}"
  [ "$added" = "-" ]
}

STAGED_FILES="$(git diff --cached --name-only --diff-filter=ACM)"
[ -z "$STAGED_FILES" ] && exit 0

violations=()

while IFS= read -r path; do
  [ -z "$path" ] && continue
  is_excluded "$path" && continue
  is_binary "$path" && continue

  content="$(git show ":$path" 2>/dev/null || true)"
  [ -z "$content" ] && continue

  i=0
  while [ "$i" -lt "${#PATTERN_REGEX[@]}" ]; do
    category="${PATTERN_CATEGORIES[$i]}"
    flag="${PATTERN_FLAGS[$i]}"
    regex="${PATTERN_REGEX[$i]}"
    if [ "$flag" = "i" ]; then
      matches="$(printf '%s\n' "$content" | grep -inE -- "$regex" || true)"
    else
      matches="$(printf '%s\n' "$content" | grep -nE -- "$regex" || true)"
    fi
    if [ -n "$matches" ]; then
      while IFS= read -r m; do
        [ -z "$m" ] && continue
        violations+=("$path:${m%%:*}:$category")
      done <<<"$matches"
    fi
    i=$((i + 1))
  done
done <<<"$STAGED_FILES"

if [ "${#violations[@]}" -gt 0 ]; then
  echo "pre-commit: confidentiality scan BLOCKED this commit:" >&2
  for v in "${violations[@]}"; do
    rest="${v#*:}"
    echo "  - ${v%%:*}:${rest%%:*} — possible ${rest#*:}" >&2
  done
  echo "" >&2
  echo "Fix the above, exclude a reviewed false positive in $IGNORE_FILE, or bypass with 'git commit --no-verify' (the next scan still reports it)." >&2
  exit 1
fi

exit 0
