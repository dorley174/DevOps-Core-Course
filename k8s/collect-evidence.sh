#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="k8s/evidence"
NS="devops-lab09"
APP="devops-info-service"

mkdir -p "$OUT_DIR"

kubectl cluster-info > "$OUT_DIR/01-cluster-info.txt"
kubectl get nodes -o wide > "$OUT_DIR/02-get-nodes.txt"
kubectl get all -n "$NS" -o wide > "$OUT_DIR/03-get-all.txt"
kubectl get pods,svc -n "$NS" -o wide > "$OUT_DIR/04-get-pods-svc.txt"
kubectl describe deployment "$APP" -n "$NS" > "$OUT_DIR/05-describe-deployment.txt"
kubectl rollout history deployment/"$APP" -n "$NS" > "$OUT_DIR/06-rollout-history.txt"
kubectl get ingress -n "$NS" -o wide > "$OUT_DIR/07-get-ingress.txt" 2>/dev/null || true
kubectl get events -n "$NS" --sort-by=.metadata.creationTimestamp > "$OUT_DIR/08-events.txt"

echo "Evidence saved to $OUT_DIR"
