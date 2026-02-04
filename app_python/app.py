"""
DevOps Info Service
Main application module (Flask)

Endpoints:
- GET /        : service + system + runtime + request info
- GET /health  : health check (for probes/monitoring)
"""

from __future__ import annotations

import logging
import os
import platform
import socket
from datetime import datetime, timezone
from typing import Any, Dict, Optional

from flask import Flask, jsonify, request

# -----------------------------------------------------------------------------
# App & Config
# -----------------------------------------------------------------------------

app = Flask(__name__)

HOST: str = os.getenv("HOST", "0.0.0.0")
PORT: int = int(os.getenv("PORT", "5000"))
DEBUG: bool = os.getenv("DEBUG", "False").strip().lower() == "true"

SERVICE_NAME = "devops-info-service"
SERVICE_VERSION = "1.0.0"
SERVICE_DESCRIPTION = "DevOps course info service"
SERVICE_FRAMEWORK = "Flask"

START_TIME_UTC = datetime.now(timezone.utc)

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------

logging.basicConfig(
    level=logging.DEBUG if DEBUG else logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger("devops-info-service")


@app.before_request
def log_request() -> None:
    logger.debug("Request: %s %s", request.method, request.path)


@app.after_request
def add_headers(response):
    # Helpful defaults
    response.headers["Content-Type"] = "application/json; charset=utf-8"
    return response


# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

def iso_utc_now_z() -> str:
    """Return current UTC time in ISO format with 'Z' suffix."""
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def get_client_ip() -> str:
    """
    Best-effort client IP resolution.
    Prefers X-Forwarded-For (common behind reverse proxies).
    """
    forwarded_for = request.headers.get("X-Forwarded-For", "")
    if forwarded_for:
        # "client, proxy1, proxy2"
        return forwarded_for.split(",")[0].strip()
    return request.remote_addr or "unknown"


def get_uptime() -> Dict[str, Any]:
    """Calculate service uptime since START_TIME_UTC."""
    delta = datetime.now(timezone.utc) - START_TIME_UTC
    seconds = int(delta.total_seconds())
    hours = seconds // 3600
    minutes = (seconds % 3600) // 60

    hours_part = f"{hours} hour" + ("" if hours == 1 else "s")
    minutes_part = f"{minutes} minute" + ("" if minutes == 1 else "s")

    return {
        "seconds": seconds,
        "human": f"{hours_part}, {minutes_part}",
    }


def get_system_info() -> Dict[str, Any]:
    """Collect system information using Python standard library."""
    return {
        "hostname": socket.gethostname(),
        "platform": platform.system(),
        # platform.platform() gives a more descriptive string than version/release alone
        "platform_version": platform.platform(),
        "architecture": platform.machine(),
        "cpu_count": os.cpu_count() or 0,
        "python_version": platform.python_version(),
    }


def build_endpoints() -> list[Dict[str, str]]:
    return [
        {"path": "/", "method": "GET", "description": "Service information"},
        {"path": "/health", "method": "GET", "description": "Health check"},
    ]


# -----------------------------------------------------------------------------
# Routes
# -----------------------------------------------------------------------------

@app.get("/")
def index():
    """Main endpoint - service and system information."""
    uptime = get_uptime()

    payload: Dict[str, Any] = {
        "service": {
            "name": SERVICE_NAME,
            "version": SERVICE_VERSION,
            "description": SERVICE_DESCRIPTION,
            "framework": SERVICE_FRAMEWORK,
        },
        "system": get_system_info(),
        "runtime": {
            "uptime_seconds": uptime["seconds"],
            "uptime_human": uptime["human"],
            "current_time": iso_utc_now_z(),
            "timezone": "UTC",
        },
        "request": {
            "client_ip": get_client_ip(),
            "user_agent": request.headers.get("User-Agent", "unknown"),
            "method": request.method,
            "path": request.path,
        },
        "endpoints": build_endpoints(),
    }

    return jsonify(payload), 200


@app.get("/health")
def health():
    """Health check endpoint (for probes/monitoring)."""
    uptime = get_uptime()
    return jsonify(
        {
            "status": "healthy",
            "timestamp": iso_utc_now_z(),
            "uptime_seconds": uptime["seconds"],
        }
    ), 200


# -----------------------------------------------------------------------------
# Error Handlers
# -----------------------------------------------------------------------------

@app.errorhandler(404)
def not_found(_error):
    return (
        jsonify(
            {
                "error": "Not Found",
                "message": "Endpoint does not exist",
                "timestamp": iso_utc_now_z(),
            }
        ),
        404,
    )


@app.errorhandler(500)
def internal_error(_error):
    logger.exception("Unhandled error")
    return (
        jsonify(
            {
                "error": "Internal Server Error",
                "message": "An unexpected error occurred",
                "timestamp": iso_utc_now_z(),
            }
        ),
        500,
    )


# -----------------------------------------------------------------------------
# Entrypoint
# -----------------------------------------------------------------------------

def main() -> None:
    logger.info("Starting %s v%s (%s)", SERVICE_NAME, SERVICE_VERSION, SERVICE_FRAMEWORK)
    logger.info("Config: HOST=%s PORT=%s DEBUG=%s", HOST, PORT, DEBUG)
    # NOTE: Flask built-in server is fine for lab/dev.
    # For production you'd run via a WSGI server (e.g., gunicorn).
    app.run(host=HOST, port=PORT, debug=DEBUG)


if __name__ == "__main__":
    main()
