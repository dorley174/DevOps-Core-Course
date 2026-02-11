import app as app_module
from app import app as flask_app


def test_root_ok_structure(client):
    resp = client.get("/", headers={"User-Agent": "pytest"})
    assert resp.status_code == 200
    data = resp.get_json()
    assert isinstance(data, dict)
    for key in ("service", "system", "runtime", "request", "endpoints"):
        assert key in data


def test_health_ok(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    data = resp.get_json()
    assert data["status"] == "healthy"


def test_404_error_shape(client):
    resp = client.get("/does-not-exist")
    assert resp.status_code == 404
    data = resp.get_json()
    assert data["error"] == "Not Found"


def test_500_error_shape(monkeypatch):
    flask_app.config.update(TESTING=False, PROPAGATE_EXCEPTIONS=False)

    def boom():
        raise RuntimeError("boom")

    monkeypatch.setattr(app_module, "get_system_info", boom)

    with flask_app.test_client() as client:
        resp = client.get("/")
        assert resp.status_code == 500
        data = resp.get_json()
        assert data["error"] == "Internal Server Error"
