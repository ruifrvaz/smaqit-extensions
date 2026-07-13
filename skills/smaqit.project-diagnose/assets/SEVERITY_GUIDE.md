# Severity Guide — smaqit.project-diagnose

Classify each failing check using the four-tier model below. Apply top-down: assign the highest tier that matches.

---

## P1 — Critical

**Definition:** Exploitable without authentication, presents a data loss risk, or blocks production launch.

**Rules:**
- An unauthenticated attacker can exploit the gap directly (no credentials required)
- Hardcoded credentials, secret keys, or tokens appear in source code or image layers
- Authentication or authorisation is absent on a sensitive endpoint
- Production deployment is blocked: a required env var has no default and is undocumented
- The backup system is non-functional: the primary database has no backup, or backups consistently fail

**Examples:**

| Finding | Why P1 |
|---------|--------|
| `RegisterRequest.role: Optional[str] = None` — caller controls their own role at registration | Unauthenticated privilege escalation: any user can self-assign admin |
| `SECRET_KEY = "dev_secret"` hardcoded in `config.py` | Anyone reading the source can forge session tokens |
| No backup covers the production PostgreSQL database | Any disk failure or accidental drop is unrecoverable |
| Auth endpoint reachable over plain HTTP in nginx config | Login credentials transmitted in cleartext |
| CORS `allow_origins=["*"]` on an API that issues session cookies | Cross-origin requests can harvest authenticated sessions |

---

## P2 — High

**Definition:** Operational risk that degrades reliability or enables an authenticated user to escalate privileges.

**Rules:**
- A logged-in user can elevate their privileges through a code pattern
- Log files are unbounded and will fill the disk under normal production load
- Health or readiness endpoints are absent (load balancer or Docker cannot detect failures)
- No rate limiting on authentication endpoints (brute force is unimpeded)
- Cookie security flags (`Secure`, `HttpOnly`, `SameSite`) are missing
- A critical data volume (vector index, object store) is not covered by backup

**Examples:**

| Finding | Why P2 |
|---------|--------|
| `FileHandler` with no rotation used in `backend/logger.py` | Logs grow unbounded; disk fill kills the service |
| Session cookie lacks `HttpOnly` flag | XSS can steal session tokens from the browser |
| No `/health` route in `backend/main.py` | Docker and nginx cannot detect backend failures; crashed container goes unnoticed |
| No rate limiting on `/auth/login` | Brute-force credential attacks succeed without detection |
| Milvus vector data volumes absent from `backup.sh` | Vector index is unrecoverable after disk failure |
| No Docker `logging:` driver config with size limits | Container logs rotate at Docker default (unlimited); disk fills silently |

---

## P3 — Medium

**Definition:** Quality or maintainability debt; the system functions correctly today but regressions are not caught automatically.

**Rules:**
- No test files or test runner configuration exists
- CI pipeline is absent (builds and tests must be run manually)
- No infrastructure-as-code (IaC); provisioning is manual but currently working
- Security scanning absent from CI (vulnerability discovery is delayed, not impossible)
- Backup exists but covers the wrong path (produces empty output)

**Examples:**

| Finding | Why P3 |
|---------|--------|
| Zero test files in `backend/` | Regressions are not caught; production bugs ship undetected |
| No `[tool.pytest.ini_options]` in `pyproject.toml` | Test runs are inconsistent; no coverage threshold enforced |
| No CI workflow for the project (only smaqit scaffolding workflows present) | Builds and tests must be run manually on every change |
| No `pip-audit` or `npm audit` step in CI | Known CVEs in dependencies are discovered late |
| `backup.sh` APP_DIR points to a path that does not match the deployed location | Backup runs without errors but produces empty or mismatched files |

---

## P4 — Low

**Definition:** Nice-to-have improvements or future-proofing with no current operational impact.

**Rules:**
- Feature is only needed when a supporting infrastructure component is added
- Improvement applies at scale, not at current deployment size
- Structural or documentation preference, not a functional requirement
- Defence-in-depth measure where the primary attack vector does not currently exist

**Examples:**

| Finding | Why P4 |
|---------|--------|
| No `/metrics` endpoint when no Prometheus server is deployed | Only required when the observability stack is added |
| NGINX uses `combined` log format instead of structured JSON | Useful for log aggregation tools not currently in use |
| No `SameSite=Strict` on cookies when no cross-site auth flow exists | Defence-in-depth with no active attack surface |
| No `dependabot.yml` for automated dependency updates | Good practice; no current exposure beyond manual updates |
| No SOPS encryption when secrets are managed locally on a single node | Useful when secrets management is centralised or multi-operator |

---

## Precedence Notes

- If a finding matches both P1 and P2 (e.g., unauthenticated endpoint with no rate limiting), assign **P1**.
- Evaluate `COOKIE_SECURE` by the **code default**, not the `.env` file — the hardcoded default is what ships to production if the env var is unset.
- Distinguish a configuration gap (P2/P3) from an active exploitation vector (P1): a missing rate limit is P2; a missing authentication check is P1.
