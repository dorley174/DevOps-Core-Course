#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

"${SCRIPT_DIR}/create-kind-cluster.sh"
"${SCRIPT_DIR}/deploy-statefulset-app.sh"
"${REPO_ROOT}/k8s/monitoring/install-monitoring.sh"
kubectl apply -f "${REPO_ROOT}/k8s/init-containers/"

cat <<'MSG'

Lab 16 Docker/kind resources have been applied.

Useful checks:
  kubectl get pods -A
  kubectl get po,svc -n monitoring
  kubectl get pods

Grafana:
  ./k8s/monitoring/port-forward-grafana.sh
  http://localhost:3000  admin / prom-operator

Alertmanager:
  ./k8s/monitoring/port-forward-alertmanager.sh
  http://localhost:9093
MSG
