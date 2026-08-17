#!/usr/bin/env bash
# Hermetic checks for release-boundary detection: a reference implementation of
# smaqit.release-analysis' Step 1c/1d tag lookups, exercised against fixture
# repositories that reproduce real mixed-era release history, plus contract
# assertions that both boundary-consuming skills document the tag-primary
# algorithm and its fallbacks.
#
# The bug this guards against: under the PR-gated per-task release model, the
# string "Prepare release vX.Y.Z" only ever exists as a PR *title*. The merge
# commit GitHub writes reads "Merge pull request #NNN from owner/branch", which
# the old marker regex never matches — so boundary detection silently skipped
# back to the last pre-PR-gated release.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/smaqit-release-boundary.XXXXXX")"

cleanup() {
  rm -rf "$FIXTURE_ROOT"
}
trap cleanup EXIT

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

assert_contains() {
  local file="$1" pattern="$2" message="$3"
  rg -q --fixed-strings -- "$pattern" "$file" || fail "$message — expected [$pattern] in $file"
}

assert_eq() {
  local actual="$1" expected="$2" message="$3"
  [ "$actual" = "$expected" ] || fail "$message — expected [$expected], got [$actual]"
}

assert_ne() {
  local a="$1" b="$2" message="$3"
  [ "$a" != "$b" ] || fail "$message — both were [$a]"
}

# --- Fixture helpers -------------------------------------------------------

git_init_fixture() {
  local repo="$1"
  mkdir -p "$repo"
  git -C "$repo" init -q -b main
  git -C "$repo" config user.email "test@example.com"
  git -C "$repo" config user.name "Fixture"
  git -C "$repo" config commit.gpgsign false
  git -C "$repo" config tag.gpgsign false
}

commit() {
  local repo="$1" message="$2"
  echo "$RANDOM-$message" >> "$repo/log.txt"
  git -C "$repo" add -A
  git -C "$repo" commit -q -m "$message"
}

# Simulates a merged PR: a side branch merged with --no-ff carrying GitHub's
# own default merge message. Deliberately produces NO release-marker commit.
merge_pr() {
  local repo="$1" number="$2" branch="$3" work="$4"
  git -C "$repo" checkout -q -b "$branch"
  commit "$repo" "$work"
  git -C "$repo" checkout -q main
  git -C "$repo" merge -q --no-ff -m "Merge pull request #${number} from owner/${branch}" "$branch"
}

# --- Reference implementation of the FIXED Step 1c / 1d --------------------

boundary_tag() { git -C "$1" describe --tags --abbrev=0 "$2" 2>/dev/null; }
boundary_sha() { git -C "$1" rev-list -n1 "$2"; }
last_version() { git -C "$1" tag --merged "$2" --sort=-v:refname | head -1; }

# The pre-fix behaviour, retained so the test proves the bug rather than
# merely asserting the new code agrees with itself.
legacy_boundary_sha() {
  git -C "$1" log "$2" --format="%H %s" \
    | grep -iE "^[0-9a-f]+ (Prepare release|Release) v[0-9]+\.[0-9]+\.[0-9]+$" \
    | head -1 | cut -d' ' -f1
}

# --- Fixture 1: mixed-era history -----------------------------------------
# Batch-era releases (real marker commits) followed by a PR-gated release
# (merge commit only, no marker) — exactly this repository's own shape.

MIXED="$FIXTURE_ROOT/mixed-era"
git_init_fixture "$MIXED"

commit "$MIXED" "initial commit"
commit "$MIXED" "feat: alpha"
commit "$MIXED" "Release v1.0.0"                       # batch-era local release
git -C "$MIXED" tag -a v1.0.0 -m "Release v1.0.0"

commit "$MIXED" "feat: beta"
commit "$MIXED" "Prepare release v1.1.0"               # batch-era PR release
merge_pr "$MIXED" 5 "release/v1.1.0" "chore: bump"
git -C "$MIXED" tag -a v1.1.0 -m "Release v1.1.0"      # tag lands on the merge

commit "$MIXED" "feat: gamma"
merge_pr "$MIXED" 10 "task/030-widget" "feat: widget"  # PR-GATED: no marker
PR_GATED_MERGE="$(git -C "$MIXED" rev-parse HEAD)"
git -C "$MIXED" tag -a v1.2.0 -m "Release v1.2.0"

commit "$MIXED" "feat: delta"                          # unreleased work

fixed_tag="$(boundary_tag "$MIXED" HEAD)"
fixed_sha="$(boundary_sha "$MIXED" "$fixed_tag")"
legacy_sha="$(legacy_boundary_sha "$MIXED" HEAD)"

assert_eq "$fixed_tag" "v1.2.0" "tag lookup must find the PR-gated release, not the last marker commit"
assert_eq "$fixed_sha" "$PR_GATED_MERGE" "boundary must dereference to the PR-gated merge commit"
assert_eq "$(last_version "$MIXED" HEAD)" "v1.2.0" "last-version must be the highest reachable tag"

# Prove the bug actually existed: the old regex resolves somewhere else entirely.
assert_ne "$legacy_sha" "$fixed_sha" "regression guard: old marker regex must NOT agree with the tag lookup here"
legacy_subject="$(git -C "$MIXED" log -1 --format=%s "$legacy_sha")"
assert_eq "$legacy_subject" "Prepare release v1.1.0" "old regex is expected to skip back to the last marker commit"

echo "[PASS] mixed-era history: tag lookup finds the PR-gated release the marker regex skips"

# --- Fixture 1b: batch mode with an already-tagged tip ---------------------
# When the tip is itself the release, that tag must not also be the lower bound.

tip_tag="$(boundary_tag "$MIXED" "$PR_GATED_MERGE")"
assert_eq "$tip_tag" "v1.2.0" "a tagged tip describes as its own tag"
prev_tag="$(boundary_tag "$MIXED" "${PR_GATED_MERGE}^")"
assert_eq "$prev_tag" "v1.1.0" "stepping back one commit from a tagged tip yields the previous release"

echo "[PASS] batch mode: a tagged tip steps back to the previous release tag"

# --- Fixture 2: out-of-order tags -----------------------------------------
# Per-task releases claim versions before merging, and PRs merge in review
# order, not version order — so boundary (topological) and version baseline
# (numeric) legitimately disagree.

OOO="$FIXTURE_ROOT/out-of-order"
git_init_fixture "$OOO"

commit "$OOO" "initial commit"
git -C "$OOO" tag -a v2.0.0 -m "Release v2.0.0"

merge_pr "$OOO" 200 "task/200-minor" "feat: minor feature"
git -C "$OOO" tag -a v2.1.0 -m "Release v2.1.0"        # MINOR merges first

merge_pr "$OOO" 201 "task/201-patch" "fix: patch"
LATER_MERGE="$(git -C "$OOO" rev-parse HEAD)"
git -C "$OOO" tag -a v2.0.1 -m "Release v2.0.1"        # PATCH merges second

commit "$OOO" "feat: subsequent work"

ooo_boundary_tag="$(boundary_tag "$OOO" HEAD)"
ooo_last_version="$(last_version "$OOO" HEAD)"

assert_eq "$ooo_boundary_tag" "v2.0.1" "boundary must be the topologically latest tag"
assert_eq "$(boundary_sha "$OOO" "$ooo_boundary_tag")" "$LATER_MERGE" "boundary dereferences to the last-merged release"
assert_eq "$ooo_last_version" "v2.1.0" "last-version must be the highest-numbered tag, not the nearest one"
assert_ne "$ooo_boundary_tag" "$ooo_last_version" "the two lookups must be independent — this is the whole reason they are separate"

# Conflating them is what regresses the version baseline below a shipped release.
[ "$ooo_boundary_tag" = "v2.0.1" ] && [ "$ooo_last_version" = "v2.1.0" ] \
  || fail "out-of-order divergence not reproduced"

echo "[PASS] out-of-order tags: boundary and version baseline resolve independently"

# --- Fixture 3: tagless repository falls back to marker commits ------------

TAGLESS="$FIXTURE_ROOT/tagless"
git_init_fixture "$TAGLESS"

commit "$TAGLESS" "initial commit"
commit "$TAGLESS" "Release v0.1.0"
TAGLESS_MARKER="$(git -C "$TAGLESS" rev-parse HEAD)"
commit "$TAGLESS" "feat: post-release work"

[ -z "$(boundary_tag "$TAGLESS" HEAD)" ] || fail "tagless fixture unexpectedly resolved a tag"
assert_eq "$(legacy_boundary_sha "$TAGLESS" HEAD)" "$TAGLESS_MARKER" "tagless repo must fall back to the marker commit"

echo "[PASS] tagless repository falls back to marker-commit detection"

# --- Contract assertions: the skills document the fixed algorithm ----------

RELEASE_ANALYSIS="$SOURCE_ROOT/skills/smaqit.release-analysis/SKILL.md"
RELEASE_PREPARE="$SOURCE_ROOT/skills/smaqit.release-prepare-files/SKILL.md"

assert_contains "$RELEASE_ANALYSIS" 'git fetch --tags --force' "release-analysis fetches tags before resolving the boundary"
assert_contains "$RELEASE_ANALYSIS" 'git describe --tags --abbrev=0 origin/main' "release-analysis resolves the boundary from tags on origin/main"
assert_contains "$RELEASE_ANALYSIS" 'git rev-list -n1' "release-analysis dereferences the tag to a commit"
assert_contains "$RELEASE_ANALYSIS" 'git tag --merged origin/main --sort=-v:refname' "release-analysis derives last-version from the highest reachable tag"
assert_contains "$RELEASE_ANALYSIS" 'separate lookup from Step 1c' "release-analysis states that boundary and last-version are separate lookups"
assert_contains "$RELEASE_ANALYSIS" 'Fallback 1' "release-analysis retains a marker-commit fallback for tagless repositories"
assert_contains "$RELEASE_ANALYSIS" '(Prepare release|Release) v[0-9]+\.[0-9]+\.[0-9]+$' "release-analysis keeps the marker regex available as a fallback"

assert_contains "$RELEASE_PREPARE" 'git fetch --tags --force' "release-prepare-files fetches tags before resolving the boundary"
assert_contains "$RELEASE_PREPARE" 'git describe --tags --abbrev=0 origin/main' "release-prepare-files resolves the boundary from tags on origin/main"
assert_contains "$RELEASE_PREPARE" 'git rev-list -n1' "release-prepare-files dereferences the tag to a commit"

echo "[PASS] release-boundary detection contract"
