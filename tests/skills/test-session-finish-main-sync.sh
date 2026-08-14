#!/usr/bin/env bash
# Hermetic contract tests for smaqit.session-finish's main-branch finalize helper.
# Exercises every branching condition against local git fixtures — no real remote is contacted.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HELPER="$SOURCE_ROOT/skills/smaqit.session-finish/scripts/finalize-main.sh"
SESSION_FINISH_SKILL="$SOURCE_ROOT/skills/smaqit.session-finish/SKILL.md"
FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/smaqit-session-finish.XXXXXX")"
ORIGIN_DIR="$FIXTURE_ROOT/origin.git"
PRIMARY_DIR="$FIXTURE_ROOT/primary"
OTHER_DIR="$FIXTURE_ROOT/other"
CAPTURE_OUT="$FIXTURE_ROOT/capture.out"
CAPTURE_ERR="$FIXTURE_ROOT/capture.err"

cleanup() {
  rm -rf "$FIXTURE_ROOT"
}
trap cleanup EXIT

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

assert_contains() {
  local value="$1" expected="$2" message="$3"
  case "$value" in
    *"$expected"*) ;;
    *) fail "$message — expected [$expected]" ;;
  esac
}

assert_eq() {
  local actual="$1" expected="$2" message="$3"
  [ "$actual" = "$expected" ] || fail "$message (expected [$expected], got [$actual])"
}

# --- SKILL.md contract assertions -------------------------------------------

assert_contains "$(<"$SESSION_FINISH_SKILL")" 'scripts/finalize-main.sh' "session-finish routes Step 7 through the deterministic helper"
assert_contains "$(<"$SESSION_FINISH_SKILL")" 'never run its underlying git commands directly' "session-finish forbids bypassing the helper"
assert_contains "$(<"$SESSION_FINISH_SKILL")" 'session.finish --autonomous' "session-finish documents the autonomous invocation form"
assert_contains "$(<"$SESSION_FINISH_SKILL")" 'do not retry, do not force-push' "session-finish forbids retrying or forcing a rejected push"
assert_contains "$(<"$SESSION_FINISH_SKILL")" 'never substitute `git add -A`' "session-finish forbids broad staging"

# --- Fixture setup -----------------------------------------------------------

git init --bare -q -b main "$ORIGIN_DIR"

git init -q -b main "$PRIMARY_DIR"
git -C "$PRIMARY_DIR" config user.email "primary@example.test"
git -C "$PRIMARY_DIR" config user.name "Primary"
git -C "$PRIMARY_DIR" remote add origin "$ORIGIN_DIR"
echo "root" >"$PRIMARY_DIR/root.txt"
git -C "$PRIMARY_DIR" add root.txt
git -C "$PRIMARY_DIR" commit -q -m "chore: initial commit"
git -C "$PRIMARY_DIR" push -q -u origin main

git clone -q "$ORIGIN_DIR" "$OTHER_DIR"
git -C "$OTHER_DIR" config user.email "other@example.test"
git -C "$OTHER_DIR" config user.name "Other"

run_helper() {
  ( cd "$PRIMARY_DIR" && bash "$HELPER" "$@" )
}

reset_primary() {
  git -C "$PRIMARY_DIR" merge --abort >/dev/null 2>&1 || true
  git -C "$PRIMARY_DIR" checkout -q main
  git -C "$PRIMARY_DIR" fetch -q origin main
  git -C "$PRIMARY_DIR" reset -q --hard origin/main
  git -C "$PRIMARY_DIR" clean -q -fdx
}

# --- detect: clean main, up to date -----------------------------------------

detect_out="$(run_helper detect)"
assert_eq "$(printf '%s' "$detect_out" | jq -r '.state')" "on_main" "detect reports on_main at baseline"
assert_eq "$(printf '%s' "$detect_out" | jq -r '.dirty')" "false" "detect reports a clean tree at baseline"

sync_out="$(run_helper sync)"
assert_eq "$(printf '%s' "$sync_out" | jq -r '.sync')" "up_to_date" "sync reports up_to_date when local matches origin"

# --- detect: clean non-main branch, then checkout-main ----------------------

git -C "$PRIMARY_DIR" checkout -q -b feature/clean
detect_out="$(run_helper detect)"
assert_eq "$(printf '%s' "$detect_out" | jq -r '.state')" "clean_non_main" "detect reports clean_non_main on a clean feature branch"
assert_eq "$(printf '%s' "$detect_out" | jq -r '.branch')" "feature/clean" "detect reports the actual branch name"

checkout_out="$(run_helper checkout-main)"
assert_eq "$(printf '%s' "$checkout_out" | jq -r '.checked_out')" "main" "checkout-main switches to main"
assert_eq "$(git -C "$PRIMARY_DIR" branch --show-current)" "main" "primary is actually on main after checkout-main"

reset_primary

# --- detect: dirty non-main branch — checkout-main must refuse --------------

git -C "$PRIMARY_DIR" checkout -q -b feature/dirty
echo "wip" >"$PRIMARY_DIR/wip.txt"
detect_out="$(run_helper detect)"
assert_eq "$(printf '%s' "$detect_out" | jq -r '.state')" "dirty_non_main" "detect reports dirty_non_main with an uncommitted file"

if run_helper checkout-main >"$CAPTURE_OUT" 2>"$CAPTURE_ERR"; then
  fail "checkout-main must refuse a dirty non-main branch"
fi
assert_contains "$(cat "$CAPTURE_ERR")" "dirty" "checkout-main reports why it refused"
assert_eq "$(git -C "$PRIMARY_DIR" branch --show-current)" "feature/dirty" "checkout-main took no action on refusal"

reset_primary

# --- detect: detached HEAD ---------------------------------------------------

git -C "$PRIMARY_DIR" checkout -q --detach main
detect_out="$(run_helper detect)"
assert_eq "$(printf '%s' "$detect_out" | jq -r '.state')" "detached_head" "detect reports detached_head"

reset_primary

# --- detect: merge conflict in progress --------------------------------------

git -C "$PRIMARY_DIR" checkout -q -b conflict-source
echo "source version" >"$PRIMARY_DIR/root.txt"
git -C "$PRIMARY_DIR" commit -q -am "conflict: source change"
git -C "$PRIMARY_DIR" checkout -q main
echo "main version" >"$PRIMARY_DIR/root.txt"
git -C "$PRIMARY_DIR" commit -q -am "conflict: main change"
git -C "$PRIMARY_DIR" merge conflict-source >/dev/null 2>&1 || true

detect_out="$(run_helper detect)"
assert_eq "$(printf '%s' "$detect_out" | jq -r '.state')" "merge_in_progress" "detect reports merge_in_progress during an unresolved conflict"

git -C "$PRIMARY_DIR" merge --abort >/dev/null 2>&1 || true
git -C "$PRIMARY_DIR" checkout -q main
git -C "$PRIMARY_DIR" reset -q --hard origin/main
git -C "$PRIMARY_DIR" branch -q -D conflict-source

# --- sync: fast-forward when behind only -------------------------------------

echo "upstream change" >"$OTHER_DIR/other.txt"
git -C "$OTHER_DIR" add other.txt
git -C "$OTHER_DIR" commit -q -m "chore: upstream-only change"
git -C "$OTHER_DIR" push -q origin main

sync_out="$(run_helper sync)"
assert_eq "$(printf '%s' "$sync_out" | jq -r '.sync')" "fast_forwarded" "sync fast-forwards when only behind"
assert_eq "$(git -C "$PRIMARY_DIR" rev-parse main)" "$(git -C "$OTHER_DIR" rev-parse main)" "primary matches origin after fast-forward"

reset_primary

# --- sync: diverged history never merges/rebases -----------------------------

before_sha="$(git -C "$PRIMARY_DIR" rev-parse main)"
echo "primary-only change" >"$PRIMARY_DIR/primary-only.txt"
git -C "$PRIMARY_DIR" add primary-only.txt
git -C "$PRIMARY_DIR" commit -q -m "chore: primary-only change"
primary_ahead_sha="$(git -C "$PRIMARY_DIR" rev-parse main)"

echo "other-only change" >"$OTHER_DIR/other-only.txt"
git -C "$OTHER_DIR" add other-only.txt
git -C "$OTHER_DIR" commit -q -m "chore: other-only change"
git -C "$OTHER_DIR" push -q origin main

[ "$primary_ahead_sha" != "$before_sha" ] || fail "sanity: primary should have advanced locally before the diverge check"

sync_out="$(run_helper sync)"
assert_eq "$(printf '%s' "$sync_out" | jq -r '.sync')" "diverged" "sync reports diverged when both ahead and behind"
assert_eq "$(printf '%s' "$sync_out" | jq -r '.ahead')" "1" "sync reports the correct ahead count"
assert_eq "$(printf '%s' "$sync_out" | jq -r '.behind')" "1" "sync reports the correct behind count"
assert_eq "$(git -C "$PRIMARY_DIR" rev-parse main)" "$primary_ahead_sha" "diverged sync never mutates local main (no merge/rebase commit created)"

reset_primary

# --- commit: stages only the exact paths given -------------------------------

echo "known change" >"$PRIMARY_DIR/known.txt"
echo "unrelated change" >"$PRIMARY_DIR/unrelated.txt"

commit_out="$(run_helper commit "chore: session housekeeping — known.txt only" known.txt)"
assert_eq "$(printf '%s' "$commit_out" | jq -r '.committed')" "true" "commit reports success"
assert_eq "$(git -C "$PRIMARY_DIR" status --porcelain -- known.txt)" "" "the known path is committed and clean"
assert_contains "$(git -C "$PRIMARY_DIR" status --porcelain -- unrelated.txt)" "??" "the unrelated path is left untouched, still untracked"

git -C "$PRIMARY_DIR" push -q origin main
reset_primary

# --- push: success when ahead and not diverged -------------------------------

echo "ready to push" >"$PRIMARY_DIR/ready.txt"
git -C "$PRIMARY_DIR" add ready.txt
git -C "$PRIMARY_DIR" commit -q -m "chore: ready to push"

push_out="$(run_helper push)"
assert_eq "$(printf '%s' "$push_out" | jq -r '.pushed')" "true" "push reports success"
assert_eq "$(git --git-dir="$ORIGIN_DIR" rev-parse main)" "$(git -C "$PRIMARY_DIR" rev-parse main)" "origin now matches primary after push"

reset_primary

# --- push: rejected race never retries or forces -----------------------------

echo "primary race change" >"$PRIMARY_DIR/race-primary.txt"
git -C "$PRIMARY_DIR" add race-primary.txt
git -C "$PRIMARY_DIR" commit -q -m "chore: primary race change"

# OTHER_DIR was cloned once at the start and never kept in sync with the
# pushes primary made in later scenarios — fast-forward it to the real
# current tip first so its own push below is a clean fast-forward.
git -C "$OTHER_DIR" fetch -q origin main
git -C "$OTHER_DIR" reset -q --hard origin/main
echo "other race change" >"$OTHER_DIR/race-other.txt"
git -C "$OTHER_DIR" add race-other.txt
git -C "$OTHER_DIR" commit -q -m "chore: other race change"
git -C "$OTHER_DIR" push -q origin main
winning_sha="$(git -C "$OTHER_DIR" rev-parse main)"

if run_helper push >"$CAPTURE_OUT" 2>"$CAPTURE_ERR"; then
  fail "push must be rejected when origin has diverged"
fi
assert_contains "$(cat "$CAPTURE_ERR")" "push rejected" "push reports a concise rejection reason"
assert_eq "$(git --git-dir="$ORIGIN_DIR" rev-parse main)" "$winning_sha" "a rejected push never overwrites origin"

echo "[PASS] session-finish main-branch finalize contract"
