#!/usr/bin/env bash
# Regression coverage for recap.py's transcript parsing.
#
# The bug this guards against: recap.py's schema assumptions (top-level
# "type": "user.message"/"assistant.message" with content at "data.content")
# never matched the real on-disk Claude Code transcript format ("type":
# "user"/"assistant", content at "message.content" as a list of typed blocks,
# with "origin.kind" distinguishing genuine human turns from tool-result
# deliveries). The mismatch made the script silently print nothing and exit 0
# on a real transcript — exactly the case its callers rely on it for.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/smaqit-recap-schema.XXXXXX")"

cleanup() {
  rm -rf -- "$fixture_root"
}
trap cleanup EXIT

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

recap_scripts=(
  "skills/smaqit.session-title/scripts/recap.py"
  "skills/smaqit.session-finish/scripts/recap.py"
  "skills/smaqit.session-recap/scripts/recap.py"
)

# All three copies must stay byte-identical, and must be the real fix.
first="${recap_scripts[0]}"
for rel in "${recap_scripts[@]}"; do
  test -f "$repo_root/$rel" || fail "missing $rel"
  diff -q "$repo_root/$first" "$repo_root/$rel" >/dev/null \
    || fail "$rel has drifted from $first — all three copies must stay in sync"
done

real_transcript="$fixture_root/real.jsonl"
cat > "$real_transcript" <<'EOF'
{"type": "user", "message": {"role": "user", "content": [{"type": "text", "text": "hello there"}]}, "origin": {"kind": "human"}}
{"type": "assistant", "message": {"role": "assistant", "content": [{"type": "thinking", "text": "thinking..."}, {"type": "text", "text": "hi back"}]}}
{"type": "user", "message": {"role": "user", "content": [{"type": "tool_result", "content": "some tool result"}]}, "origin": {"kind": "tool"}}
{"type": "user", "message": {"role": "user", "content": [{"type": "text", "text": "second question"}]}, "origin": {"kind": "human"}}
EOF

for rel in "${recap_scripts[@]}"; do
  out="$(python3 "$repo_root/$rel" "$real_transcript")"
  status=$?
  [ "$status" -eq 0 ] || fail "$rel: expected exit 0 on a real-format transcript, got $status"
  echo "$out" | grep -q "USER: 'hello there'" || fail "$rel: did not extract first human turn"
  echo "$out" | grep -q "ASSISTANT: 'hi back'" || fail "$rel: did not extract assistant text (skipping thinking blocks)"
  echo "$out" | grep -q "USER: 'second question'" || fail "$rel: did not extract second human turn"
  echo "$out" | grep -q "tool result" && fail "$rel: leaked a non-human tool-result delivery as a user turn"
done

# A schema that no longer matches (e.g. a future format drift, or the old
# broken schema) must fail loudly instead of silently exiting 0 with no output.
broken_transcript="$fixture_root/broken.jsonl"
echo '{"type": "user.message", "data": {"content": "x"}}' > "$broken_transcript"

for rel in "${recap_scripts[@]}"; do
  set +e
  out="$(python3 "$repo_root/$rel" "$broken_transcript" 2>&1)"
  status=$?
  set -e
  [ "$status" -ne 0 ] || fail "$rel: expected non-zero exit on unparseable schema, got 0"
  echo "$out" | grep -qi "warning" || fail "$rel: expected a warning message on unparseable schema, got: $out"
done

# An empty transcript is a legitimate no-op: exit 0, no warning.
empty_transcript="$fixture_root/empty.jsonl"
: > "$empty_transcript"
for rel in "${recap_scripts[@]}"; do
  out="$(python3 "$repo_root/$rel" "$empty_transcript")"
  status=$?
  [ "$status" -eq 0 ] || fail "$rel: expected exit 0 on an empty transcript, got $status"
  [ -z "$out" ] || fail "$rel: expected no output on an empty transcript, got: $out"
done

echo "[PASS] recap.py parses the real Claude Code transcript schema and fails loudly on mismatch"
