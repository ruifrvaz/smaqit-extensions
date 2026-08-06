#!/usr/bin/env bash
# Hermetic regression tests for smaqit.project-research's verify-urls.sh,
# exercised against a local Python HTTP fixture server — never public sites.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERIFY_SCRIPT="$SOURCE_ROOT/skills/smaqit.project-research/scripts/verify-urls.sh"
FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/smaqit-verify-urls.XXXXXX")"

SERVER_PID=""
cleanup() {
  [ -n "$SERVER_PID" ] && kill "$SERVER_PID" >/dev/null 2>&1 || true
  rm -rf "$FIXTURE_ROOT"
}
trap cleanup EXIT

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

assert_eq() {
  local actual="$1" expected="$2" message="$3"
  [ "$actual" = "$expected" ] || fail "$message (expected [$expected], got [$actual])"
}

assert_contains() {
  local haystack="$1" needle="$2" message="$3"
  case "$haystack" in
    *"$needle"*) ;;
    *) fail "$message — expected to find: $needle" ;;
  esac
}

assert_line_count() {
  local text="$1" expected="$2" message="$3"
  local actual
  if [ -z "$text" ]; then
    actual=0
  else
    actual=$(printf '%s\n' "$text" | wc -l | tr -d ' ')
  fi
  assert_eq "$actual" "$expected" "$message"
}

# --- Fixture HTTP server -----------------------------------------------
FIXTURE_SERVER="$FIXTURE_ROOT/server.py"
cat > "$FIXTURE_SERVER" <<'PYEOF'
import http.server
import sys

class Handler(http.server.BaseHTTPRequestHandler):
    def do_HEAD(self):
        self._respond()
    def do_GET(self):
        self._respond()
    def _respond(self):
        path = self.path
        if path == "/ok200":
            self.send_response(200); self.end_headers()
        elif path == "/ok204":
            self.send_response(204); self.end_headers()
        elif path == "/redirect":
            self.send_response(301)
            self.send_header("Location", "/ok200")
            self.end_headers()
        elif path == "/head-rejected":
            if self.command == "HEAD":
                self.send_response(405); self.end_headers()
            else:
                self.send_response(200); self.end_headers()
        elif path == "/notfound":
            self.send_response(404); self.end_headers()
        else:
            self.send_response(404); self.end_headers()
    def log_message(self, fmt, *args):
        pass

if __name__ == "__main__":
    port = int(sys.argv[1])
    http.server.HTTPServer(("127.0.0.1", port), Handler).serve_forever()
PYEOF

PORT="$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')"
BASE="http://127.0.0.1:$PORT"

python3 "$FIXTURE_SERVER" "$PORT" &
SERVER_PID=$!

# Wait for the fixture server to accept connections (bounded, no arbitrary sleep chains).
ready=0
for _ in $(seq 1 50); do
  if curl --silent --max-time 1 -o /dev/null "$BASE/ok200" 2>/dev/null; then
    ready=1
    break
  fi
  sleep 0.1
done
[ "$ready" -eq 1 ] || fail "fixture server did not become ready on port $PORT"

# Unreachable target: a port nothing is listening on, on the same loopback host.
UNREACHABLE="http://127.0.0.1:1"

run_verify() {
  # $1: input TSV content (already tab-separated, newline-delimited)
  local input="$FIXTURE_ROOT/in.tsv"
  printf '%s\n' "$1" > "$input"
  bash "$VERIFY_SCRIPT" "$input" 2>"$FIXTURE_ROOT/stderr.log"
}

# --- 200 ---
out="$(run_verify "$(printf 'Go\tDocs\t%s/ok200\tproject' "$BASE")")"
assert_line_count "$out" 1 "200 response produces exactly one output line"
assert_eq "$out" "$(printf 'Go\tDocs\t%s/ok200\t200\tproject' "$BASE")" "200 response output fields match exactly"

# --- non-200 2xx (204) ---
out="$(run_verify "$(printf 'Go\tDocs\t%s/ok204\tproject' "$BASE")")"
assert_line_count "$out" 1 "204 (non-200 2xx) response produces exactly one output line"
assert_contains "$out" $'\t204\t' "204 status is classified as live, not just literal 200"

# --- redirect ---
out="$(run_verify "$(printf 'Go\tDocs\t%s/redirect\tproject' "$BASE")")"
assert_contains "$out" "/ok200" "redirect target's final_url reflects the redirected location"
assert_contains "$out" $'\t200\t' "redirect ultimately resolves to a 200 status"

# --- HEAD rejected, GET fallback succeeds ---
out="$(run_verify "$(printf 'Go\tDocs\t%s/head-rejected\tproject' "$BASE")")"
assert_line_count "$out" 1 "HEAD-rejected endpoint still produces one output line via GET fallback"
assert_contains "$out" $'\t200\t' "GET fallback status is 200"
stderr="$(cat "$FIXTURE_ROOT/stderr.log")"
assert_contains "$stderr" "HEAD returned 405" "stderr shows the HEAD rejection that triggered the GET fallback"

# --- 4xx rejected ---
out="$(run_verify "$(printf 'Go\tDocs\t%s/notfound\tproject' "$BASE")")"
assert_eq "$out" "" "4xx response produces no output line"
stderr="$(cat "$FIXTURE_ROOT/stderr.log")"
assert_contains "$stderr" "404" "stderr reports the 404 status"

# --- unreachable endpoint ---
out="$(run_verify "$(printf 'Go\tDocs\t%s\tproject' "$UNREACHABLE")")"
assert_eq "$out" "" "unreachable endpoint produces no output line"

# --- malformed: invalid LAYER value ---
out="$(run_verify "$(printf 'Go\tDocs\t%s/ok200\tbadlayer' "$BASE")")"
assert_eq "$out" "" "invalid LAYER value produces no output line"
stderr="$(cat "$FIXTURE_ROOT/stderr.log")"
assert_contains "$stderr" "Malformed record" "invalid LAYER value is reported as a malformed record"

# --- malformed: missing LAYER field (3-column legacy row) ---
out="$(run_verify "$(printf 'Go\tDocs\t%s/ok200' "$BASE")")"
assert_eq "$out" "" "3-column row (no LAYER) produces no output line"
stderr="$(cat "$FIXTURE_ROOT/stderr.log")"
assert_contains "$stderr" "Malformed record" "missing LAYER field is reported as a malformed record"

# --- project and task layer preservation, in the same run ---
input=$(printf 'Go\tDocs\t%s/ok200\tproject\nTaskTool\tSetup\t%s/ok200\ttask' "$BASE" "$BASE")
out="$(run_verify "$input")"
assert_line_count "$out" 2 "both project- and task-layer rows produce output"
assert_contains "$out" $'\tproject' "project-layer row preserves its LAYER value"
assert_contains "$out" $'\ttask' "task-layer row preserves its LAYER value"

# --- labels containing spaces ---
out="$(run_verify "$(printf 'My Tool\tGetting Started Guide\t%s/ok200\tproject' "$BASE")")"
assert_contains "$out" "My Tool" "tool label with spaces survives unmangled"
assert_contains "$out" "Getting Started Guide" "section label with spaces survives unmangled"

echo "[PASS] verify-urls.sh liveness and contract regression suite"
