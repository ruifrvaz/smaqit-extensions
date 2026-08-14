#!/usr/bin/env bash
# Deterministic git helper for smaqit.session-finish's main-branch finalize step.
# Every subcommand resolves the primary checkout from the caller's cwd via
# `git worktree list --porcelain` and never mutates a branch other than main.
set -euo pipefail

fail() {
  printf 'session-finish finalize: %s\n' "$*" >&2
  exit 1
}

require_git_repo() {
  git rev-parse --show-toplevel >/dev/null 2>&1 || fail 'not a git repository'
}

primary_root() {
  # git worktree list --porcelain always lists the primary checkout first.
  local root
  root="$(git worktree list --porcelain | awk '/^worktree /{print $2; exit}')"
  [ -n "$root" ] || fail 'could not resolve primary checkout'
  printf '%s' "$root"
}

detect() {
  local root branch porcelain
  root="$(primary_root)"
  cd "$root"

  if ! git symbolic-ref -q HEAD >/dev/null; then
    printf '{"state":"detached_head","root":%s}\n' "$(printf '%s' "$root" | jq -Rs .)"
    return 0
  fi

  branch="$(git branch --show-current)"

  if [ -e "$(git rev-parse --git-dir)/MERGE_HEAD" ]; then
    printf '{"state":"merge_in_progress","root":%s,"branch":"%s"}\n' "$(printf '%s' "$root" | jq -Rs .)" "$branch"
    return 0
  fi

  porcelain="$(git status --porcelain)"

  if printf '%s\n' "$porcelain" | grep -Eq '^(UU|AA|DD|AU|UA|UD|DU) '; then
    printf '{"state":"conflict_markers","root":%s,"branch":"%s"}\n' "$(printf '%s' "$root" | jq -Rs .)" "$branch"
    return 0
  fi

  if [ "$branch" != "main" ]; then
    if [ -n "$porcelain" ]; then
      printf '{"state":"dirty_non_main","root":%s,"branch":"%s"}\n' "$(printf '%s' "$root" | jq -Rs .)" "$branch"
    else
      printf '{"state":"clean_non_main","root":%s,"branch":"%s"}\n' "$(printf '%s' "$root" | jq -Rs .)" "$branch"
    fi
    return 0
  fi

  if [ -n "$porcelain" ]; then
    printf '{"state":"on_main","root":%s,"dirty":true}\n' "$(printf '%s' "$root" | jq -Rs .)"
  else
    printf '{"state":"on_main","root":%s,"dirty":false}\n' "$(printf '%s' "$root" | jq -Rs .)"
  fi
}

checkout_main() {
  local root branch
  root="$(primary_root)"
  cd "$root"
  branch="$(git branch --show-current 2>/dev/null || true)"
  [ "$branch" != "main" ] || fail 'already on main'
  [ -z "$(git status --porcelain)" ] || fail 'refusing to checkout main: working tree is dirty'
  git checkout main >/dev/null 2>&1 || fail 'checkout main failed'
  printf '{"checked_out":"main","from":"%s"}\n' "$branch"
}

commit_paths() {
  local root message
  root="$(primary_root)"
  cd "$root"
  [ "$(git branch --show-current)" = "main" ] || fail 'not on main'
  [ "$#" -ge 2 ] || fail 'usage: commit <message> <path> [path...]'
  message="$1"
  shift
  git add -- "$@"
  git commit -q -m "$message" || fail 'commit failed'
  printf '{"committed":true,"message":%s}\n' "$(printf '%s' "$message" | jq -Rs .)"
}

sync_main() {
  local root counts ahead behind err_file
  root="$(primary_root)"
  cd "$root"
  [ "$(git branch --show-current)" = "main" ] || fail 'not on main'

  err_file="$(mktemp)"
  trap 'rm -f "$err_file"' RETURN
  git fetch origin main >/dev/null 2>"$err_file" || fail "fetch failed: $(cat "$err_file")"

  counts="$(git rev-list --left-right --count main...origin/main)"
  ahead="$(printf '%s' "$counts" | awk '{print $1}')"
  behind="$(printf '%s' "$counts" | awk '{print $2}')"

  if [ "$ahead" = 0 ] && [ "$behind" = 0 ]; then
    printf '{"sync":"up_to_date","ahead":0,"behind":0}\n'
  elif [ "$ahead" = 0 ] && [ "$behind" -gt 0 ]; then
    git pull --ff-only origin main >/dev/null 2>"$err_file" || fail "fast-forward pull failed unexpectedly: $(cat "$err_file")"
    printf '{"sync":"fast_forwarded","ahead":0,"behind":%s}\n' "$behind"
  elif [ "$ahead" -gt 0 ] && [ "$behind" = 0 ]; then
    printf '{"sync":"ahead","ahead":%s,"behind":0}\n' "$ahead"
  else
    printf '{"sync":"diverged","ahead":%s,"behind":%s}\n' "$ahead" "$behind"
  fi
}

push_main() {
  local root err_file
  root="$(primary_root)"
  cd "$root"
  [ "$(git branch --show-current)" = "main" ] || fail 'not on main'

  err_file="$(mktemp)"
  trap 'rm -f "$err_file"' RETURN
  if git push origin main >/dev/null 2>"$err_file"; then
    printf '{"pushed":true}\n'
  else
    fail "push rejected: $(cat "$err_file")"
  fi
}

usage() {
  printf 'Usage: %s detect | checkout-main | commit <message> <path...> | sync | push\n' "${0##*/}" >&2
  exit 2
}

require_git_repo
[ "$#" -ge 1 ] || usage

case "$1" in
  detect) detect ;;
  checkout-main) checkout_main ;;
  commit) shift; commit_paths "$@" ;;
  sync) sync_main ;;
  push) push_main ;;
  *) usage ;;
esac
