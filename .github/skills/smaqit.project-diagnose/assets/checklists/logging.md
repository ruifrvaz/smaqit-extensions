# Logging Checklist

10 checks for log configuration, persistence, and observability.

| Check | Pass Condition |
|-------|----------------|
| Log handler is rotating (not plain file/stream) | Inventory `logging.handler_type` is `"rotating"`; plain file or stream handler is a fail |
| Log files persisted via volume mount | Inventory `logging.volume_mount` is `true` — a log directory is mounted into the backend container |
| `LOG_LEVEL` env var present in `.env.example` | `LOG_LEVEL` key present in the env example file |
| Request correlation ID middleware present | Middleware injects a unique request ID per request that propagates into log records |
| Container log driver configured for backend | Inventory `container.services_with_logging` includes the backend service |
| Container log `max-size` limit set for backend | `max-size` option set under the backend service logging config |
| Container log `max-file` limit set for backend | `max-file` option set under the backend service logging config |
| Web server access log format is structured | Custom structured log format defined (not default `combined`); JSON or key=value preferred |
| Web server error log level configured explicitly | Error log directive present with an explicit severity level |
| Log formatter outputs structured fields | Formatter produces structured records including `timestamp`, `level`, `logger`, and `message` |
