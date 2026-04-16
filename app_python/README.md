# DevOps Info Service

[![python-ci](https://github.com/dorley174/DevOps-Core-Course/actions/workflows/python-ci.yml/badge.svg)](https://github.com/dorley174/DevOps-Core-Course/actions/workflows/python-ci.yml)

## Overview
DevOps Info Service is a production-ready starter web service for the DevOps course.
It reports service metadata, runtime details, basic system information, and a persisted visit counter.

The service exposes these endpoints:
- `GET /` — service + system + runtime + request information and increments the persisted visit counter
- `GET /visits` — returns the current visit counter without incrementing it
- `GET /health` — liveness health endpoint
- `GET /ready` — readiness health endpoint for Kubernetes
- `GET /metrics` — Prometheus metrics endpoint

## Prerequisites
- Python **3.11+**
- `pip`
- (Recommended) Virtual environment (`venv`)
- **Windows:** Python Launcher `py` is recommended

## Installation

```bash
python -m venv venv
# Windows: .\venv\Scripts\activate
# Linux/macOS: source venv/bin/activate

pip install -r requirements.txt
```

## Running the Application

### Default run (port 5000)
> If `PORT` is not set, the application runs on **0.0.0.0:5000**.
```bash
python app.py
```

### Custom configuration

**Linux/Mac:**
```bash
HOST=127.0.0.1 PORT=8080 DEBUG=True VISITS_FILE=./data/visits python app.py
```

**Windows (PowerShell):**
```powershell
$env:HOST="127.0.0.1"
$env:PORT="8080"
$env:DEBUG="True"
$env:VISITS_FILE="./data/visits"
python app.py
```

**Windows (CMD):**
```bat
set HOST=127.0.0.1
set PORT=8080
set DEBUG=True
set VISITS_FILE=./data/visits
python app.py
```

## API Endpoints

### `GET /`
Returns service metadata, system information, runtime details, request info, runtime configuration, and the current visit count.
Each request to `/` increments the persisted counter stored in `VISITS_FILE`.

Example:
```bash
curl http://127.0.0.1:5000/
```

### `GET /visits`
Returns the current counter value without incrementing it.

Example:
```bash
curl http://127.0.0.1:5000/visits
```

### `GET /health`
Returns a minimal liveness response for monitoring and Kubernetes liveness probes.

Example (includes HTTP status):
```bash
curl -i http://127.0.0.1:5000/health
```

### `GET /ready`
Returns readiness information for Kubernetes readiness probes.

Example:
```bash
curl -i http://127.0.0.1:5000/ready
```

## Local Persistence Testing with Docker Compose

A `docker-compose.yml` file is provided to verify that the visits counter survives container restarts.

### Start the service
```bash
mkdir -p data
docker compose up --build -d
```

### Generate visits
```bash
curl http://127.0.0.1:5000/
curl http://127.0.0.1:5000/
curl http://127.0.0.1:5000/visits
cat ./data/visits
```

### Restart and verify persistence
```bash
docker compose restart
docker compose ps
curl http://127.0.0.1:5000/visits
cat ./data/visits
```

### Stop the stack
```bash
docker compose down
```

## Testing / Pretty Output

### Pretty-printed JSON
**Windows PowerShell tip:** use `curl.exe`.
```bash
curl -s http://127.0.0.1:5000/ | python -m json.tool
```

## Testing & Linting (LAB03)

> Dev dependencies live in `requirements-dev.txt` (pytest, coverage, ruff).

Install dev deps:
```bash
pip install -r requirements-dev.txt
```

Run linter:
```bash
ruff check .
```

Run tests + coverage:
```bash
pytest -q tests --cov=. --cov-report=term-missing
```

## CI/CD Secrets (GitHub Actions)

In your GitHub repository:
**Settings → Secrets and variables → Actions → New repository secret**

Add:
- `DOCKERHUB_USERNAME` — your Docker Hub username
- `DOCKERHUB_TOKEN` — Docker Hub Access Token (Account Settings → Security)
- `SNYK_TOKEN` — Snyk API token (Account settings → API token)

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| HOST | `0.0.0.0` | Bind address |
| PORT | `5000` | HTTP port |
| DEBUG | `False` | Flask debug mode |
| VISITS_FILE | `/data/visits` | File used to persist the visit counter |
| APP_ENV | `dev` | Runtime environment value |
| LOG_LEVEL | `INFO` | Application log level metadata |
| CONFIG_FILE_PATH | `/config/config.json` | Mounted ConfigMap file path |
| FEATURE_VISITS_ENDPOINT | `true` | Feature flag exposed through environment variables |

---

## Docker

> Examples below use placeholders like `<image>` and `<tag>`.

### Build (local)

```bash
docker build -t <image>:<tag> .
```

### Run

```bash
docker run --rm -p 5000:5000 -e VISITS_FILE=/data/visits -v $(pwd)/data:/data <image>:<tag>
```

### Pull from Docker Hub

```bash
docker pull <dockerhub-username>/<repo>:<tag>
docker run --rm -p 5000:5000 -e VISITS_FILE=/data/visits -v $(pwd)/data:/data <dockerhub-username>/<repo>:<tag>
```

### Quick test

```bash
curl http://localhost:5000/health
curl http://localhost:5000/
curl http://localhost:5000/visits
```
