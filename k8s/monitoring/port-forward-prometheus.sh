#!/usr/bin/env bash
set -euo pipefail

echo "Prometheus: http://localhost:9090"
kubectl port-forward svc/monitoring-kube-prometheus-prometheus -n monitoring 9090:9090 --address 0.0.0.0
