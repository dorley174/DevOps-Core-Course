This directory contains lightweight validation artifacts captured from the sandbox for the instrumented Flask application itself.

Included files:
- `app-root.json` — sample response from `GET /`
- `app-health.json` — sample response from `GET /health`
- `app-metrics-sample.txt` — sample Prometheus metrics output from `GET /metrics`
- `app-metrics-headers.txt` — response headers for `/metrics` confirming the Prometheus content type

These files validate the application-side instrumentation.

Full multi-container validation for Prometheus, Grafana, and Loki must still be executed locally because the sandbox does not provide a Docker daemon.
