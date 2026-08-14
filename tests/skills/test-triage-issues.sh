#!/usr/bin/env bash
# Hermetic contract tests for the compact GitHub client used by issue triage.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HELPER="$SOURCE_ROOT/skills/smaqit.utils.triage-issues/scripts/github-issues.sh"
TASK_SIGNAL_HELPER="$SOURCE_ROOT/skills/smaqit.project-research/scripts/task-context.sh"
TASK_MAP_HELPER="$SOURCE_ROOT/skills/smaqit.project-research/scripts/task-map.sh"
TRIAGE_SKILL="$SOURCE_ROOT/skills/smaqit.utils.triage-issues/SKILL.md"
TASK_START_SKILL="$SOURCE_ROOT/skills/smaqit.task-start/SKILL.md"
FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/smaqit-triage.XXXXXX")"
QUERY_LOG="$FIXTURE_ROOT/queries.jsonl"
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

assert_contains "$(<"$TRIAGE_SKILL")" 'smaqit.project-research` is the triage skill' "triage preserves project-research as its upstream source"
assert_contains "$(<"$TRIAGE_SKILL")" '## Task NNN — [title]' "triage prioritizes task-scoped research-map rows"
assert_contains "$(<"$TRIAGE_SKILL")" 'It never substitutes for the research map' "helper fallback does not replace research-map context"
assert_contains "$(<"$TASK_START_SKILL")" 'verified current-task map block' "task-start supplies current-task map context before triage"
assert_contains "$(<"$TRIAGE_SKILL")" 'smaqit.project-research/scripts/task-context.sh' "triage projects task content through the upstream context helper"
assert_contains "$(<"$TRIAGE_SKILL")" 'Do not open, read, print, or search the task file directly' "triage forbids direct task-file reads"
assert_contains "$(<"$TASK_START_SKILL")" 'Read the full task file** after triage' "task-start delays the full task read until after triage"
assert_contains "$(<"$TASK_START_SKILL")" 'do not refresh or render the full map' "task-start avoids a full map at the triage gate"
for template in "$SOURCE_ROOT/.smaqit/templates/task.template.md" "$SOURCE_ROOT/skills/smaqit.task-create/assets/TASK_TEMPLATE.md"; do
  template_context="$(awk '/^## Issue Triage Context$/ { in_context = 1; next } in_context && /^## / { exit } in_context { print }' "$template")"
  assert_eq "$(rg -c '^## Issue Triage Context$' "$template")" "1" "template has one Issue Triage Context heading"
  assert_eq "$(printf '%s\n' "$template_context" | rg '^\*\*(Mode|Technologies|Platforms/Environments|Features/Integrations|Versions/Constraints):\*\*' | sed 's/^\*\*\([^:]*\):\*\*.*/\1/' | paste -sd '|')" 'Mode|Technologies|Platforms/Environments|Features/Integrations|Versions/Constraints' "template fields use canonical order"
done
assert_contains "$(<"$SOURCE_ROOT/skills/smaqit.task-create/SKILL.md")" 'A child receives its own context' "task-create owns structured context population"
assert_contains "$(<"$SOURCE_ROOT/skills/smaqit.task-plan/SKILL.md")" 'Issue Triage Context' "task-plan owns structured context derivation and refinement"

cat >"$FIXTURE_ROOT/structured-task.md" <<'TASK_EOF'
## Issue Triage Context
**Mode:** Auto
**Technologies:** Widget Library
**Platforms/Environments:** Ubuntu 24.04
**Features/Integrations:** inference
**Versions/Constraints:** None

## Findings
SENSITIVE UNRELATED FINDINGS
TASK_EOF

structured_context="$(bash "$TASK_SIGNAL_HELPER" "$FIXTURE_ROOT/structured-task.md")"
printf '%s' "$structured_context" | jq -e '
  .source == "structured" and .mode == "Auto" and .technologies == "Widget Library" and
  .platforms == "Ubuntu 24.04" and .features == "inference" and .versions == "None" and
  (.fingerprint | startswith("sha256:"))
' >/dev/null || fail "structured context emits only canonical fields and fingerprint"
case "$structured_context" in *SENSITIVE*) fail "structured context leaked unrelated task content" ;; esac

cat >"$FIXTURE_ROOT/none-context.md" <<'TASK_EOF'
## Issue Triage Context
**Mode:** Auto
**Technologies:** None
**Platforms/Environments:** None
**Features/Integrations:** None
**Versions/Constraints:** None
TASK_EOF
assert_eq "$(bash "$TASK_SIGNAL_HELPER" "$FIXTURE_ROOT/none-context.md" | jq -r '.technologies')" "None" "structured context supports explicit None"

cat >"$FIXTURE_ROOT/bad-order-context.md" <<'TASK_EOF'
## Issue Triage Context
**Technologies:** Widget Library
**Mode:** Auto
**Platforms/Environments:** Ubuntu
**Features/Integrations:** inference
**Versions/Constraints:** None
TASK_EOF
if bash "$TASK_SIGNAL_HELPER" "$FIXTURE_ROOT/bad-order-context.md" >"$FIXTURE_ROOT/out" 2>"$FIXTURE_ROOT/err"; then
  fail "structured context must reject non-canonical field order"
fi
assert_contains "$(<"$FIXTURE_ROOT/err")" 'canonical order' "structured context reports non-canonical order"

cat >"$FIXTURE_ROOT/invalid-context.md" <<'TASK_EOF'
## Issue Triage Context
**Mode:** Maybe
**Technologies:** TBD
**Platforms/Environments:** Ubuntu
**Features/Integrations:** inference
**Versions/Constraints:** None
TASK_EOF
if bash "$TASK_SIGNAL_HELPER" "$FIXTURE_ROOT/invalid-context.md" >"$FIXTURE_ROOT/out" 2>"$FIXTURE_ROOT/err"; then
  fail "structured context must reject invalid values"
fi
assert_contains "$(<"$FIXTURE_ROOT/err")" 'invalid placeholder' "structured context rejects placeholders"

cat >"$FIXTURE_ROOT/map.md" <<'MAP_EOF'
# Project Research Map
**Project:** Example
**Refreshed:** 2026-08-14

| Tool | Section | URL |
|---|---|---|
| Widget Library | Overview | https://example.test/docs |

## Task 025 — Example
**Context fingerprint:** sha256:expected
**Refreshed:** 2026-08-14
| Tool | Section | URL |
|---|---|---|
| Widget Library | Inference | https://example.test/inference |

## Task 026 — Other
**Context fingerprint:** sha256:other
MAP_EOF

assert_eq "$(bash "$TASK_MAP_HELPER" status "$FIXTURE_ROOT/map.md" 025 sha256:expected | jq -r '.status')" "match" "task map matches task fingerprint"
assert_eq "$(bash "$TASK_MAP_HELPER" status "$FIXTURE_ROOT/map.md" 025 sha256:changed | jq -r '.status')" "mismatch" "task map detects changed context"
map_projection="$(bash "$TASK_MAP_HELPER" select "$FIXTURE_ROOT/map.md" 025 sha256:expected)"
assert_contains "$map_projection" 'Widget Library | Inference' "task map projects current task block"
case "$map_projection" in *"Task 026"*) fail "task map leaked another task block" ;; esac
cp "$FIXTURE_ROOT/map.md" "$FIXTURE_ROOT/map-before-upsert.md"
cat >"$FIXTURE_ROOT/refreshed-task-block.md" <<'BLOCK_EOF'
## Task 025 — Example refreshed
**Context fingerprint:** sha256:refreshed
**Refreshed:** 2026-08-14
| Tool | Section | URL |
|---|---|---|
| Widget Library | Inference | https://example.test/refreshed |
BLOCK_EOF
bash "$TASK_MAP_HELPER" upsert "$FIXTURE_ROOT/map.md" 025 "$FIXTURE_ROOT/refreshed-task-block.md"
assert_contains "$(<"$FIXTURE_ROOT/map.md")" '**Refreshed:** 2026-08-14' "task-only upsert preserves project refresh metadata"
assert_contains "$(<"$FIXTURE_ROOT/map.md")" '| Widget Library | Overview | https://example.test/docs |' "task-only upsert preserves project table"
assert_contains "$(<"$FIXTURE_ROOT/map.md")" '## Task 026 — Other' "task-only upsert preserves unrelated task blocks"
assert_contains "$(<"$FIXTURE_ROOT/map.md")" 'sha256:refreshed' "task-only upsert replaces the requested task block"

cat >"$FIXTURE_ROOT/task.md" <<'TASK_EOF'
# Example task

**Status:** In Progress

## Description
Integrate Widget Library with Ubuntu 24.04.

### Detail
Support inference mode.

## Acceptance Criteria
- [ ] Widget inference works

## Notes
triage: skip

## Findings
SENSITIVE UNRELATED FINDINGS

## Known Issues Triage
SENSITIVE PREVIOUS TRIAGE
TASK_EOF

task_signal="$(bash "$TASK_SIGNAL_HELPER" --allow-legacy "$FIXTURE_ROOT/task.md" | jq -r '.legacy_signal')"
assert_contains "$task_signal" 'Integrate Widget Library with Ubuntu 24.04.' "task signal retains Description"
assert_contains "$task_signal" 'Widget inference works' "task signal retains Acceptance Criteria"
assert_contains "$task_signal" 'triage: skip' "task signal retains Notes"
case "$task_signal" in
  *SENSITIVE*) fail "task signal leaked an unrelated task section" ;;
esac
assert_eq "$(printf '%s\n' "$task_signal" | awk '/^## / { print }' | paste -sd '|')" '## Description|## Acceptance Criteria|## Notes' "task signal emits only required sections in canonical order"

cat >"$FIXTURE_ROOT/malformed-task.md" <<'TASK_EOF'
## Description
Missing required sections.
TASK_EOF

if bash "$TASK_SIGNAL_HELPER" --allow-legacy "$FIXTURE_ROOT/malformed-task.md" >"$FIXTURE_ROOT/out" 2>"$FIXTURE_ROOT/err"; then
  fail "task signal must reject missing required sections"
fi
assert_contains "$(<"$FIXTURE_ROOT/err")" 'legacy task missing section' "task signal reports malformed task structure concisely"

PORT="$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')"
BASE="http://127.0.0.1:$PORT"

python3 - "$PORT" "$QUERY_LOG" <<'PYEOF' &
import http.server
import json
import sys
from urllib.parse import parse_qs, urlparse

port = int(sys.argv[1])
query_log = sys.argv[2]

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urlparse(self.path)
        query = parse_qs(parsed.query)
        with open(query_log, "a", encoding="utf-8") as log:
            log.write(json.dumps({"path": parsed.path, "query": query}) + "\n")

        terms = " ".join(query.get("q", []))
        if "badjson" in terms:
            self._send(200, b"this is not json", "text/plain")
            return
        if "http500" in terms:
            self._send(500, b'{"message":"SENSITIVE API ERROR"}')
            return
        if parsed.path == "/search/repositories":
            self._json({"items": [{"full_name": "acme/widget", "body": "SENSITIVE REPOSITORY BODY"}]})
            return
        if parsed.path == "/search/issues":
            state = "closed" if "state:closed" in terms else "open"
            items = []
            for number in range(1, 13):
                items.append({
                    "number": number,
                    "title": f"Widget issue {number}",
                    "labels": [{"name": "bug"}, {"name": "platform"}],
                    "html_url": f"https://example.test/acme/widget/issues/{number}",
                    "state": state,
                    "created_at": "2026-01-01T00:00:00Z",
                    "closed_at": "2026-01-02T00:00:00Z" if state == "closed" else None,
                    "body": "SENSITIVE ISSUE BODY",
                    "comments": 999,
                    "user": {"login": "sensitive-user"},
                    "reactions": {"total_count": 999},
                    "pull_request": {"url": "https://example.test/pr"},
                })
            self._json({"total_count": 12, "incomplete_results": "incomplete" in terms, "items": items})
            return
        if parsed.path == "/repos/acme/widget/issues/1":
            self._json({
                "number": 1,
                "title": "Widget issue 1",
                "labels": [{"name": "bug"}],
                "html_url": "https://example.test/acme/widget/issues/1",
                "state": "open",
                "created_at": "2026-01-01T00:00:00Z",
                "closed_at": None,
                "body": "X" * 2000 + " SENSITIVE DETAIL BODY",
                "comments": 999,
                "user": {"login": "sensitive-user"},
            })
            return
        self._send(404, b'{"message":"not found"}')

    def _json(self, body):
        self._send(200, json.dumps(body).encode("utf-8"))

    def _send(self, status, body, content_type="application/json"):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        pass

http.server.HTTPServer(("127.0.0.1", port), Handler).serve_forever()
PYEOF
SERVER_PID=$!

ready=0
for _ in $(seq 1 50); do
  if curl --silent --max-time 1 -o /dev/null "$BASE/search/repositories" 2>/dev/null; then
    ready=1
    break
  fi
  sleep 0.1
done
[ "$ready" -eq 1 ] || fail "fixture server did not become ready"

run_helper() {
  SMAQIT_GITHUB_API_BASE="$BASE" bash "$HELPER" "$@"
}

resolved="$(run_helper resolve 'Widget Library')"
assert_eq "$(printf '%s' "$resolved" | jq -c 'keys | sort')" '["full_name"]' "repository resolution emits only full_name"
assert_eq "$(printf '%s' "$resolved" | jq -r '.full_name')" "acme/widget" "repository resolution returns the selected repository"

open="$(run_helper search acme/widget open 'Ubuntu 24.04' inference)"
closed="$(run_helper search acme/widget closed 'Ubuntu 24.04' inference)"
for result in "$open" "$closed"; do
  assert_eq "$(printf '%s' "$result" | jq -r '.items | length')" "10" "search locally truncates to ten results"
  printf '%s' "$result" | jq -e '
    (keys | sort) == ["incomplete_results", "items"] and
    all(.items[]; (keys | sort) == ["closed_at", "created_at", "html_url", "labels", "number", "state", "title"])
  ' >/dev/null || fail "search emits only the compact issue schema"
  case "$result" in
    *SENSITIVE*) fail "search leaked a forbidden raw API field" ;;
  esac
done
assert_eq "$(printf '%s' "$open" | jq -r '.items[0].labels | join(",")')" "bug,platform" "labels are reduced to names"
assert_eq "$(printf '%s' "$closed" | jq -r '.items[0].closed_at')" "2026-01-02T00:00:00Z" "closed search preserves closed_at"
incomplete="$(run_helper search acme/widget open incomplete)"
assert_eq "$(printf '%s' "$incomplete" | jq -r '.incomplete_results')" "true" "incomplete GitHub search state survives projection"

detail="$(run_helper detail acme/widget 1)"
printf '%s' "$detail" | jq -e '
  (keys | sort) == ["body_excerpt", "closed_at", "created_at", "html_url", "labels", "number", "state", "title"] and
  (.body_excerpt | length) == 1500
' >/dev/null || fail "detail emits compact metadata and a 1,500-character excerpt"
case "$detail" in
  *SENSITIVE*) fail "detail leaked content beyond the bounded excerpt" ;;
esac

jq -s -e '
  ([.[] | select(.path == "/search/issues")] | length) == 3 and
  all(.[] | select(.path == "/search/issues");
    .query.per_page[0] == "10" and
    .query.page[0] == "1" and
    (.query.q[0] | contains("is:issue"))
  ) and
  any(.[] | select(.path == "/search/issues"); .query.q[0] == "repo:acme/widget is:issue Ubuntu 24.04 inference state:open") and
  ([.[] | select(.path == "/search/issues") | .query.q[0] | contains("state:open")] | any) and
  ([.[] | select(.path == "/search/issues") | .query.q[0] | contains("state:closed")] | any)
' "$QUERY_LOG" >/dev/null || fail "search requests use both states, is:issue, and bounded pagination"

if run_helper search acme/widget open badjson >"$FIXTURE_ROOT/out" 2>"$FIXTURE_ROOT/err"; then
  fail "malformed JSON must fail"
fi
assert_contains "$(<"$FIXTURE_ROOT/err")" "response was not valid JSON" "malformed JSON produces a concise diagnostic"

if run_helper search acme/widget open http500 >"$FIXTURE_ROOT/out" 2>"$FIXTURE_ROOT/err"; then
  fail "non-2xx response must fail"
fi
assert_contains "$(<"$FIXTURE_ROOT/err")" "HTTP 500" "non-2xx response reports its status"
case "$(<"$FIXTURE_ROOT/err")" in
  *SENSITIVE*) fail "non-2xx response leaked its raw API body" ;;
esac

if SMAQIT_GITHUB_API_BASE="http://127.0.0.1:1" bash "$HELPER" resolve Widget >"$FIXTURE_ROOT/out" 2>"$FIXTURE_ROOT/err"; then
  fail "transport failure must fail"
fi
assert_contains "$(<"$FIXTURE_ROOT/err")" "request failed" "transport failure produces a concise diagnostic"

echo "[PASS] triage compact GitHub client contract"
