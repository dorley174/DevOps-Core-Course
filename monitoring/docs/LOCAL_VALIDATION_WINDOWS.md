# Local Validation on Windows 11 (WSL2 + Vagrant-friendly)

This guide is tailored for a fully local and free setup:
- Windows host
- WSL2 for Linux commands
- VS Code connected to WSL2
- optional Vagrant VM for a dedicated Linux target
- no external cloud services required

## Ports used by the observability stack

- App: `8000`
- Grafana: `3000`
- Loki: `3100`
- Promtail: `9080`
- Prometheus: `9090`

## Option A — Run directly from WSL2

### 1. Prepare environment file

```bash
cd monitoring
cp .env.example .env
```

Set a real Grafana password in `.env`.

### 2. Start the stack

```bash
docker compose up -d --build
docker compose ps
```

### 3. Verify endpoints

```bash
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/metrics | head -40
curl http://127.0.0.1:3100/ready
curl http://127.0.0.1:9080/targets
curl http://127.0.0.1:9090/-/healthy
```

### 4. Open browser pages

- Grafana: `http://127.0.0.1:3000`
- Prometheus targets: `http://127.0.0.1:9090/targets`
- Prometheus graph: `http://127.0.0.1:9090/graph`

### 5. Generate traffic

```bash
for i in {1..30}; do curl -s http://127.0.0.1:8000/ > /dev/null; done
for i in {1..30}; do curl -s http://127.0.0.1:8000/health > /dev/null; done
curl -s http://127.0.0.1:8000/does-not-exist > /dev/null
```

### 6. Prometheus queries to test

```promql
up
sum by (endpoint) (rate(http_requests_total{endpoint!="/metrics"}[5m]))
sum(rate(http_requests_total{status_code=~"5.."}[5m]))
histogram_quantile(0.95, sum by (le, endpoint) (rate(http_request_duration_seconds_bucket{endpoint!="/metrics"}[5m])))
sum by (status_code) (rate(http_requests_total[5m]))
```

### 7. Grafana checks

- log in with the credentials from `.env`
- confirm both data sources exist: Loki and Prometheus
- open the `Lab08 - Prometheus Metrics Overview` dashboard
- verify the panels update after traffic generation

## Option B — Run on the Vagrant VM

### 1. Reload Vagrant to apply port forwarding

```powershell
vagrant reload
vagrant status
vagrant port
```

### 2. Run Ansible deployment from WSL2

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook -i inventory/hosts.ini playbooks/deploy-monitoring.yml
```

### 3. Verify from the Windows host or WSL2

```bash
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:9090/-/healthy
```

If WSL2 cannot reach forwarded ports through `127.0.0.1`, use the current Windows host IP.

## PowerShell traffic generation

```powershell
1..30 | ForEach-Object { Invoke-WebRequest -UseBasicParsing http://127.0.0.1:8000/ | Out-Null }
1..30 | ForEach-Object { Invoke-WebRequest -UseBasicParsing http://127.0.0.1:8000/health | Out-Null }
try { Invoke-WebRequest -UseBasicParsing http://127.0.0.1:8000/does-not-exist | Out-Null } catch {}
```

## What to capture for proof

- `/metrics` endpoint output in the browser or terminal
- Prometheus `/targets` page with all targets `UP`
- Prometheus query page with `up`
- Grafana Prometheus data source test
- Grafana dashboard with all panels populated
- `docker compose ps` showing healthy services
