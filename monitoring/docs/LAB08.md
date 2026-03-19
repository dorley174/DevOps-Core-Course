# Lab08 — Metrics & Monitoring with Prometheus

## Summary

This implementation extends the existing Lab07 observability stack with Prometheus-based metrics collection and a Grafana metrics dashboard.

The solution is designed for a fully local, free workflow:
- Windows host
- WSL2 for Linux tooling
- optional Vagrant VM for a 100% local deployment target
- no external cloud services required

The repository now contains:
- Prometheus instrumentation in the Python Flask application
- a `/metrics` endpoint compatible with Prometheus scraping
- a Prometheus service added to `monitoring/docker-compose.yml`
- Grafana provisioning for both Loki and Prometheus data sources
- a prebuilt Grafana metrics dashboard with 9 panels
- updated local validation instructions for Windows + WSL2 + Vagrant
- extended Ansible automation for the full Loki + Prometheus + Grafana stack

## Architecture

```text
                         +-----------------------+
                         |      Grafana          |
                         | dashboards + Explore  |
                         +-----------+-----------+
                                     ^
                                     |
                      +--------------+---------------+
                      |                              |
                      |                              |
              metrics |                              | logs
                      |                              |
                      |                              |
+---------------------+-----+              +---------+---------+
|   Python Flask App        |              |     Promtail      |
|  /, /health, /metrics     |              | Docker SD + labels|
+------------+--------------+              +---------+---------+
             |                                       |
             | scrape                                | push
             v                                       v
      +------+----------------+              +-------+--------+
      |      Prometheus       |              |      Loki      |
      | pull-based TSDB       |              | log storage    |
      +-----------------------+              +----------------+
```

## Repository Structure

```text
monitoring/
├── .env.example
├── docker-compose.yml
├── docs/
│   ├── LAB07.md
│   ├── LAB08.md
│   ├── LOCAL_VALIDATION_WINDOWS.md
│   └── screenshots/
├── grafana/
│   ├── dashboards/
│   │   ├── lab07-logging.json
│   │   └── lab08-metrics.json
│   └── provisioning/
│       ├── dashboards/
│       │   └── dashboard-provider.yml
│       └── datasources/
│           └── loki.yml
├── loki/
│   └── config.yml
├── prometheus/
│   └── prometheus.yml
└── promtail/
    └── config.yml
```

## Application Instrumentation

### Metrics added to the Flask application

#### 1. HTTP request counter

Metric:

```text
http_requests_total{method, endpoint, status_code}
```

Purpose:
- total request volume
- request rate calculations
- status code distribution
- error rate calculations

#### 2. HTTP request duration histogram

Metric:

```text
http_request_duration_seconds{method, endpoint}
```

Purpose:
- latency measurements
- percentile calculations such as p95
- heatmap visualizations for duration buckets

Note:
- `status_code` is intentionally not used on the latency histogram to avoid unnecessary cardinality growth and to keep PromQL queries simpler

#### 3. In-progress requests gauge

Metric:

```text
http_requests_in_progress
```

Purpose:
- concurrent request visibility
- simple saturation signal
- active request panel in Grafana

#### 4. Application-specific business metrics

Metrics:

```text
devops_info_endpoint_calls_total{endpoint}
devops_info_system_collection_seconds
devops_info_uptime_seconds
```

Purpose:
- endpoint usage tracking
- system information collection cost tracking
- current service uptime for dashboards and troubleshooting

### Instrumentation design choices

- request metrics are collected in Flask hooks (`before_request`, `after_request`, `teardown_request`)
- endpoint labels are normalized to avoid high-cardinality labels
- unknown routes are grouped as `unmatched`
- `/metrics` scrape traffic is excluded from request-rate business metrics to avoid self-scrape noise in dashboards
- `/metrics` keeps the Prometheus content type and is not overwritten by the JSON response middleware
- the in-progress gauge is decremented in `teardown_request` to avoid leaks in error scenarios

## Prometheus Configuration

File:

```text
monitoring/prometheus/prometheus.yml
```

### Scrape settings

- scrape interval: `15s`
- evaluation interval: `15s`

### Scrape targets

1. `prometheus`
   - target: `localhost:9090`
2. `app`
   - target: `app-python:8000`
   - path: `/metrics`
3. `loki`
   - target: `loki:3100`
4. `grafana`
   - target: `grafana:3000`

### Retention policy

Prometheus retention is configured via container flags in `docker-compose.yml`:

```text
--storage.tsdb.retention.time=15d
--storage.tsdb.retention.size=10GB
```

Why this matters:
- avoids unbounded disk usage
- keeps local storage predictable on a laptop or VM
- is fully compatible with a free local deployment model

## Grafana Dashboard Walkthrough

Dashboard file:

```text
monitoring/grafana/dashboards/lab08-metrics.json
```

The dashboard includes 9 panels.

### 1. Request Rate by Endpoint

Query:

```promql
sum by (endpoint) (rate(http_requests_total{endpoint!="/metrics"}[5m]))
```

Purpose:
- visualizes request throughput
- supports the **R** in RED

### 2. Error Rate (5xx)

Query:

```promql
sum(rate(http_requests_total{status_code=~"5.."}[5m]))
```

Purpose:
- shows server-side errors per second
- supports the **E** in RED

### 3. Request Duration p95 by Endpoint

Query:

```promql
histogram_quantile(0.95, sum by (le, endpoint) (rate(http_request_duration_seconds_bucket{endpoint!="/metrics"}[5m])))
```

Purpose:
- tracks latency percentiles
- supports the **D** in RED

### 4. Active Requests

Query:

```promql
sum(http_requests_in_progress)
```

Purpose:
- highlights current concurrency pressure

### 5. Application Uptime

Query:

```promql
max(devops_info_uptime_seconds)
```

Purpose:
- confirms the service is alive and progressing normally

### 6. Request Duration Heatmap

Query:

```promql
sum by (le) (rate(http_request_duration_seconds_bucket{endpoint!="/metrics"}[5m]))
```

Purpose:
- visualizes latency bucket distribution over time

### 7. Status Code Distribution

Query:

```promql
sum by (status_code) (rate(http_requests_total[5m]))
```

Purpose:
- shows how traffic is split across response classes and codes

### 8. App Target Uptime

Query:

```promql
up{job="app"}
```

Purpose:
- shows whether Prometheus is successfully scraping the application

### 9. System Info Collection p95

Query:

```promql
histogram_quantile(0.95, sum by (le) (rate(devops_info_system_collection_seconds_bucket[5m])))
```

Purpose:
- tracks the internal cost of the service-specific system information collection function

## PromQL Examples

### RED method queries

```promql
sum by (endpoint) (rate(http_requests_total{endpoint!="/metrics"}[5m]))
sum(rate(http_requests_total{status_code=~"5.."}[5m]))
histogram_quantile(0.95, sum by (le, endpoint) (rate(http_request_duration_seconds_bucket{endpoint!="/metrics"}[5m])))
```

### Additional useful queries

```promql
sum by (status_code) (rate(http_requests_total[5m]))
sum(http_requests_in_progress)
up{job="app"}
max(devops_info_uptime_seconds)
sum by (job) (up)
histogram_quantile(0.95, sum by (le) (rate(devops_info_system_collection_seconds_bucket[5m])))
```

## Production Setup

### Health checks

Health checks are configured for:
- Loki
- Promtail
- Grafana
- Prometheus
- Python application

### Resource limits

Configured Docker Compose limits:

| Service | CPU | Memory |
|--------|-----|--------|
| Loki | 1.0 | 1G |
| Promtail | 0.5 | 512M |
| Grafana | 0.5 | 512M |
| Prometheus | 1.0 | 1G |
| App | 0.5 | 256M |

### Persistence

Named volumes:
- `loki-data`
- `promtail-data`
- `grafana-data`
- `prometheus-data`

### Security and operational choices

- Grafana anonymous access is disabled
- Grafana credentials are externalized via `.env`
- Grafana metrics are explicitly enabled for Prometheus scraping
- the app health check uses Python stdlib instead of `curl` to keep the slim image lightweight

## Local Run Commands

### Docker Compose from WSL2

```bash
cd monitoring
cp .env.example .env
# edit GRAFANA_ADMIN_PASSWORD in .env

docker compose up -d --build
docker compose ps
```

### Generate traffic

```bash
for i in {1..25}; do curl -s http://127.0.0.1:8000/ > /dev/null; done
for i in {1..25}; do curl -s http://127.0.0.1:8000/health > /dev/null; done
curl -s http://127.0.0.1:8000/does-not-exist > /dev/null
curl -s http://127.0.0.1:8000/metrics | head -40
```

### Validate Prometheus

```bash
curl http://127.0.0.1:9090/-/healthy
curl http://127.0.0.1:9090/api/v1/targets | python -m json.tool
```

Open in browser:
- `http://127.0.0.1:9090/targets`
- `http://127.0.0.1:3000`

### Useful Grafana checks

- Confirm both data sources are provisioned: Loki and Prometheus
- Open dashboard: `Lab08 - Prometheus Metrics Overview`
- Run ad hoc PromQL query: `up`

## Testing Results

### Static validation completed in the sandbox

The following checks were completed while preparing this repository update:
- Python syntax validation for the Flask application
- JSON validation for the Grafana dashboard file
- YAML validation for Docker Compose, Prometheus, Loki, and Promtail configuration files
- local application runtime validation for `/`, `/health`, `/metrics`, and request counters

Captured application-side evidence is stored in:

```text
monitoring/docs/evidence/
```

Files included there:
- `app-root.json`
- `app-health.json`
- `app-metrics-sample.txt`
- `app-metrics-headers.txt`

### Full stack runtime validation to run locally

Because the sandbox used to prepare this patch does not provide a Docker daemon, UI screenshots and multi-container runtime proofs must be captured locally with the provided commands.

Recommended screenshots to capture locally:
- all `lab08*.png` files in `monitoring/docs/screenshots`


## Metrics vs Logs

### Use metrics when you need
- rates and trends over time
- low-cost aggregation
- alert thresholds
- latency and saturation views

### Use logs when you need
- exact event details
- request-specific context
- raw error messages and stack traces
- forensic troubleshooting

### Combined observability model in this repository

- **Loki + Promtail** answer: *what happened?*
- **Prometheus** answers: *how much, how often, how fast?*
- **Grafana** provides one UI for both views

## Challenges and Solutions

### 1. `/metrics` vs JSON middleware

Problem:
- the existing `after_request` hook forced `application/json` on every response

Solution:
- the hook now preserves the Prometheus metrics content type and only rewrites JSON responses

### 2. Label cardinality control

Problem:
- raw request paths can create unbounded label values

Solution:
- metrics use normalized endpoints and group unknown routes as `unmatched`

### 3. In-progress gauge correctness

Problem:
- a gauge can leak if it is incremented but not decremented during exceptions

Solution:
- the decrement is handled in `teardown_request`

### 4. Windows + WSL2 + Vagrant networking

Problem:
- forwarded ports can behave differently in Windows and WSL2

Solution:
- the local validation guide includes both localhost and host-IP guidance

### 5. Free local deployment requirement

Problem:
- the lab should not depend on paid services or third-party cloud platforms

Solution:
- the full stack runs locally with Docker Compose and can also run on the Vagrant VM via Ansible

## Bonus — Ansible Automation

The existing `ansible/roles/monitoring` role was extended to cover Lab08 as well.

Implemented bonus scope:
- Prometheus variables added to role defaults
- Prometheus config generated from a Jinja2 template
- Docker Compose template updated to include Prometheus
- Grafana provisioning now includes both Loki and Prometheus data sources
- the Lab08 dashboard JSON is rendered by Ansible automatically
- the deployment task verifies Prometheus health and both data sources

Playbook:

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook -i inventory/hosts.ini playbooks/deploy-monitoring.yml
```

## Evidence Checklist

After you run the stack locally, verify the following:

- `/metrics` endpoint returns Prometheus-formatted metrics
- Prometheus `/targets` shows all targets as `UP`
- Grafana has both Loki and Prometheus data sources
- the Lab08 dashboard shows live data in all panels
- `docker compose ps` shows healthy containers
- dashboards survive `docker compose down` / `docker compose up -d`

All these checklist you can see as a screenshots in:
- all `lab08*.png` files in `monitoring/docs/screenshots`
