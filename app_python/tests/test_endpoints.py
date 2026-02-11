import pytest

import app_python.app as app_module
from app_python.app import app as flask_app


def test_root_ok_structure(client):
    resp = client.get("/", headers={"User-Agent": "pytest"})
    assert resp.status_code == 200

    data = resp.get_json()
    assert isinstance(data, dict)

    # Top-level keys
    for key in ("service", "system", "runtime", "request", "endpoints"):
        assert key in data

    # Service block
    service = data["service"]
    assert service["name"] == "devops-info-service"
    assert "version" in service
    assert "framework" in service

    # Runtime block
    runtime = data["runtime"]
    assert runtime["timezone"] == "UTC"
    assert isinstance(runtime["uptime_seconds"], int)
    assert runtime["uptime_seconds"] >= 0
    assert isinstance(runtime["current_time"], str)

    # Request block
    req = data["request"]
    assert req["method"] == "GET"
    assert req["path"] == "/"
    assert isinstance(req["client_ip"], str)
    assert isinstance(req["user_agent"], str)

    # Endpoints list contains expected items
    endpoints = data["endpoints"]
    assert any(e["path"] == "/" and e["method"] == "GET" for e in endpoints)
    assert any(e["path"] == "/health" and e["method"] == "GET" for e in endpoints)


def test_health_ok(client):
    resp = client.get("/health")
    assert resp.status_code == 200

    data = resp.get_json()
    assert data["status"] == "healthy"
    assert isinstance(data["timestamp"], str)
    assert isinstance(data["uptime_seconds"], int)
    assert data["uptime_seconds"] >= 0


def test_404_error_shape(client):
    resp = client.get("/does-not-exist")
    assert resp.status_code == 404

    data = resp.get_json()
    assert data["error"] == "Not Found"
    assert "Endpoint does not exist" in data["message"]
    assert isinstance(data["timestamp"], str)


def test_500_error_shape(monkeypatch):
    # In TESTING mode Flask often propagates exceptions instead of using error handlers,
    # so we explicitly disable propagation to assert JSON error handler behavior.
    flask_app.config.update(TESTING=False, PROPAGATE_EXCEPTIONS=False)

    def boom():
        raise RuntimeError("boom")

    monkeypatch.setattr(app_module, "get_system_info", boom)

    with flask_app.test_client() as client:
        resp = client.get("/")
        assert resp.status_code == 500
        data = resp.get_json()
        assert data["error"] == "Internal Server Error"
        assert "unexpected error" in data["message"].lower()
        assert isinstance(data["timestamp"], str)
