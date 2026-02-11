# DevOps Info Service

[![python-ci](https://github.com/dorley174/DevOps-Core-Course/actions/workflows/python-ci.yml/badge.svg)](https://github.com/dorley174/DevOps-Core-Course/actions/workflows/python-ci.yml)

## Overview
DevOps Info Service is a production-ready starter web service for the DevOps course.  
It reports service metadata, runtime details, and basic system information.

The service exposes two endpoints:
- `GET /` — service + system + runtime + request information
- `GET /health` — health check endpoint (used later for Kubernetes probes)

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
HOST=127.0.0.1 PORT=8080 DEBUG=True python app.py
```

**Windows (PowerShell):**
```powershell
$env:HOST="127.0.0.1"
$env:PORT="8080"
$env:DEBUG="True"
python app.py
```

**Windows (CMD):**
```bat
set HOST=127.0.0.1
set PORT=8080
set DEBUG=True
python app.py
```

## API Endpoints

### `GET /`
Returns service metadata, system information, runtime details, request info, and a list of available endpoints.

Example:
```bash
curl http://127.0.0.1:5000/
```

### `GET /health`
Returns a minimal health response for monitoring.

Example (includes HTTP status):
```bash
curl -i http://127.0.0.1:5000/health
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
| HOST     | 0.0.0.0 | Bind address |
| PORT     | 5000    | HTTP port |
| DEBUG    | False   | Flask debug mode |

---

## Docker

> Examples below use placeholders like `<image>` and `<tag>`.

### Build (local)

```bash
docker build -t <image>:<tag> .
```

### Run

```bash
docker run --rm -p 5000:5000 <image>:<tag>
```

(Optional: override env vars)

```bash
docker run --rm -p 5000:5000 -e PORT=5000 -e DEBUG=false <image>:<tag>
```

### Pull from Docker Hub

```bash
docker pull <dockerhub-username>/<repo>:<tag>
docker run --rm -p 5000:5000 <dockerhub-username>/<repo>:<tag>
```

### Quick test

```bash
curl http://localhost:5000/health
curl http://localhost:5000/
```
