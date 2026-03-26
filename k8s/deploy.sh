#!/usr/bin/env bash
set -euo pipefail

kubectl apply -f k8s/namespace.yml
kubectl apply -f k8s/deployment.yml
kubectl apply -f k8s/service.yml
kubectl rollout status deployment/devops-info-service -n devops-lab09
kubectl get pods,svc -n devops-lab09 -o wide
