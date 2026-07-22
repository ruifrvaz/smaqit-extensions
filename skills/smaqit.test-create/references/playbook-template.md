# Playbook Template

> Canonical Markdown structure for all test playbooks. Load this when creating a new playbook via `smaqit.test-create`. Fill in `{placeholders}` with task-specific details and project-specific commands discovered by probing the project.

---

```markdown
# {Title} — E2E Test Playbook

**Test ID:** {NNN}
**Title:** {Task title}
**Date:** YYYY-MM-DD
**Tester:** User Testing Agent
**Task:** {NNN}

## Objectives
{What this playbook validates — 2-4 sentences}

## Prerequisites
- {Required services, tools, access — derived from project probe}
- {Example: API server running on localhost:8080 with valid auth token in .env}

## Test Steps

### Step 1 — Build & Unit Test Gate
- [ ] `{build command}` exits 0 — e.g., `make build`, `go build ./...`, `npm run build`, `dotnet build`, `cargo build`
- [ ] `{test command}` exits 0 (zero failures) — e.g., `make test`, `go test ./...`, `npm test`, `dotnet test`, `cargo test`, `pytest`

### Step 2 — Deploy & Start
- [ ] `{deploy/start command}` — deploys and starts the service(s)
- [ ] `{health-check command}` — all services report healthy

### Step 3 — Live Service E2E {REMOVE THIS STEP IF TASK DOES NOT TOUCH LIVE SERVICES}

{Derive verification method from the project's actual interfaces. Choose the applicable pattern:}

{For HTTP-based services:}
- [ ] `curl -s http://localhost:{port}/{endpoint}` → verify response contains "{expected text}"
- [ ] `curl -s -X POST http://localhost:{port}/{endpoint} -H "Content-Type: application/json" -d '{payload}'` → verify response status {NNN}
- [ ] Verify in logs: `{log-check command}` | grep "{key log line}"

{For WebSocket-based services:}
- [ ] Connect: `{websocket client command} {ws://url}`
- [ ] Turn 1: send `{exact input}` → verify response contains "{expected text}"
- [ ] Turn 2: send `{exact input}` → verify response contains "{expected text}"
- [ ] Verify in logs: `{log-check command}` | grep "{key log line}"

{For bot/event-driven services:}
- [ ] Trigger: {how to trigger the bot/event} → verify {expected behavior}
- [ ] Verify in logs: `{log-check command}` | grep "{key log line}"

### Step N — Additional Validation {REMOVE IF NOT NEEDED}

- [ ] {Config check, log check, or other project-specific validation}
- [ ] {Example: verify config entry with appropriate tool (`jq`, `yq`, `grep`, etc.)}

## Pass/Fail Criteria

**PASS** — All checkboxes are checked. All commands exit 0. Live-service responses match expected behavior.
**FAIL** — Any checkbox unchecked. Any unexpected failure or incorrect response.

## Evidence to Capture

- Output of `{test command}` (pass/fail summary)
- Output of `{health-check command}` (health status)
- {Turn-by-turn inputs and responses for live service E2E}
- Relevant log excerpts: `{log-check command}` | grep -E "{pattern}"
```
