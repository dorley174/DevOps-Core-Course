# Lab07 — Observability & Logging with Loki Stack

## Summary

This implementation follows the lab requirements and is adapted to a fully local, free workflow on Windows 11 using WSL2. The repository now contains:

- a ready-to-run Loki + Promtail + Grafana stack in `monitoring/`
- structured JSON logging in the Python Flask app
- Grafana data source provisioning
- a prebuilt Grafana dashboard definition with four required panels
- an optional Ansible automation role (`roles/monitoring`) and playbook (`playbooks/deploy-monitoring.yml`)

The final practical validation for this lab was completed locally with Docker Compose in WSL2.

## Architecture

```text
+-------------------+        +-------------------+
|   Python App      |        |   Grafana         |
| JSON logs stdout  |        | dashboards/query  |
+---------+---------+        +---------+---------+
          |                            |
          | Docker json-file logs      | HTTP API / UI
          v                            |
+---------+---------+                  |
|   Promtail        |  push logs       |
| docker_sd_configs +----------------> |
+---------+---------+                  |
          |                            v
          |                      +-----+------+
          +--------------------> |   Loki     |
                                 | TSDB + FS  |
                                 +------------+
```

## Repository Structure

```text
monitoring/
├── .env.example
├── docker-compose.yml
├── docs/
│   ├── LAB07.md
│   ├── LOCAL_VALIDATION_WINDOWS.md
│   └── screenshots/
├── grafana/
│   ├── dashboards/
│   │   └── lab07-logging.json
│   └── provisioning/
│       ├── dashboards/
│       │   └── dashboard-provider.yml
│       └── datasources/
│           └── loki.yml
├── loki/
│   └── config.yml
└── promtail/
    └── config.yml
```

## Configuration Notes

### Loki

- single-node deployment
- `store: tsdb`
- `schema: v13`
- filesystem-backed local storage
- 7-day retention (`168h`)
- compactor enabled for retention processing

### Promtail

- Docker service discovery via `docker_sd_configs`
- filters only containers with label `logging=promtail`
- extracts container name into the `container` label
- keeps the application label from Docker metadata as `app`
- uses the `docker` pipeline stage so Docker JSON logs are parsed correctly

### Grafana

- anonymous access disabled
- admin password loaded from `.env`
- Loki data source provisioned automatically on startup
- dashboard provider loads a ready-made dashboard from disk

## Application Logging

The Flask app emits structured JSON logs to stdout using a custom `JSONFormatter`.

Logged events include:
- service startup
- request start
- request completion with method/path/status/client IP/duration
- 404 events
- unhandled 500 errors with exception details

Example log line:

```json
{"timestamp":"2026-03-13T01:11:28.923Z","level":"INFO","logger":"werkzeug","message":"127.0.0.1 - - [13/Mar/2026 01:11:28] \"GET /health HTTP/1.1\" 200 -"}
```

## Dashboard

The provisioned dashboard contains four required panels:

1. **Recent Logs (all apps)** — logs panel
2. **Request Rate by App** — time series
3. **Error Logs Only** — logs panel filtered by log level
4. **Log Level Distribution (last 5m)** — pie chart grouped by log level

## Production Readiness Choices

- resource constraints were added to all services
- Grafana anonymous authentication is disabled
- Grafana admin credentials are externalized through `.env`
- health checks were added for Loki, Promtail, Grafana, and the Python app
- Loki retention is set to 7 days to prevent unbounded log growth

## Local Validation Workflow

The stack was validated locally from WSL2 using Docker Compose.

Commands used:

```bash
cd monitoring
cp .env.example .env
# edit Grafana admin password in .env

docker compose up -d --build
docker compose ps
curl http://127.0.0.1:3100/ready
curl http://127.0.0.1:3000
curl http://127.0.0.1:8000/health
```

Traffic generation used for log validation:

```bash
curl http://127.0.0.1:8000/
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/
curl http://127.0.0.1:8000/health
```

## Validation Results

The monitoring stack was validated successfully in a fully local Windows 11 + WSL2 environment using Docker Compose.

Confirmed results:
- Grafana is reachable on `http://127.0.0.1:3000`
- Loki is reachable on `http://127.0.0.1:3100/ready` and returns `ready`
- the Flask application is reachable on `http://127.0.0.1:8000`
- the application health endpoint returns a successful JSON response
- container logs are ingested into Loki and visible in Grafana Explore

The following LogQL query was confirmed to work locally:

```logql
{job="docker", app="devops-python"}
```

A broader query also returned logs successfully:

```logql
{job="docker"}
```

The returned logs included Flask access entries such as `GET /health` and `GET /`.

## Recommended LogQL Queries

Working queries confirmed locally:

```logql
{job="docker"}
{job="docker", app="devops-python"}
{job="docker", container="devops-python"}
{job="docker", service_name="devops-python"}
```

Additional useful queries:

```logql
{app="devops-python"} | json | level="INFO"
{app="devops-python"} | json | level="ERROR"
{app="devops-python"} | json | method="GET"
sum by (app) (rate({job="docker"}[1m]))
sum by (level) (count_over_time({job="docker"} | json [5m]))
```

## Ansible Bonus Automation

The repository also includes bonus automation for the existing Lab06 Ansible layout:

- role: `ansible/roles/monitoring`
- playbook: `ansible/playbooks/deploy-monitoring.yml`

The role:
- depends on the existing `docker` role
- creates the monitoring directory structure on the VM
- copies the local Python app source to the target host
- templates Loki, Promtail, Grafana, and Docker Compose files
- builds the Python app locally on the target VM with Docker Compose v2
- verifies Loki, Grafana, the app health endpoint, and the provisioned data source

## Challenges and Practical Notes

1. **Windows + WSL2 networking**
   - forwarded ports from VirtualBox may work on Windows `127.0.0.1` but require the current Windows host IP from inside WSL
2. **Registry/network instability**
   - in this environment, network timeouts to Docker infrastructure are possible
   - the final successful validation was completed locally with Docker Compose in WSL2
3. **Promtail lifecycle**
   - the lab still requires Promtail, so this solution keeps it
   - for long-term production use, plan a future migration path to Grafana Alloy

## Captured Screenshots

The following screenshots should be saved under `monitoring/docs/screenshots/`:

- `grafana-login.png` — Grafana login page
- `grafana-datasource-loki.png` — Loki datasource with successful connection test
- `grafana-explore-all-logs.png` — Grafana Explore with the broad query `{job="docker"}`
- `grafana-explore-app-logs.png` — Grafana Explore with application-specific logs using `{job="docker", app="devops-python"}`
- `grafana-dashboard.png` — provisioned dashboard with visible log/metrics panels
- `app-health-and-stack.png` — terminal validation with `docker compose ps`, Loki ready check, and app health check

## Evidence Captured Locally

The following evidence was captured after the stack started successfully:

- Grafana login page
- Loki datasource connection test
- Grafana Explore with working LogQL queries
- provisioned dashboard
- successful Loki readiness check
- successful application health check
- running Docker Compose services

## Conclusion

Lab07 was completed successfully in a local Windows 11 + WSL2 environment. The Grafana + Loki + Promtail stack is running, the Flask application emits structured JSON logs, and those logs are visible in Grafana through Loki. Local validation confirmed successful service startup, log ingestion, and dashboard availability.