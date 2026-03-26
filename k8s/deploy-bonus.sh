#!/usr/bin/env bash
set -euo pipefail

kubectl apply -f k8s/deployment-app2.yml
kubectl apply -f k8s/service-app2.yml
kubectl apply -f k8s/ingress.yml
kubectl rollout status deployment/devops-info-service-app2 -n devops-lab09
kubectl get ingress,pods,svc -n devops-lab09 -o wide
