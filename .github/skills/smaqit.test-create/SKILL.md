---
name: smaqit.test-create
description: Creates a test playbook for a task — `task.test-create [id]`, `test.create [id]`, or any request to generate an E2E test runbook from a task file. Produces a complete, executable playbook under `.smaqit/user-testing/tests/` with build-gate, deploy-gate, and live-service E2E validation where the task touches live services.
metadata:
  version: "1.0.0"
---

# Test Playbook Creator

## Steps

### 1. Gather task context

Collect from the user or from the task file (`.smaqit/tasks/NNN_*.md`):

- Task ID (NNN)
- Task title
- What the task changes (paths, services, abilities, config)
- Whether the task touches any live service: orchestrator, Discord, WebSocket, vLLM, Hindsight, RAG, TTS, STT

If the task file is not found, ask the user to verify the task ID. Do not proceed without confirmation.

### 2. Determine required sections

Every playbook MUST include:

- Objectives (2–4 sentences)
- Prerequisites (services, tools, access)
- Step 1: Build & Unit Test Gate — `dotnet build Iodis.sln --nologo --verbosity quiet` exits 0, then `dotnet test Iodis.sln --nologo --verbosity quiet` exits 0
- Step 2: Deploy & Start Orchestrator — `bash scripts/start/orchestrator-start.sh` then `bash scripts/health/health.sh`
- Pass/Fail Criteria
- Evidence to Capture

**Conditional — Step 3: Live Service E2E.** Include iff the task touches ANY live service (orchestrator, Discord, WebSocket, vLLM, Hindsight, RAG, TTS, STT). Must contain:

- Turn-by-turn instructions with exact input per turn
- Expected output/behavior per turn
- How to verify each turn (response content, `journalctl -u iodis-orchestrator --since "2 min ago" --no-pager | grep "…"`, Metadata key via `jq`)
- A `wscat -c ws://localhost:5000/ws` WebSocket fallback with the note: "If Discord token is unavailable, use WebSocket fallback."

**Conditional — Step N: Additional Validation.** Include only if the task requires config checks (`jq` against `appconfig.json`), log checks, or other domain-specific validation beyond the standard gates.

### 3. Load the playbook template

Read `references/playbook-template.md` from this skill's directory. Use it as the canonical skeleton — fill in every `{placeholder}` with task-specific details from Steps 1–2.

### 4. Write the playbook

Write to `.smaqit/user-testing/tests/{NNN}_{slug}.md`. Derive the slug from the task title: lowercase, hyphens, drop leading article words and the task number.

Rules:

- `scripts/start/orchestrator-start.sh` is idempotent — it rebuilds, redeploys, and restarts the systemd unit. Never include separate `dotnet publish`, `serve_daisy.sh`, or manual systemd restart steps.
- `scripts/health/health.sh` is the single source of truth for service health. Never check individual ports manually.
- Every live-service E2E turn must specify: exact input, expected output/behavior, and how to verify.
- If the playbook file already exists, ask whether to overwrite or use a different name.

### 5. Report

Report to the user:

- Path of the created playbook
- Sections included (Build Gate, Deploy, Live Service E2E, Additional Validation)
- If Live Service E2E is included, list the verification methods used (Discord, WebSocket, journalctl)

## Output

- `.smaqit/user-testing/tests/{NNN}_{slug}.md` — complete, executable test playbook

## Scope

**In scope:** Creating new test playbooks for existing tasks; determining required sections from task context; including live-service E2E where applicable.

**Out of scope:** Executing playbooks (`smaqit.test-start`); modifying existing playbooks (edit directly); creating task files or modifying `PLANNING.md`.

## Examples

**Request:** `task.test-create 058`

**Agent actions:**
1. Reads `.smaqit/tasks/058_coder_session_service.md`
2. Determines: task touches orchestrator and Discord
3. Loads `references/playbook-template.md`
4. Writes `.smaqit/user-testing/tests/058_coder-session-e2e.md` with Build Gate, Deploy, Live Service E2E (Discord turns + journalctl verification), and Evidence checklist

**Output:** Playbook created at `.smaqit/user-testing/tests/058_coder-session-e2e.md`. Sections: Build Gate, Deploy, Live Service E2E (Discord + journalctl).

## Gotchas

- `scripts/start/orchestrator-start.sh` is idempotent — it rebuilds the solution, copies to runtime, and restarts the systemd unit. Never include separate build, publish, or restart steps.
- `scripts/health/health.sh` is the single source of truth for service health. Always use it after deploy; never check individual ports manually.
- Discord tokens may be absent from the test environment. Always provide a `wscat`-based WebSocket fallback with the note: "If Discord token is unavailable, use WebSocket fallback."
- Journalctl `--since` values: use `"2 min ago"` for sequential turns. Adjust if the playbook has longer delays between steps.
- Playbook filename derives from the task title slug, not the raw task filename. Example: "021 — Assistant Multi-Turn Session Context" → `021_assistant-session-context.md`.

## Completion

- [ ] Task context gathered (ID, title, what it touches)
- [ ] Required sections determined
- [ ] Playbook template loaded from `references/playbook-template.md`
- [ ] Complete playbook written to `.smaqit/user-testing/tests/{NNN}_{slug}.md`
- [ ] Build Gate step present
- [ ] Deploy step present
- [ ] Live Service E2E step present iff task touches live services
- [ ] No separate `dotnet publish`, `serve_daisy.sh`, or manual systemd restart anti-patterns
- [ ] User informed of created file path

## Failure Handling

| Situation | Action |
|-----------|--------|
| Required input not provided | Request the missing information before proceeding |
| Gathered input is ambiguous | Flag the ambiguity and ask for clarification |
| Task ID not found in `.smaqit/tasks/` | Ask user to verify task ID; do not proceed without confirmation |
| Playbook already exists | Ask user: overwrite or create with different name |
| Template file not found at `references/playbook-template.md` | Use the hardcoded minimal structure from this skill's Steps section; report the missing template |
| Task context unclear (vague description) | Infer from task file ACs and implementation steps; flag assumptions to user |
