#!/usr/bin/env bash
set -euo pipefail

kubectl get po,svc -n monitoring
helm list -A
kubectl get prometheus,alertmanager -n monitoring
