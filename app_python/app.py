"""
DevOps Info Service
Main application module (Flask)

Endpoints:
- GET /        : service + system + runtime + request info
- GET /health  : health check (for probes/monitoring)
- GET /metrics : Prometheus metrics endpoint
"""

from __future__ import annotations

import json
import logging
import os
import platform
import socket
import sys
import time
from datetime import datetime, timezone
from typing import Any, Dict

from flask import Flask, Response, g, jsonify, request
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Gauge, Histogram, generate_latest

# -----------------------------------------------------------------------------
# App & Config
# -----------------------------------------------------------------------------

app = Flask(__name__)

HOST: str = os.getenv("HOST", "0.0.0.0")
PORT: int = int(os.getenv("PORT", "5000"))
DEBUG: bool = os.getenv("DEBUG", "False").strip().lower() == "true"

SERVICE_NAME = os.getenv("SERVICE_NAME", "devops-info-service")
SERVICE_VERSION = os.getenv("SERVICE_VERSION", "1.1.0")
SERVICE_DESCRIPTION = os.getenv("SERVICE_DESCRIPTION", "DevOps course info service")
SERVICE_FRAMEWORK = "Flask"
APP_VARIANT = os.getenv("APP_VARIANT", "primary")
APP_MESSAGE = os.getenv("APP_MESSAGE", "running")

START_TIME_UTC = datetime.now(timezone.utc)


# -----------------------------------------------------------------------------
# Prometheus metrics
# -----------------------------------------------------------------------------

HTTP_REQUESTS_TOTAL = Counter(
    "http_requests_total",
    "Total HTTP requests processed by the service.",
    ["method", "endpoint", "status_code"],
)

HTTP_REQUEST_DURATION_SECONDS = Histogram(
    "http_request_duration_seconds",
    "HTTP request duration in seconds.",
    ["method", "endpoint"],
)

HTTP_REQUESTS_IN_PROGRESS = Gauge(
    "http_requests_in_progress",
    "HTTP requests currently being processed.",
)

DEVOPS_INFO_ENDPOINT_CALLS_TOTAL = Counter(
    "devops_info_endpoint_calls_total",
    "Total endpoint calls for the DevOps info service.",
    ["endpoint"],
)

DEVOPS_INFO_SYSTEM_COLLECTION_SECONDS = Histogram(
    "devops_info_system_collection_seconds",
    "Time spent collecting system information.",
)

DEVOPS_INFO_UPTIME_SECONDS = Gauge(
    "devops_info_uptime_seconds",
    "Current service uptime in seconds.",
)


# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------


def iso_utc_now_z() -> str:
    """Return current UTC time in ISO format with 'Z' suffix."""
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


class JSONFormatter(logging.Formatter):
    """Small JSON formatter for container-friendly structured logs."""

    EXTRA_FIELDS = (
        "event",
        "service",
        "version",
        "method",
        "path",
        "status_code",
        "client_ip",
        "duration_ms",
        "user_agent",
    )

    def format(self, record: logging.LogRecord) -> str:
        payload: Dict[str, Any] = {
            "timestamp": iso_utc_now_z(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }

        for field in self.EXTRA_FIELDS:
            value = getattr(record, field, None)
            if value is not None:
                payload[field] = value

        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)

        return json.dumps(payload, ensure_ascii=False)



def configure_logging() -> logging.Logger:
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JSONFormatter())

    root_logger = logging.getLogger()
    root_logger.handlers.clear()
    root_logger.addHandler(handler)
    root_logger.setLevel(logging.DEBUG if DEBUG else logging.INFO)

    for logger_name in ("werkzeug", "gunicorn.error", "gunicorn.access"):
        current_logger = logging.getLogger(logger_name)
        current_logger.handlers.clear()
        current_logger.propagate = True
        current_logger.setLevel(logging.DEBUG if DEBUG else logging.INFO)

    return logging.getLogger(SERVICE_NAME)


logger = configure_logging()


# -----------------------------------------------------------------------------
# Request hooks
# -----------------------------------------------------------------------------


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


def normalize_endpoint() -> str:
    """
    Keep endpoint labels low-cardinality for Prometheus.
    Uses the Flask route template when available and groups unknown paths.
    """
    if request.url_rule and request.url_rule.rule:
        return request.url_rule.rule

    if request.path == "/":
        return "/"

    return "unmatched"


@app.before_request
def log_request_started() -> None:
    g.request_started_at = time.perf_counter()
    g.normalized_endpoint = normalize_endpoint()
    g.skip_http_metrics = request.path == "/metrics"
    g.active_request_metric_registered = False

    if not g.skip_http_metrics:
        HTTP_REQUESTS_IN_PROGRESS.inc()
        g.active_request_metric_registered = True

    logger.debug(
        "request_started",
        extra={
            "event": "request_started",
            "service": SERVICE_NAME,
            "version": SERVICE_VERSION,
            "method": request.method,
            "path": request.path,
            "client_ip": get_client_ip(),
            "user_agent": request.headers.get("User-Agent", "unknown"),
        },
    )


@app.teardown_request
def track_request_finished(_error: Exception | None) -> None:
    if getattr(g, "active_request_metric_registered", False):
        HTTP_REQUESTS_IN_PROGRESS.dec()
        g.active_request_metric_registered = False


@app.after_request
def add_headers(response):
    endpoint = getattr(g, "normalized_endpoint", normalize_endpoint())
    duration_seconds = time.perf_counter() - getattr(g, "request_started_at", time.perf_counter())
    duration_ms = round(duration_seconds * 1000, 2)

    if not getattr(g, "skip_http_metrics", False):
        HTTP_REQUESTS_TOTAL.labels(
            method=request.method,
            endpoint=endpoint,
            status_code=str(response.status_code),
        ).inc()
        HTTP_REQUEST_DURATION_SECONDS.labels(
            method=request.method,
            endpoint=endpoint,
        ).observe(duration_seconds)
        DEVOPS_INFO_ENDPOINT_CALLS_TOTAL.labels(endpoint=endpoint).inc()

    DEVOPS_INFO_UPTIME_SECONDS.set(get_uptime()["seconds"])

    if response.mimetype == "application/json":
        response.headers["Content-Type"] = "application/json; charset=utf-8"

    logger.info(
        "request_completed",
        extra={
            "event": "request_completed",
            "service": SERVICE_NAME,
            "version": SERVICE_VERSION,
            "method": request.method,
            "path": request.path,
            "status_code": response.status_code,
            "client_ip": get_client_ip(),
            "duration_ms": duration_ms,
            "user_agent": request.headers.get("User-Agent", "unknown"),
        },
    )
    return response


# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------


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
    started_at = time.perf_counter()
    try:
        return {
            "hostname": socket.gethostname(),
            "platform": platform.system(),
            "platform_version": platform.platform(),
            "architecture": platform.machine(),
            "cpu_count": os.cpu_count() or 0,
            "python_version": platform.python_version(),
        }
    finally:
        DEVOPS_INFO_SYSTEM_COLLECTION_SECONDS.observe(time.perf_counter() - started_at)



def build_endpoints() -> list[Dict[str, str]]:
    return [
        {"path": "/", "method": "GET", "description": "Service information"},
        {"path": "/health", "method": "GET", "description": "Liveness health check"},
        {"path": "/ready", "method": "GET", "description": "Readiness health check"},
        {"path": "/metrics", "method": "GET", "description": "Prometheus metrics"},
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
            "variant": APP_VARIANT,
            "message": APP_MESSAGE,
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
            "variant": APP_VARIANT,
        }
    ), 200


@app.get("/ready")
def ready():
    """Readiness endpoint used by Kubernetes readiness probes."""
    uptime = get_uptime()
    return jsonify(
        {
            "status": "ready",
            "timestamp": iso_utc_now_z(),
            "uptime_seconds": uptime["seconds"],
            "variant": APP_VARIANT,
            "message": APP_MESSAGE,
        }
    ), 200


@app.get("/metrics")
def metrics() -> Response:
    """Expose Prometheus metrics for scraping."""
    DEVOPS_INFO_UPTIME_SECONDS.set(get_uptime()["seconds"])
    return Response(generate_latest(), content_type=CONTENT_TYPE_LATEST)


# -----------------------------------------------------------------------------
# Error Handlers
# -----------------------------------------------------------------------------

@app.errorhandler(404)
def not_found(_error):
    logger.warning(
        "endpoint_not_found",
        extra={
            "event": "endpoint_not_found",
            "service": SERVICE_NAME,
            "version": SERVICE_VERSION,
            "method": request.method,
            "path": request.path,
            "status_code": 404,
            "client_ip": get_client_ip(),
        },
    )
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
    logger.exception(
        "unhandled_error",
        extra={
            "event": "unhandled_error",
            "service": SERVICE_NAME,
            "version": SERVICE_VERSION,
            "method": request.method,
            "path": request.path,
            "status_code": 500,
            "client_ip": get_client_ip(),
        },
    )
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
    logger.info(
        "service_starting",
        extra={
            "event": "service_starting",
            "service": SERVICE_NAME,
            "version": SERVICE_VERSION,
        },
    )
    logger.info(
        "runtime_configuration host=%s port=%s debug=%s",
        HOST,
        PORT,
        DEBUG,
        extra={
            "event": "runtime_configuration",
            "service": SERVICE_NAME,
            "version": SERVICE_VERSION,
        },
    )
    app.run(host=HOST, port=PORT, debug=DEBUG)


if __name__ == "__main__":
    main()
