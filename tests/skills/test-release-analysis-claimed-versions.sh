#!/usr/bin/env bash
# Hermetic checks for the per-task release mechanics: a reference
# implementation of smaqit.release-prepare-files' Task-Release Mode (write a
# task's versioned CHANGELOG.md section on its own branch, folding in whatever
# the implementer already left under [Unreleased]) exercised against a
# fixture, plus contract assertions across every release skill that documents
# claimed-version awareness via open release-PR titles.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/smaqit-release-claimed.XXXXXX")"

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

# --- Mechanical test: write the task's versioned section on the branch ------
# The implementer left one bullet under [Unreleased] while coding; release-
# analysis's `changes` list independently describes that same fix plus a new
# feature. The operation must fold both sources into one `## [X.Y.Z]` section,
# deduplicate the shared bullet, leave [Unreleased] as an empty header, and
# leave every already-released section untouched — with no annotation of any
# kind, since the open PR's title is the only version claim.

CHANGELOG="$FIXTURE_ROOT/CHANGELOG.md"
cat > "$CHANGELOG" <<'EOF'
# Changelog

## [Unreleased]

### Fixed
- **Null pointer in resolver** — fixes a crash when resolving.

## [1.15.0] - 2026-08-14

### Added
- Something already released.
EOF

CHANGES="$FIXTURE_ROOT/changes.tsv"
printf 'Added\t- **Widget caching** — adds an LRU cache to the widget resolver.\nFixed\t- **Null pointer in resolver** — fixes a crash when resolving.\n' > "$CHANGES"

write_task_release_section() {
  local file="$1" changes="$2" version="$3" today="$4"
  local merged="$file.merged"
  # 1. Bullets already under [Unreleased], tagged with their category.
  awk '
    /^## \[Unreleased\]/ { in_unreleased=1; next }
    in_unreleased && /^## \[/ { in_unreleased=0 }
    in_unreleased && /^### / { category=substr($0, 5); next }
    in_unreleased && /^- / { print category "\t" $0 }
  ' "$file" > "$merged"
  # 2. Plus release-analysis's changes list; dedupe on exact bullet text,
  #    first occurrence wins.
  cat "$changes" >> "$merged"
  awk -F'\t' '!seen[$2]++' "$merged" > "$merged.dedup"
  # 3. Rewrite: everything up to and including the [Unreleased] header, an
  #    empty [Unreleased], the new section grouped by category in conventional
  #    order, then every already-released section byte-for-byte.
  {
    awk '/^## \[Unreleased\]/ { print; exit } { print }' "$file"
    echo
    echo "## [${version}] - ${today}"
    for category in Added Changed Deprecated Removed Fixed Security; do
      if awk -F'\t' -v c="$category" '$1==c { found=1 } END { exit !found }' "$merged.dedup"; then
        echo
        echo "### $category"
        awk -F'\t' -v c="$category" '$1==c { print $2 }' "$merged.dedup"
      fi
    done
    echo
    awk '/^## \[/ && !/\[Unreleased\]/ { f=1 } f { print }' "$file"
  } > "$file.new"
  mv "$file.new" "$file"
  rm -f "$merged" "$merged.dedup"
}

write_task_release_section "$CHANGELOG" "$CHANGES" "1.16.0" "2026-09-15"

grep -q -- '^## \[1.16.0\] - 2026-09-15$' "$CHANGELOG" || fail "versioned section was not created"
grep -qF -- '- **Widget caching** — adds an LRU cache to the widget resolver.' "$CHANGELOG" || fail "release-analysis change was not written"
[ "$(grep -cF -- '- **Null pointer in resolver** — fixes a crash when resolving.' "$CHANGELOG")" -eq 1 ] \
  || fail "implementer bullet was not folded in exactly once (dedupe against the changes list)"
awk '/^## \[Unreleased\]/ { f=1; next } f && /^## \[1.16.0\]/ { exit 0 } f && NF { exit 1 }' "$CHANGELOG" \
  || fail "[Unreleased] was not left as an empty header"
[ "$(grep '^## \[' "$CHANGELOG" | tr '\n' '|')" = "## [Unreleased]|## [1.16.0] - 2026-09-15|## [1.15.0] - 2026-08-14|" ] \
  || fail "section order is wrong — expected Unreleased, then the new version, then the prior release"
grep -qF -- '- Something already released.' "$CHANGELOG" || fail "prior released section was disturbed"
grep -qF -- '(pending v' "$CHANGELOG" && fail "no pending annotation may ever be written"

echo "[PASS] task-release section folds [Unreleased] bullets and the changes list into one versioned section"

# --- Contract assertions: release-analysis Task mode / claimed-version awareness

RELEASE_ANALYSIS="$SOURCE_ROOT/skills/smaqit.release-analysis/SKILL.md"
RELEASE_PREPARE="$SOURCE_ROOT/skills/smaqit.release-prepare-files/SKILL.md"
RELEASE_APPROVAL="$SOURCE_ROOT/skills/smaqit.release-approval/SKILL.md"
RELEASE_GIT_PR="$SOURCE_ROOT/skills/smaqit.release-git-pr/SKILL.md"

assert_contains "$RELEASE_ANALYSIS" '**Task mode**' "release-analysis documents Task mode"
assert_contains "$RELEASE_ANALYSIS" 'git fetch origin main' "release-analysis fetches origin/main fresh before searching"
assert_contains "$RELEASE_ANALYSIS" 'git log origin/main --format' "release-analysis searches origin/main, not local HEAD"
assert_contains "$RELEASE_ANALYSIS" 'Claimed-version awareness' "release-analysis documents claimed-version awareness"
assert_contains "$RELEASE_ANALYSIS" 'gh pr list --state open --limit 100 --json number,title' "release-analysis reads claims from open release-PR titles"
assert_contains "$RELEASE_ANALYSIS" 'never `--search`' "release-analysis filters titles client-side, never through the eventually-consistent search index"

assert_contains "$RELEASE_PREPARE" '## Task-Release Mode' "release-prepare-files documents Task-Release Mode"
assert_contains "$RELEASE_PREPARE" 'directly on the task branch' "release-prepare-files writes the section on the branch, never on main"
assert_contains "$RELEASE_PREPARE" 'leave `## [Unreleased]` as an empty header' "release-prepare-files empties [Unreleased] after folding it in"

assert_contains "$RELEASE_APPROVAL" 'Pattern 4' "release-approval documents Task-mode auto-confirm"
assert_contains "$RELEASE_APPROVAL" 'Claimed-version re-check' "release-approval documents the defense-in-depth collision re-check"

assert_contains "$RELEASE_GIT_PR" 'skip Steps 1-3 entirely' "release-git-pr documents skipping staging, commit, and push for task-complete invocations"
assert_contains "$RELEASE_GIT_PR" 'PR-title verification only' "release-git-pr's task-complete role is narrowed to title enforcement"

# The retired pending-entry design — an annotated bullet born on main and
# rebased into the branch — must not survive anywhere in the shipped skills.
if rg -n --fixed-strings '(pending v' "$SOURCE_ROOT/skills"; then
  fail "the retired (pending vX.Y.Z · PR #NNN) convention is still referenced under skills/"
fi
if rg -n --fixed-strings 'Pending Entry Mode' "$SOURCE_ROOT/skills"; then
  fail "the retired Pending Entry Mode is still referenced under skills/"
fi

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
