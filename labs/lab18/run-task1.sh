#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_DIR="$ROOT_DIR/labs/lab18/app_python"
EVIDENCE_DIR="$ROOT_DIR/labs/lab18/evidence"
mkdir -p "$EVIDENCE_DIR"

cd "$APP_DIR"

log() {
  echo "[lab18-task1] $*"
}

log "Recording Nix version"
nix --version | tee "$EVIDENCE_DIR/01-nix-version.txt"

log "Running nixpkgs hello"
nix run nixpkgs#hello | tee "$EVIDENCE_DIR/02-nix-hello.txt"

log "Building Python app with Nix"
rm -f result
nix-build | tee "$EVIDENCE_DIR/03-nix-build-first.txt"
readlink -f result | tee "$EVIDENCE_DIR/04-store-path-first.txt"
nix-hash --type sha256 result | tee "$EVIDENCE_DIR/05-nix-output-hash-first.txt"

log "Building again to show identical store path"
rm -f result
nix-build | tee "$EVIDENCE_DIR/06-nix-build-second.txt"
readlink -f result | tee "$EVIDENCE_DIR/07-store-path-second.txt"
nix-hash --type sha256 result | tee "$EVIDENCE_DIR/08-nix-output-hash-second.txt"

log "Forcing rebuild by deleting output store path"
STORE_PATH="$(readlink -f result)"
echo "$STORE_PATH" | tee "$EVIDENCE_DIR/09-store-path-before-delete.txt"
rm -f result
rm -f result labs/lab18/app_python/result
nix-store --delete "$STORE_PATH" | tee "$EVIDENCE_DIR/10-nix-store-delete.txt" || true
nix-build | tee "$EVIDENCE_DIR/11-nix-build-after-delete.txt"
readlink -f result | tee "$EVIDENCE_DIR/12-store-path-after-delete.txt"
nix-hash --type sha256 result | tee "$EVIDENCE_DIR/13-nix-output-hash-after-delete.txt"

log "Comparing with unpinned pip workflow"
rm -rf venv1 venv2 freeze1.txt freeze2.txt requirements-unpinned.txt
printf 'flask\n' > requirements-unpinned.txt
python3 -m venv venv1
# shellcheck disable=SC1091
source venv1/bin/activate
python -m pip install --upgrade pip >/dev/null
pip install -r requirements-unpinned.txt >/dev/null
pip freeze | grep -i -E '^(Flask|Werkzeug|Jinja2|click|itsdangerous|MarkupSafe|blinker)==' | sort > freeze1.txt
deactivate
pip cache purge >/dev/null 2>&1 || rm -rf ~/.cache/pip
python3 -m venv venv2
# shellcheck disable=SC1091
source venv2/bin/activate
python -m pip install --upgrade pip >/dev/null
pip install -r requirements-unpinned.txt >/dev/null
pip freeze | grep -i -E '^(Flask|Werkzeug|Jinja2|click|itsdangerous|MarkupSafe|blinker)==' | sort > freeze2.txt
deactivate
{
  echo '--- freeze1.txt ---'
  cat freeze1.txt
  echo '--- freeze2.txt ---'
  cat freeze2.txt
  echo '--- diff freeze1 freeze2 ---'
  diff -u freeze1.txt freeze2.txt || true
} | tee "$EVIDENCE_DIR/14-pip-comparison.txt"

log "Task 1 evidence written to $EVIDENCE_DIR"
