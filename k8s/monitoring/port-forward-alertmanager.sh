#!/usr/bin/env bash
set -euo pipefail

echo "Alertmanager: http://localhost:9093"
kubectl port-forward svc/monitoring-kube-prometheus-alertmanager -n monitoring 9093:9093 --address 0.0.0.0
