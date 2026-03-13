import json
import logging

from app import JSONFormatter


def test_json_formatter_renders_expected_fields():
    formatter = JSONFormatter()
    record = logging.LogRecord(
        name="devops-info-service",
        level=logging.INFO,
        pathname=__file__,
        lineno=10,
        msg="request_completed",
        args=(),
        exc_info=None,
    )
    record.event = "request_completed"
    record.service = "devops-info-service"
    record.version = "1.1.0"
    record.method = "GET"
    record.path = "/health"
    record.status_code = 200
    record.client_ip = "127.0.0.1"
    record.duration_ms = 3.14

    payload = json.loads(formatter.format(record))

    assert payload["message"] == "request_completed"
    assert payload["level"] == "INFO"
    assert payload["event"] == "request_completed"
    assert payload["service"] == "devops-info-service"
    assert payload["method"] == "GET"
    assert payload["path"] == "/health"
    assert payload["status_code"] == 200
