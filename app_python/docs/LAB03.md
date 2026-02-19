# LAB03 — CI/CD (GitHub Actions)

## 1) Overview

### Testing framework
This project uses **pytest** because it provides:
- clean assertions and fixtures
- Flask test client without running a live server
- easy coverage reporting via `pytest-cov`

### Test coverage (what is tested)
- `GET /` — validates the JSON structure and required fields
- `GET /health` — validates the health-check response
- `GET /does-not-exist` — validates the JSON 404 error handler
- 500-case — forces an internal error and validates the JSON 500 error handler

### CI triggers
The workflow runs on `push` and `pull_request` for the selected branches, **only when** these paths change:
- `app_python/**`
- `.github/workflows/python-ci.yml`

### Versioning strategy
We use **CalVer** for Docker image tags:
- monthly tag: `YYYY.MM` (e.g., `2026.02`)
- build tag: `YYYY.MM.<run_number>` (e.g., `2026.02.31`)
- plus `latest`

This makes it easy to see *when* an image was built and to find the most recent build.

---

## 2) How to run locally

From the `app_python` directory:

```bash
python -m venv .venv
# Windows: .\.venv\Scripts\activate
# Linux/macOS: source .venv/bin/activate

pip install -r requirements.txt
pip install -r requirements-dev.txt

ruff check .
pytest -q tests --cov=. --cov-report=term-missing
```

---

## 3) Workflow evidence (paste links here)

Add links to prove the pipeline works:

- ✅ Successful workflow run: [https://github.com/dorley174/DevOps-Core-Course/actions/runs/21917089826/job/63287177794](https://github.com/dorley174/DevOps-Core-Course/actions/runs/21917089826/job/63287177794)
- ✅ Docker Hub image/repo: [https://hub.docker.com/repository/docker/dorley174/devops-info-service/general](https://hub.docker.com/repository/docker/dorley174/devops-info-service/general)
- ✅ Status badge in README: see `README.md` 
or go
[![python-ci](https://github.com/dorley174/DevOps-Core-Course/actions/workflows/python-ci.yml/badge.svg)](https://github.com/dorley174/DevOps-Core-Course/actions/workflows/python-ci.yml)

---

## 4) Best practices implemented

- **Path filters**: CI does not run if changes are outside `app_python/**`
- **Job dependency**: Docker push runs only if lint + tests succeeded
- **Concurrency**: cancels outdated runs on the same branch
- **Least privileges**: `permissions: contents: read`
- **Caching**:
  - pip cache via `actions/setup-python`
  - Docker layer cache via `cache-to/cache-from type=gha`
- **Snyk scan**:
  - scans dependencies from `requirements.txt`
  - severity threshold = high
  - `continue-on-error: true` (learning mode; does not block pipeline)
