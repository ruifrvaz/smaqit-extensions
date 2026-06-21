# Security Checklist

14 checks for security posture at system boundaries.

| Check | Pass Condition |
|-------|----------------|
| Caller-supplied `role` in registration schema | `role` field absent from the inbound request schema, OR field is not caller-settable (hardcoded server-side, not accepted from request body) |
| Role field has no exploitable default | If `role` field exists, default must be hardcoded to an unprivileged value (e.g. `"user"`); `null`/`None` or missing default is a fail |
| `SECRET_KEY` / `AUTH_SECRET` has no hardcoded fallback | No hardcoded fallback string; key is required and raises an error if absent |
| `COOKIE_SECURE` defaults to `True` | Default is `True`/`Secure`, or the env var is required with no fallback |
| Cookie `HttpOnly` flag enabled | `httponly=True` (or `HttpOnly` header directive) present on auth cookies |
| Cookie `SameSite` attribute set | `samesite="lax"` or `"strict"` (or `SameSite=Lax/Strict` header) present |
| Rate limiting middleware present | Rate limiting middleware registered on the application |
| Rate limiting applied to auth endpoints | At least the login route has a rate limit decorator or is covered by a global limiter |
| CSRF protection or CORS restricted to known origins | `allow_origins` does not include `"*"` on a state-modifying API; or CSRF token middleware present |
| Local login flag enforced in login route | Login route returns 403/disabled when the local login feature flag is disabled; flag is not silently ignored |
| File upload validates MIME type | MIME type checked against an allowlist before processing |
| File upload validates file size | Size limit enforced before processing |
| File path operations use safe join | Paths constructed with safe join + realpath check, or UUID-based storage keys used (no raw user-supplied filenames in paths) |
| Web server adds security response headers | At least `X-Frame-Options`, `X-Content-Type-Options`, and `Referrer-Policy` headers present |
