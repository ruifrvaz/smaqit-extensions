---
name: smaqit.test-create
description: Creates a test playbook for a task — `task.test-create [id]`, `test.create [id]`, or any request to generate an E2E test runbook from a task file. Produces a complete, executable playbook under `.smaqit/user-testing/tests/` with build-gate, deploy-gate, and live-service E2E validation where the task touches live services.
metadata:
  version: "2.0.0"
---

# Test Playbook Creator

## Steps

### 1. Gather task context

Collect from the user or from the task file (`.smaqit/tasks/NNN_*.md`):

- Task ID (NNN)
- Task title
- What the task changes (paths, services, abilities, config)
- Whether the task touches any live/running service (API server, bot, daemon, worker, message queue consumer, scheduled job, etc.)

If the task file is not found, ask the user to verify the task ID. Do not proceed without confirmation.

### 2. Probe the project for build, test, and deploy commands

**Do not assume any specific toolchain.** Probe the project the same way `smaqit.session-start` does. Read whichever of the following exist (in parallel):

**Build & test commands — probe in order:**
1. `AGENTS.md`, `CLAUDE.md`, or `.github/copilot-instructions.md` — look for "Testing", "Build", or "Development" sections that document commands
2. `Makefile` — look for `build`, `test`, `check` targets
3. `package.json` — look for `scripts.test`, `scripts.build`
4. `pyproject.toml` / `tox.ini` / `pytest.ini` — infer pytest/tox commands
5. `go.mod` — infer `go build ./...` and `go test ./...`
6. `Cargo.toml` — infer `cargo build` and `cargo test`
7. `*.sln` / `*.csproj` — infer `dotnet build` and `dotnet test`
8. `specs/stack/*.md` — look for documented build/test/run commands

**Deploy/start commands — probe in order:**
1. Project instructions (`AGENTS.md`/`CLAUDE.md`/`.github/copilot-instructions.md`) — look for "Deploy", "Start", "Run" sections
2. `Makefile` — look for `deploy`, `start`, `run`, `up` targets
3. `docker-compose.yml` / `Dockerfile` — infer `docker compose up`
4. `scripts/start/`, `scripts/deploy/`, `scripts/run/` — check for start/deploy scripts
5. `package.json` — look for `scripts.start`, `scripts.deploy`
6. `specs/stack/*.md` — look for documented deploy/run commands

**Health-check mechanism:**
1. Project instructions or Makefile for a `health` target or health-check script
2. If a server/binary is started, infer `curl http://localhost:{port}/health` or equivalent
3. If systemd units are documented, infer `systemctl status {unit}` or `journalctl -u {unit}`
4. If none found, note "manual verification" as the fallback

**Live-service detection:**
- Read the task file carefully. Does it mention any running service, API endpoint, bot, daemon, worker, WebSocket, message queue consumer, or scheduled job?
- If yes, include Step 3 (Live Service E2E). If no, omit it.
- For the E2E verification method, derive from the project's actual interfaces: HTTP endpoints (use `curl`), WebSocket (use `wscat` or similar), bot messages (use the bot's client or a test harness), log output (`tail`/`grep`/`journalctl` as appropriate). Do NOT hardcode Discord, WebSocket on port 5000, or journalctl.

### 3. Determine required sections

Every playbook MUST include:

- Objectives (2–4 sentences)
- Prerequisites (services, tools, access — derived from project probe)
- Step 1: Build & Unit Test Gate — `{build command}` exits 0, then `{test command}` exits 0
- Step 2: Deploy & Start — `{deploy/start command}` then `{health-check command}`
- Pass/Fail Criteria
- Evidence to Capture

**Conditional — Step 3: Live Service E2E.** Include iff the task touches ANY live service (determined in Step 2). Must contain:

- Turn-by-turn instructions with exact input per turn
- Expected output/behavior per turn
- How to verify each turn (HTTP response, log output, message queue, etc. — derived from the project's actual interfaces)

**Conditional — Step N: Additional Validation.** Include only if the task requires config checks, log checks, or other domain-specific validation beyond the standard gates.

### 4. Load the playbook template

Read `references/playbook-template.md` from this skill's directory. Use it as the canonical skeleton — fill in every `{placeholder}` with task-specific details and the project-specific commands discovered in Step 2.

### 5. Write the playbook

Write to `.smaqit/user-testing/tests/{NNN}_{slug}.md`. Derive the slug from the task title: lowercase, hyphens, drop leading article words and the task number.

Rules:

- Use the exact build, test, deploy, and health-check commands discovered in Step 2 — do not substitute hardcoded alternatives.
- Every live-service E2E turn must specify: exact input, expected output/behavior, and how to verify.
- If the playbook file already exists, ask whether to overwrite or use a different name.

### 6. Report

Report to the user:

- Path of the created playbook
- Sections included (Build Gate, Deploy, Live Service E2E, Additional Validation)
- Build/test commands used and their source (Makefile, package.json, AGENTS.md, etc.)
- Deploy/start commands used and their source
- If Live Service E2E is included, list the verification methods used

## Output

- `.smaqit/user-testing/tests/{NNN}_{slug}.md` — complete, executable test playbook

## Scope

**In scope:** Creating new test playbooks for existing tasks; probing the project for build/test/deploy commands; determining required sections from task context; including live-service E2E where applicable.

**Out of scope:** Executing playbooks (`smaqit.test-start`); modifying existing playbooks (edit directly); creating task files or modifying `PLANNING.md`.

## Examples

**Request:** `task.test-create 058`

**Agent actions:**
1. Reads `.smaqit/tasks/058_example_task.md`
2. Probes project: finds `Makefile` with `build`, `test`, `deploy` targets
3. Determines: task touches the API server (a live service)
4. Loads `references/playbook-template.md`
5. Writes `.smaqit/user-testing/tests/058_example-task.md` with Build Gate (`make build && make test`), Deploy (`make deploy`), Live Service E2E (HTTP curl + log grep), and Evidence checklist

**Output:** Playbook created at `.smaqit/user-testing/tests/058_example-task.md`. Sections: Build Gate, Deploy, Live Service E2E (HTTP curl + log grep).

## Gotchas

- Never assume a specific build tool (dotnet, go, cargo, npm, etc.). Always probe the project.
- Never assume a specific deploy mechanism (orchestrator, docker compose, systemd, etc.). Always probe the project.
- Never assume a specific health-check mechanism (custom script, HTTP endpoint, systemd status, etc.). Always probe the project.
- Never assume a specific service type (Discord, WebSocket, vLLM, etc.). Derive from the task file and project context.
- Playbook filename derives from the task title slug, not the raw task filename. Example: "021 — Assistant Multi-Turn Session Context" → `021_assistant-session-context.md`.
- If no build/test/deploy commands can be discovered, ask the user to provide them. Do not guess.

## Completion

- [ ] Task context gathered (ID, title, what it touches)
- [ ] Project probed for build, test, deploy, and health-check commands
- [ ] Required sections determined
- [ ] Playbook template loaded from `references/playbook-template.md`
- [ ] Complete playbook written to `.smaqit/user-testing/tests/{NNN}_{slug}.md`
- [ ] Build Gate step present with project-specific commands
- [ ] Deploy step present with project-specific commands
- [ ] Live Service E2E step present iff task touches live services
- [ ] No hardcoded toolchain-specific commands in playbook
- [ ] User informed of created file path and command sources

## Failure Handling

| Situation | Action |
|-----------|--------|
| Required input not provided | Request the missing information before proceeding |
| Gathered input is ambiguous | Flag the ambiguity and ask for clarification |
| Task ID not found in `.smaqit/tasks/` | Ask user to verify task ID; do not proceed without confirmation |
| Playbook already exists | Ask user: overwrite or create with different name |
| Template file not found at `references/playbook-template.md` | Use the hardcoded minimal structure from this skill's Steps section; report the missing template |
| Task context unclear (vague description) | Infer from task file ACs and implementation steps; flag assumptions to user |
| No build/test/deploy commands discoverable | Ask user to provide the commands; do not guess |
