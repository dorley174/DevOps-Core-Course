#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CLUSTER_NAME="lab16-monitoring"
CONFIG_FILE="${SCRIPT_DIR}/kind-config.yaml"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: '$1' is required but was not found in PATH." >&2
    exit 1
  fi
}

require_cmd docker
require_cmd kind
require_cmd kubectl

if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker is not running or the current user cannot access Docker." >&2
  exit 1
fi

if kind get clusters | grep -qx "${CLUSTER_NAME}"; then
  echo "kind cluster '${CLUSTER_NAME}' already exists. Using existing cluster."
else
  echo "Creating kind cluster '${CLUSTER_NAME}' from ${CONFIG_FILE}..."
  kind create cluster --name "${CLUSTER_NAME}" --config "${CONFIG_FILE}"
fi

kubectl config use-context "kind-${CLUSTER_NAME}"
kubectl cluster-info
kubectl get nodes -o wide

cat <<MSG

Docker-only Kubernetes cluster is ready.
Repository root: ${REPO_ROOT}
Context: kind-${CLUSTER_NAME}
MSG
