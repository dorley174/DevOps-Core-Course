#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="lab16-monitoring"

if ! command -v kind >/dev/null 2>&1; then
  echo "ERROR: 'kind' is required but was not found in PATH." >&2
  exit 1
fi

kind delete cluster --name "${CLUSTER_NAME}"
