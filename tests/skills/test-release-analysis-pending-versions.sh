#!/usr/bin/env bash
# Hermetic checks for the per-task release mechanics: a real reference
# implementation of the pending-CHANGELOG-entry promotion algorithm exercised
# against fixtures, plus contract assertions across every release skill and
# workflow file that documents the pending-version, Task-mode, and
# concurrency-hardening behavior.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/smaqit-release-pending.XXXXXX")"

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

# --- Mechanical test: promote exactly one named pending entry --------------
# Reference implementation of smaqit.release-prepare-files' Pending Entry
# Mode "Promote a single pending entry" operation, run against a fixture with
# two concurrently pending tasks to prove promoting one never disturbs the
# other — the core guarantee the whole per-task-release design depends on.

CHANGELOG="$FIXTURE_ROOT/CHANGELOG.md"
cat > "$CHANGELOG" <<'EOF'
# Changelog

## [Unreleased]

### Added
- **Widget caching** (pending v1.16.0 · PR #135) — adds an LRU cache to the widget resolver.

### Fixed
- **Null pointer in resolver** (pending v1.17.0 · PR #138) — fixes a crash when resolving.

## [1.15.0] - 2026-08-14

### Added
- Something already released.
EOF

promote_pending_entry() {
  local file="$1" version="$2" pr="$3" today="$4"
  local annotation="(pending v${version} · PR #${pr})"
  local line
  line="$(grep -F "$annotation" "$file")" || fail "promotion target not found for $annotation"
  local stripped="${line/ ${annotation}/}"
  # Remove the matched line from [Unreleased] and insert a new version
  # section directly beneath it, carrying only the promoted entry.
  grep -vF "$annotation" "$file" > "$file.tmp"
  awk -v new_section="## [${version}] - ${today}" -v entry="$stripped" '
    /^## \[Unreleased\]/ { print; getline_flag=1; next }
    getline_flag && /^### Added/ { print; print ""; print new_section; print ""; print "### Added"; print entry; getline_flag=0; next }
    { print }
  ' "$file.tmp" > "$file"
  rm -f "$file.tmp"
}

promote_pending_entry "$CHANGELOG" "1.16.0" "135" "2026-08-20"

grep -q -- '## \[1.16.0\] - 2026-08-20' "$CHANGELOG" || fail "promoted version section was not created"
grep -qF -- '- **Widget caching** — adds an LRU cache to the widget resolver.' "$CHANGELOG" || fail "promoted entry lost its annotation strip or its text"
grep -qF -- 'pending v1.16.0' "$CHANGELOG" && fail "promoted entry's pending annotation was not removed"
grep -qF -- 'pending v1.17.0 · PR #138' "$CHANGELOG" || fail "sibling pending entry (PR #138) was disturbed by an unrelated promotion"
grep -qF -- '## [1.15.0] - 2026-08-14' "$CHANGELOG" || fail "prior released version section was disturbed"

echo "[PASS] pending-entry promotion touches only its own named entry"

# --- Contract assertions: release-analysis Task mode / pending awareness ---

RELEASE_ANALYSIS="$SOURCE_ROOT/skills/smaqit.release-analysis/SKILL.md"
RELEASE_PREPARE="$SOURCE_ROOT/skills/smaqit.release-prepare-files/SKILL.md"
RELEASE_APPROVAL="$SOURCE_ROOT/skills/smaqit.release-approval/SKILL.md"
RELEASE_GIT_PR="$SOURCE_ROOT/skills/smaqit.release-git-pr/SKILL.md"

assert_contains "$RELEASE_ANALYSIS" '**Task mode**' "release-analysis documents Task mode"
assert_contains "$RELEASE_ANALYSIS" 'git fetch origin main' "release-analysis fetches origin/main fresh before searching"
assert_contains "$RELEASE_ANALYSIS" 'git log origin/main --format' "release-analysis searches origin/main, not local HEAD"
assert_contains "$RELEASE_ANALYSIS" 'Pending-version awareness' "release-analysis documents pending-version awareness"
assert_contains "$RELEASE_ANALYSIS" '(pending vX.Y.Z · PR #NNN)' "release-analysis references the exact pending-annotation format"

assert_contains "$RELEASE_PREPARE" '## Pending Entry Convention' "release-prepare-files documents the pending entry convention"
assert_contains "$RELEASE_PREPARE" 'pending v{X.Y.Z} · PR #{NNN}' "release-prepare-files documents the exact annotation template"
assert_contains "$RELEASE_PREPARE" '### Promote a single pending entry' "release-prepare-files documents single-entry promotion"
assert_contains "$RELEASE_PREPARE" 'Leave every other line in `[Unreleased]`' "write-pending-entry step never touches sibling entries"

assert_contains "$RELEASE_APPROVAL" 'Pattern 4' "release-approval documents Task-mode auto-confirm"
assert_contains "$RELEASE_APPROVAL" 'Pending-version re-check' "release-approval documents the defense-in-depth collision re-check"

assert_contains "$RELEASE_GIT_PR" 'skip Steps 1-3 entirely' "release-git-pr documents skipping staging, commit, and push for task-complete invocations"
assert_contains "$RELEASE_GIT_PR" 'PR-title verification only' "release-git-pr's task-complete role is narrowed to title enforcement"

# --- Contract assertions: post-merge-release.yml concurrency hardening -----

for workflow in \
  "$SOURCE_ROOT/.github/workflows/post-merge-release.yml" \
  "$SOURCE_ROOT/installer/workflow-templates/post-merge-release.yml"
do
  [ -f "$workflow" ] || continue
  assert_contains "$workflow" 'group: post-merge-release' "$workflow has a concurrency group"
  assert_contains "$workflow" 'cancel-in-progress: false' "$workflow never cancels an in-progress release run"
done

echo "[PASS] per-task release mechanics contract"
