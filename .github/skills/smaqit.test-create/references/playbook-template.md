# Playbook Template

> Canonical Markdown structure for all test playbooks. Load this when creating a new playbook via `smaqit.test-create`. Fill in `{placeholders}` with task-specific details.

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
- {Required services, tools, access}
- {Example: Discord bot token in appconfig.local.json (or use WebSocket fallback)}
- {Example: wscat or Electron UI for WebSocket}

## Test Steps

### Step 1 — Build & Unit Test Gate
- [ ] `dotnet build Iodis.sln --nologo --verbosity quiet` exits 0
- [ ] `dotnet test Iodis.sln --nologo --verbosity quiet` exits 0 (zero failures)

### Step 2 — Deploy & Start Orchestrator
- [ ] `bash scripts/start/orchestrator-start.sh` — rebuilds, redeploys, restarts systemd unit
- [ ] `bash scripts/health/health.sh` — all services report healthy

### Step 3 — Live Service E2E {REMOVE THIS STEP IF TASK DOES NOT TOUCH LIVE SERVICES}

{For Discord-based E2E:}

- [ ] Turn 1: send "{exact Discord message}" in test channel → verify response {expected behavior}
- [ ] Turn 2: send "{exact Discord message}" → verify response {expected behavior}
- [ ] Verify in journald: `journalctl -u iodis-orchestrator --since "2 min ago" --no-pager | grep "{key log line}"`

{For WebSocket-based E2E (fallback or primary):}

- [ ] Connect: `wscat -c ws://localhost:5000/ws`
- [ ] Turn 1: send `{"input":"{exact input}"}` → verify response contains "{expected text}"
- [ ] Turn 2: send `{"input":"{exact input}"}` → verify response contains "{expected text}"
- [ ] Verify in journald: `journalctl -u iodis-orchestrator --since "2 min ago" --no-pager | grep "{key log line}"`

{If Discord token unavailable, add note:}
> Note: If Discord token is unavailable, use the WebSocket fallback steps below. Connect via `wscat` instead of Discord client.

### Step N — Additional Validation

- [ ] {Config check, log check, or other validation}
- [ ] {Example: verify appconfig.json entry with `jq`}

## Pass/Fail Criteria

**PASS** — All checkboxes are checked. All commands exit 0. Live-service responses match expected behavior.
**FAIL** — Any checkbox unchecked. Any unexpected failure or incorrect response.

## Evidence to Capture

- Output of `dotnet test Iodis.sln` (pass/fail summary line)
- Output of `bash scripts/health/health.sh` (all services line)
- {Turn-by-turn inputs and responses for live service E2E}
- Relevant journald log excerpts: `journalctl -u iodis-orchestrator --since "5 min ago" --no-pager | grep -E "{pattern}"`
```
