---
name: smaqit.project-diagnose
description: Use this skill when the user asks to run a diagnostic or scan the project for gaps or requests a check on security posture, test coverage, logging setup, monitoring coverage, provisioning, or CI/CD pipelines. Scans six domains (Testing, Security, Logging, Monitoring, Provisioning, CI/CD) using a deterministic filesystem inventory and domain checklists, then produces a prioritised finding report at `.smaqit/reports/diagnose-YYYY-MM-DD.md`. Supports `--tasks` to generate smaqit tasks for new gaps, domain scoping (e.g. `project.diagnose security,logging`), and `--refresh` to overwrite an existing same-day report.
metadata:
  version: "1.1.1"
compatibility: "bash, python3; Linux; no network access required"
---

# Project Diagnose

## Steps

### Step 1 — Load smaqit context

Read these files if they exist, in order:

1. `.smaqit/project-recap.md` — stack, services, deployment topology
2. `.smaqit/references/project-research.md` — dependency versions
3. `.smaqit/compendium.md` — prior findings (deduplication source)
4. `.smaqit/tasks/PLANNING.md` — existing tasks (deduplication source)
5. `specs/business/`, `specs/functional/`, `specs/stack/` — declared intent vs. live reality
6. `.github/copilot-instructions.md` (GitHub Copilot), `CLAUDE.md` (Claude Code), or `AGENTS.md` (Codex) — project conventions and deployment path

Extract: **Stack** (languages, runtimes, frameworks), **Infrastructure** (container runtime, web server, database), **Existing task titles**, **Known compendium findings**.

### Step 1.5 — Resolve StackProfile

Using the context loaded in Step 1, resolve a `StackProfile` — a key/value map used by all subsequent steps. For each field, scan the project structure and infer the value from what is actually present; do not assume a specific stack or layout:

| Field | What to look for | Fallback |
|-------|-----------------|----------|
| `backend_dir` | Directory containing a server-side package manifest, build descriptor, or primary entrypoint | `src/`, `.` |
| `frontend_dir` | Directory containing a UI framework manifest or configuration (a dependency on a frontend framework is the signal) | `client/`, `web/` |
| `backend_lang` | Infer from the package manifest or build descriptor found in `backend_dir` | `unknown` |
| `frontend_lang` | Infer from the presence of a TypeScript config; otherwise assume JavaScript | `unknown` |
| `test_backend_patterns` | Derive from `backend_lang`: use the idiomatic test file naming convention for that language and its standard test runner | `*test*` |
| `test_frontend_patterns` | Derive from `frontend_lang` and the test runner declared in the frontend manifest | `*test*,*spec*` |
| `vendor_excludes` | Derive from `backend_lang`: identify the standard dependency cache and build output directories that should be excluded from source scans | `vendor` |
| `log_file` | Look for a logging module or log configuration file in `backend_dir` | `unknown` |
| `compose_file` | Look for a container orchestration file at the project root | `none` |
| `web_server_config` | Look for a web server or reverse proxy configuration file or directory | `none` |
| `backup_script` | Look for a backup script in `scripts/` or at the project root | `none` |
| `iac_dir` | Look for an infrastructure-as-code directory (provisioning, deployment, or configuration management) | `none` |
| `ci_dir` | Look for a CI/CD configuration file or directory | `none` |
| `secret_tool` | Look for a secrets management configuration file; if none found, record `none` | `none` |

Record the resolved StackProfile. Pass it as environment variables to the inventory script in Step 2.

### Step 2 — Run inventory script

Set StackProfile fields as environment variables, then run:

```bash
DIAG_BACKEND_DIR="<backend_dir>" \
DIAG_FRONTEND_DIR="<frontend_dir>" \
DIAG_BACKEND_LANG="<backend_lang>" \
DIAG_TEST_BACKEND_PATTERNS="<test_backend_patterns>" \
DIAG_TEST_FRONTEND_PATTERNS="<test_frontend_patterns>" \
DIAG_VENDOR_EXCLUDES="<vendor_excludes>" \
DIAG_LOG_FILE="<log_file>" \
DIAG_COMPOSE_FILE="<compose_file>" \
DIAG_BACKUP_SCRIPT="<backup_script>" \
bash [SMAQIT_SKILLS_DIR]/smaqit.project-diagnose/scripts/diagnose-inventory.sh
```

Captures: test file counts, test config presence, non-smaqit CI workflows, log handler type/class, log volume mount, container service logging and healthcheck status, backup script path value, systemd unit presence, env keys, secrets tool config.

**Fallback**: if the script fails, read source files directly to gather equivalent facts. Log warning in the report header: "Inventory script unavailable — using manual file inspection."

### Step 3 — Domain scan loop

For each in-scope domain, load the checklist from `assets/checklists/<domain>.md`. Each check specifies only the **Pass Condition** — what constitutes a pass. Use the following approach to determine what to inspect:

1. **Use StackProfile fields** (resolved in Step 1.5) to locate the relevant directory or file category (backend source dir, compose file, log file, backup script, CI config dir, etc.)
2. **Run targeted directory scans** as needed (e.g. `find`, `grep`, `ls`) to discover the concrete files matching each role
3. **Use inventory JSON** (from Step 2) for facts already collected (test counts, handler type, service lists, backup flags, etc.) — these do not require re-scanning
4. **Assign severity** using `assets/SEVERITY_GUIDE.md` based on the nature and impact of each failing check

Record each check as **Pass**, **Fail**, or **N/A** (not applicable to this stack).

**Load the relevant checklist file before scanning each domain:**

| Domain | Checklist |
|--------|-----------|
| Testing | `assets/checklists/testing.md` |
| Security | `assets/checklists/security.md` |
| Logging | `assets/checklists/logging.md` |
| Monitoring | `assets/checklists/monitoring.md` |
| Provisioning | `assets/checklists/provisioning.md` |
| CI/CD | `assets/checklists/cicd.md` |

### Step 4 — Severity classification

Read `assets/SEVERITY_GUIDE.md` before classifying any finding. Apply to each failing check:

- **P1** — exploitable without authentication, data loss risk, or blocks production launch
- **P2** — operational risk, reliability degradation, or authenticated escalation vector
- **P3** — quality/maintainability debt; no immediate runtime impact
- **P4** — nice-to-have; future-proofing with no current operational need

### Step 5 — Deduplicate

For each failing check:

1. Semantically compare against PLANNING.md task titles → mark as **Already Tracked**
2. Semantically compare against compendium.md answers → mark as **Known Finding**
3. All remaining findings are **New**

Deduplication is semantic, not string-equality. "Fix session cookie secure flag" and "Enable COOKIE_SECURE in production" are the same finding.

Report all findings regardless of dedup status. Only **New** findings are eligible for task creation.

### Step 6 — Write report

Output path: `.smaqit/reports/diagnose-YYYY-MM-DD.md`

If the file exists and `--refresh` is not set: compare new findings against the existing file. If identical, output "No new findings since last diagnose run (YYYY-MM-DD)." and stop.

Otherwise, write the report using `assets/REPORT_TEMPLATE.md` as the structure. The report must include:
- Run metadata: date, domains scanned, total checks run, finding counts by severity
- Executive summary table: domain × severity counts
- Per-domain findings table: severity | check | affected file | recommendation | status
- Priority matrix: P1–P4 ordered list with dependency hints
- Already-tracked cross-reference: findings mapped to existing task IDs

### Step 7 — Create tasks (only with `--tasks` flag)

For each New finding meeting `--min-severity` threshold (default: all):

1. Derive a task title from the finding description
2. Re-check PLANNING.md to confirm no equivalent task was just added
3. Invoke `smaqit.task-create` with the recommendation as the task description

Report: "N tasks created for new findings."

### Step 8 — Update compendium

For each New finding with sufficient detail to form a useful Q&A pair, add to `.smaqit/compendium.md`:
- Category: Security, Operations, or Architecture
- Question: the gap as a question ("Does the backend enforce X?")
- Answer: the finding and recommendation

Report: "Compendium updated — N entries added."

## Output

| Artifact | Path | Condition |
|----------|------|-----------|
| Diagnose report | `.smaqit/reports/diagnose-YYYY-MM-DD.md` | Always |
| Task files | `.smaqit/tasks/NNN_*.md` | Only with `--tasks` |
| Compendium update | `.smaqit/compendium.md` | Only for new findings |

## Scope

**In scope:** Structural SDLC gaps (missing test infrastructure, CI pipelines, log configuration, health endpoints, backup coverage, secrets handling), code-level security patterns at system boundaries (auth endpoints, Pydantic models, cookie/header config), configuration gaps (missing env vars, misconfigured Docker services).

**Out of scope:** Runtime probing (no live HTTP calls to the running application), CVE/dependency vulnerability scanning (use `smaqit.utils.triage-issues`), business logic correctness or functional completeness, performance analysis.

## Examples

### Example 1 — Full scan, report only

**Input:** `project.diagnose`

**Output:** `.smaqit/reports/diagnose-2026-05-20.md` with 6 domain sections, 20 findings (P1: 6, P2: 7, P3: 5, P4: 2). No tasks created. Console: "Diagnose complete — 20 findings across 6 domains. Report: .smaqit/reports/diagnose-2026-05-20.md"

### Example 2 — Scoped scan with task generation

**Input:** `project.diagnose security --tasks`

**Output:** `.smaqit/reports/diagnose-2026-05-20.md` (security domain only, 6 findings). 4 new tasks created (2 already tracked in PLANNING.md). Console: "Diagnose complete — 6 security findings. 4 tasks created."

### Example 3 — Re-run on fully-tasked project

**Input:** `project.diagnose`

**Output:** Existing report read; all findings match PLANNING.md tasks. Console: "No new findings — all 20 gaps already tracked. Report unchanged."

## Gotchas

- **Exclude vendor directories from test file discovery** — use StackProfile `vendor_excludes` to suppress false positives (e.g. Python `.venv`, Node `node_modules`, Go `vendor`, Java `target`)
- **Security analysis requires reading the request schema layer, not just route decorators** — privilege escalation vulnerabilities live in the model/DTO/schema definitions (e.g. Pydantic model fields, Zod schemas, class-validator DTOs), which are invisible from route signatures alone
- **Container healthchecks and application `/health` endpoints are independent gaps** — a service can have a container-level healthcheck without a real HTTP health route, and vice versa; both must be checked separately
- **Backup script path correctness requires cross-referencing** — compare any hardcoded deployment path in the backup script against the actual path declared in project documentation (`project-recap.md`, `copilot-instructions.md`, `CLAUDE.md`, `AGENTS.md`, or equivalent)
- **Log persistence requires both**: a rotating log handler in the application AND a volume/mount mapping log output outside the container; either alone is insufficient
- **CI/CD gap check**: the CI dir may contain smaqit framework workflows — exclude files whose name or top-level comment contains `smaqit`; report only application-specific build/test/scan workflows
- **Cookie/session security flags are production-context findings** — a hardcoded insecure default that is overridable by env var is the gap; look for the fallback pattern (`os.environ.get("VAR", insecure_default)`), not just the current runtime value
- **Deduplication is semantic, not string-equality** — "Fix session cookie secure flag" and "Enable COOKIE_SECURE in production" are the same finding; use meaning-based comparison
- **StackProfile fields marked `unknown` do not skip the domain** — apply the checklist using inference and flag N/A for individual checks whose file cannot be located

## Completion

- [ ] All in-scope domain checklists applied and results recorded
- [ ] Report written to `.smaqit/reports/diagnose-YYYY-MM-DD.md`
- [ ] All findings include severity, affected file, and recommendation
- [ ] Deduplication performed: no task created for an already-tracked gap
- [ ] Compendium updated with new findings

## Failure Handling

| Situation | Action |
|-----------|--------|
| Required input not provided | Request the missing information before proceeding |
| Gathered input is ambiguous | Flag the ambiguity and ask for clarification |
| Subagent invocation fails | Report the failure with context; do not silently retry |
| Output artifact already exists | Confirm with user before overwriting |
| Inventory script missing or fails | Fall back to manual file inspection; log warning in report header |
| A domain's source files are absent | Mark all checks for that domain as N/A; note in report |
| PLANNING.md missing | Treat as empty; all findings are New |
| compendium.md missing | Treat as empty; create it on first write |
| `--tasks` requested but `smaqit.task-create` fails | Log failure in report; continue with remaining findings |
