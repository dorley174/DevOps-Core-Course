# LAB01 — DevOps Info Service (Python)

## 1) Framework Selection

### Chosen Framework: Flask

I chose **Flask** because:
- It is lightweight and easy to set up for a small service with 2 endpoints.
- Minimal boilerplate: perfect for a “foundation” lab where the focus is DevOps workflow (Docker/CI/K8s).
- Great learning curve and widely used in industry for microservices.

### Comparison Table

| Framework | Pros | Cons | Fit for this Lab |
|---|---|---|---|
| **Flask** | Simple, minimal, fast to implement, huge ecosystem | No built-in async, fewer built-ins than Django/FastAPI | Quick & clean |
| FastAPI | Modern, async-ready, auto Swagger/OpenAPI docs | Slightly more setup, concepts (pydantic/models) | Also good |
| Django | Full-featured (ORM, auth, admin, etc.) | Overkill for 2 endpoints | Too heavy |

## 2) Best Practices Applied

### 2.1 Clean Code Organization (PEP 8, structure)

- Imports grouped (stdlib first, third-party next).
- Constants for configuration and service metadata.
- Helper functions: `get_system_info()`, `get_uptime()`, `get_client_ip()`, `iso_utc_now_z()`.

**Example (helpers):**
```python
def get_uptime() -> Dict[str, Any]:
    delta = datetime.now(timezone.utc) - START_TIME_UTC
    seconds = int(delta.total_seconds())
    ...
```

### 2.2 Configuration via Environment Variables

Implemented:
- `HOST` (default `0.0.0.0`)
- `PORT` (default `5000`)
- `DEBUG` (default `False`)

**Example:**
```python
HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", "5000"))
DEBUG = os.getenv("DEBUG", "False").lower() == "true"
```

Why it matters:
- Same artifact runs in different environments (local / CI / Docker / K8s) without code changes.

### 2.3 Error Handling

Added:
- `404` handler returning JSON
- `500` handler returning JSON + logging exception

**Example:**
```python
@app.errorhandler(404)
def not_found(_error):
    return jsonify({"error": "Not Found", ...}), 404
```

Why it matters:
- Predictable API responses
- Easier debugging and monitoring

### 2.4 Logging

- `logging.basicConfig(...)`
- Debug request logging in `@app.before_request`
- Startup logs show config

Why it matters:
- Logs are essential for observability (containers, CI/CD, production troubleshooting).

## 3) API Documentation

### 3.1 `GET /`

Returns:
- `service`: name/version/description/framework
- `system`: hostname/platform/platform_version/architecture/cpu_count/python_version
- `runtime`: uptime_seconds/uptime_human/current_time/timezone
- `request`: client_ip/user_agent/method/path
- `endpoints`: list of available endpoints

**Test command:**
```bash
curl -s http://127.0.0.1:5000/ | python -m json.tool
```

### 3.2 `GET /health`

Returns:
```json
{
  "status": "healthy",
  "timestamp": "....Z",
  "uptime_seconds": 123
}
```

**Test command:**
```bash
curl -s http://127.0.0.1:5000/health | python -m json.tool
```

### 3.3 Configuration Tests

```bash
python app.py
PORT=8080 python app.py
HOST=127.0.0.1 PORT=3000 python app.py
DEBUG=true python app.py
```

## 4) Testing Evidence (Screenshots)

Screenshots are stored in:
`app_python/docs/screenshots/`

Required screenshots:
1. `01-main-endpoint.png` — Browser/terminal showing full JSON from `GET /`
2. `02-health-check.png` — Response from `GET /health`
3. `03-formatted-output.png` — Pretty-printed JSON output (example: `python -m json.tool`)

## 5) Challenges & Solutions

### Challenge 1: Correct client IP behind proxy

**Problem:** `request.remote_addr` may show proxy IP.  
**Solution:** Prefer `X-Forwarded-For` header when available:
```python
forwarded_for = request.headers.get("X-Forwarded-For", "")
```

### Challenge 2: UTC timestamp format with `Z`

**Problem:** `datetime.isoformat()` returns `+00:00`.  
**Solution:** Convert to `Z` suffix:
```python
datetime.now(timezone.utc).isoformat(...).replace("+00:00", "Z")
```

## 6) GitHub Community

Starring repositories is a useful way to bookmark valuable projects and also signals appreciation/support to maintainers, improving a project’s visibility in GitHub search. Following developers (professor/TAs/classmates) helps with networking, discovering useful code patterns, and makes collaboration easier by tracking teammates’ activity and progress.
