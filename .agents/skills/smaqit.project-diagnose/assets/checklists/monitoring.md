# Monitoring Checklist

8 checks for runtime observability and failure detection.

| Check | Pass Condition |
|-------|----------------|
| `/health` HTTP endpoint present | Route exists and returns 2xx with a basic status payload |
| `/ready` HTTP endpoint present | Route exists and probes downstream dependencies (DB, data store) before returning 200 |
| `/metrics` endpoint or instrumentation present | Metrics endpoint registered OR Prometheus/OpenMetrics middleware active |
| Metrics instrumentation library in dependencies | Instrumentation library declared in the backend package manifest |
| Container `healthcheck` present on backend service | Inventory `container.services_with_healthcheck` includes the backend service |
| Container `healthcheck` present on frontend service | Inventory `container.services_with_healthcheck` includes the frontend service |
| Container `healthcheck` present on web server service | Inventory `container.services_with_healthcheck` includes the web server service |
| Alerting configuration exists | Alerting config file present (Alertmanager, Grafana, etc.), or deployment docs include an escalation procedure |
