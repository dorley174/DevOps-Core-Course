#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_DIR="$ROOT_DIR/labs/lab18/app_python"
EVIDENCE_DIR="$ROOT_DIR/labs/lab18/evidence"
mkdir -p "$EVIDENCE_DIR"

log() {
  echo "[lab18-task2] $*"
}

cd "$ROOT_DIR"

log "Cleaning old lab18 containers"
docker stop lab2-container nix-container >/dev/null 2>&1 || true
docker rm lab2-container nix-container >/dev/null 2>&1 || true

log "Building traditional Lab 2 Docker image twice"
docker build -t lab2-app:v1 ./app_python | tee "$EVIDENCE_DIR/15-lab2-docker-build-v1.txt"
docker inspect lab2-app:v1 --format '{{.Created}}' | tee "$EVIDENCE_DIR/16-lab2-created-v1.txt"
docker save lab2-app:v1 | sha256sum | tee "$EVIDENCE_DIR/19-lab2-save-hash-v1.txt"

sleep 2

docker build -t lab2-app:v2 ./app_python | tee "$EVIDENCE_DIR/17-lab2-docker-build-v2.txt"
docker inspect lab2-app:v2 --format '{{.Created}}' | tee "$EVIDENCE_DIR/18-lab2-created-v2.txt"
docker save lab2-app:v2 | sha256sum | tee "$EVIDENCE_DIR/20-lab2-save-hash-v2.txt"

log "Building Nix dockerTools image twice"
cd "$APP_DIR"
rm -f result
nix-build docker.nix | tee "$EVIDENCE_DIR/21-nix-docker-build-first.txt"
sha256sum result | tee "$EVIDENCE_DIR/22-nix-docker-hash-first.txt"

docker load < result | tee "$EVIDENCE_DIR/23-nix-docker-load.txt"

rm -f result
nix-build docker.nix | tee "$EVIDENCE_DIR/24-nix-docker-build-second.txt"
sha256sum result | tee "$EVIDENCE_DIR/25-nix-docker-hash-second.txt"

log "Running traditional and Nix containers side-by-side"
docker stop lab2-container nix-container >/dev/null 2>&1 || true
docker rm lab2-container nix-container >/dev/null 2>&1 || true

docker run -d -p 5000:5000 --name lab2-container lab2-app:v1 | tee "$EVIDENCE_DIR/26-lab2-container-id.txt"
docker run -d -p 5001:5000 --name nix-container devops-info-service-nix:1.0.0 | tee "$EVIDENCE_DIR/27-nix-container-id.txt"
sleep 5

{
  echo '--- docker ps ---'
  docker ps --filter name=lab2-container --filter name=nix-container
  echo '--- lab2 container health ---'
  curl -fsS http://localhost:5000/health
  echo
  echo '--- nix container health ---'
  curl -fsS http://localhost:5001/health
  echo
} | tee "$EVIDENCE_DIR/28-container-health-checks.txt"

log "Collecting image size and history comparisons"
docker images | grep -E 'lab2-app|devops-info-service-nix' | tee "$EVIDENCE_DIR/29-image-size-comparison.txt"
docker history lab2-app:v1 | tee "$EVIDENCE_DIR/30-lab2-docker-history.txt"
docker history devops-info-service-nix:1.0.0 | tee "$EVIDENCE_DIR/31-nix-docker-history.txt"

log "Task 2 evidence written to $EVIDENCE_DIR"
