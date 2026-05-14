#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALUES_FILE="${SCRIPT_DIR}/values.yaml"
RELEASE_NAME="monitoring"
NAMESPACE="monitoring"
CHART="prometheus-community/kube-prometheus-stack"

if ! command -v helm >/dev/null 2>&1; then
  echo "ERROR: 'helm' is required but was not found in PATH." >&2
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "ERROR: 'kubectl' is required but was not found in PATH." >&2
  exit 1
fi

echo "[1/4] Adding prometheus-community Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts/ >/dev/null 2>&1 || true

echo "[2/4] Updating Helm repositories..."
helm repo update

echo "[3/4] Installing or upgrading kube-prometheus-stack..."
helm upgrade --install "${RELEASE_NAME}" "${CHART}" \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  --values "${VALUES_FILE}" \
  --timeout 20m \
  --wait

echo "[4/4] Current monitoring resources:"
kubectl get po,svc -n "${NAMESPACE}"
