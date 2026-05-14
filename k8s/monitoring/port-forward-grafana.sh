#!/usr/bin/env bash
set -euo pipefail

echo "Grafana: http://localhost:3000"
echo "Login: admin"
echo "Password: prom-operator"

kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80 --address 0.0.0.0
