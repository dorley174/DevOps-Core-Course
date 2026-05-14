#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CHART_DIR="${REPO_ROOT}/k8s/devops-info-service"
RELEASE_NAME="devops-info-service"
NAMESPACE="default"

if ! command -v helm >/dev/null 2>&1; then
  echo "ERROR: 'helm' is required but was not found in PATH." >&2
  exit 1
fi

helm upgrade --install "${RELEASE_NAME}" "${CHART_DIR}" \
  --namespace "${NAMESPACE}" \
  --set statefulset.enabled=true \
  --set rollout.enabled=false \
  --set replicaCount=3 \
  --set service.type=NodePort \
  --set service.nodePort=30083 \
  --wait \
  --timeout 10m

kubectl get statefulset,pods,svc,pvc -n "${NAMESPACE}"
