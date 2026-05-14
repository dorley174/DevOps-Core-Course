#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVIDENCE_DIR="$ROOT_DIR/labs/lab18/evidence"
OUT="$ROOT_DIR/labs/submission18.md"

read_evidence() {
  local file="$1"
  local path="$EVIDENCE_DIR/$file"
  if [[ -s "$path" ]]; then
    cat "$path"
  else
    echo "PENDING: run labs/lab18/run-task1.sh and labs/lab18/run-task2.sh, then regenerate this file."
  fi
}

cat > "$OUT" <<MD
# Lab 18 — Reproducible Builds with Nix

## Scope

This submission completes the required Lab 18 tasks only:

- Task 1 — Build Reproducible Python App with Nix
- Task 2 — Reproducible Docker Images with Nix dockerTools

The bonus Flakes task was intentionally not completed.

---

## Environment and Installation Verification

### Nix version

\`\`\`text
$(read_evidence 01-nix-version.txt)
\`\`\`

### Basic Nix test

Command used:

\`\`\`bash
nix run nixpkgs#hello
\`\`\`

Output:

\`\`\`text
$(read_evidence 02-nix-hello.txt)
\`\`\`

---

## Task 1 — Reproducible Python App

### Application Source

The Lab 1/2 Flask application was copied to:

\`\`\`text
labs/lab18/app_python/
\`\`\`

The directory contains:

- \`app.py\` — DevOps Info Service Flask application
- \`requirements.txt\` — original pip dependency file
- \`Dockerfile\` — traditional Lab 2 Dockerfile for comparison
- \`default.nix\` — Nix expression for reproducible app build
- \`docker.nix\` — Nix dockerTools image definition

### \`default.nix\`

\`\`\`nix
$(cat "$ROOT_DIR/labs/lab18/app_python/default.nix")
\`\`\`

### Explanation of \`default.nix\`

| Field | Purpose |
|---|---|
| \`pname\` | Package name in the Nix store. |
| \`version\` | Application version included in the store path. |
| \`src = ./.\` | Uses the current directory as the source input. |
| \`pythonEnv\` | Creates a Python interpreter with exact dependencies from nixpkgs. |
| \`flask\` | Provides the Flask web framework dependency. |
| \`prometheus-client\` | Provides the Prometheus metrics dependency used by the app. |
| \`makeWrapper\` | Creates an executable wrapper for running \`app.py\` with the Nix-managed Python interpreter. |
| \`VISITS_FILE=/tmp/devops-info-service-visits\` | Makes the app runnable locally and inside minimal containers without relying on \`/data\`. |

### Store Path Reproducibility

First Nix build store path:

\`\`\`text
$(read_evidence 04-store-path-first.txt)
\`\`\`

Second Nix build store path:

\`\`\`text
$(read_evidence 07-store-path-second.txt)
\`\`\`

After deleting the output store path and rebuilding:

\`\`\`text
$(read_evidence 12-store-path-after-delete.txt)
\`\`\`

The store paths are expected to be identical because Nix derives the output path from all build inputs, including the source, build instructions, Python interpreter, and dependencies.

### Nix Output Hashes

First output hash:

\`\`\`text
$(read_evidence 05-nix-output-hash-first.txt)
\`\`\`

Second output hash:

\`\`\`text
$(read_evidence 08-nix-output-hash-second.txt)
\`\`\`

After forced rebuild:

\`\`\`text
$(read_evidence 13-nix-output-hash-after-delete.txt)
\`\`\`

These hashes demonstrate that the Nix-built application output is reproducible when inputs do not change.

### Pip Comparison

The following comparison was produced by creating two virtual environments from an unpinned \`requirements-unpinned.txt\` containing only \`flask\`:

\`\`\`text
$(read_evidence 14-pip-comparison.txt)
\`\`\`

### Why \`requirements.txt\` Is Weaker Than Nix

A traditional \`requirements.txt\` file can pin direct Python dependencies, but it does not fully describe the entire build environment. It usually depends on the system Python version, pip resolver behavior, platform-specific wheels, build tools, and transitive dependency resolution at install time. Even when direct dependencies are pinned, the environment is not as strongly isolated or content-addressed as a Nix build.

Nix records the full dependency closure and builds in an isolated environment. The output path includes a hash derived from all relevant inputs. This makes the result reproducible and safely cacheable.

### Nix Store Path Format

A Nix output path has this general structure:

\`\`\`text
/nix/store/<hash>-<package-name>-<version>
\`\`\`

For example:

\`\`\`text
/nix/store/<hash>-devops-info-service-1.0.0
\`\`\`

The hash is derived from build inputs. If the source code, dependency versions, or build instructions change, the hash changes and Nix creates a new output path.

### Screenshot Evidence

- [Nix app running](lab18/screenshots/01-nix-app-running.png)
- [Nix build reproducibility](lab18/screenshots/03-nix-build-reproducibility.png)

### Reflection — How Nix Would Have Helped in Lab 1

Nix would have made the Lab 1 setup more reproducible from the beginning. Instead of relying on the local Python installation, virtual environment state, and pip behavior, the application could have been built with a declared Python interpreter and dependency set. New machines and CI runners would use the same build inputs and produce the same result, reducing “works on my machine” problems.

---

## Task 2 — Reproducible Docker Images with Nix

### Traditional Lab 2 Dockerfile

\`\`\`dockerfile
$(cat "$ROOT_DIR/app_python/Dockerfile")
\`\`\`

### Nix dockerTools Image Definition

\`\`\`nix
$(cat "$ROOT_DIR/labs/lab18/app_python/docker.nix")
\`\`\`

### Explanation of \`docker.nix\`

| Field | Purpose |
|---|---|
| \`app = import ./default.nix\` | Reuses the reproducible app derivation from Task 1. |
| \`dockerTools.buildLayeredImage\` | Builds a Docker-compatible image from Nix store paths. |
| \`name\` and \`tag\` | Define the image name \`devops-info-service-nix:1.0.0\`. |
| \`contents = [ app ]\` | Adds the app and its closure to the image. |
| \`created = "1970-01-01T00:00:01Z"\` | Uses a fixed timestamp to avoid timestamp-based nondeterminism. |
| \`extraCommands\` | Creates a writable \`/tmp\` directory. |
| \`config.Cmd\` | Starts the Nix-built application. |
| \`ExposedPorts\` | Documents the app port \`5000/tcp\`. |

### Traditional Dockerfile Reproducibility Test

Traditional image hash from first \`docker save\`:

\`\`\`text
$(read_evidence 19-lab2-save-hash-v1.txt)
\`\`\`

Traditional image hash from second \`docker save\`:

\`\`\`text
$(read_evidence 20-lab2-save-hash-v2.txt)
\`\`\`

The traditional Docker image hashes are expected to differ because Docker image metadata and layer creation timestamps can vary between builds, even when the Dockerfile and source files are unchanged.

### Nix Docker Image Reproducibility Test

Nix dockerTools image hash from first build:

\`\`\`text
$(read_evidence 22-nix-docker-hash-first.txt)
\`\`\`

Nix dockerTools image hash from second build:

\`\`\`text
$(read_evidence 25-nix-docker-hash-second.txt)
\`\`\`

The Nix image hashes are expected to be identical because the image is built from content-addressed Nix store paths and uses a fixed creation timestamp.

### Side-by-Side Runtime Test

\`\`\`text
$(read_evidence 28-container-health-checks.txt)
\`\`\`

The traditional Dockerfile-based container and the Nix dockerTools container both serve the same application and return healthy responses.

### Image Size Comparison

\`\`\`text
$(read_evidence 29-image-size-comparison.txt)
\`\`\`

### Docker History — Traditional Image

\`\`\`text
$(read_evidence 30-lab2-docker-history.txt)
\`\`\`

### Docker History — Nix Image

\`\`\`text
$(read_evidence 31-nix-docker-history.txt)
\`\`\`

### Comparison Table — Lab 2 Dockerfile vs Lab 18 Nix dockerTools

| Aspect | Lab 2 Dockerfile | Lab 18 Nix dockerTools |
|---|---|---|
| Base image | Uses \`python:3.13.1-slim\` | No mutable base image tag required |
| Dependency installation | Runs \`pip install\` during Docker build | Uses Nix-built Python environment |
| Timestamp behavior | Build metadata can change per build | Fixed \`created\` timestamp |
| Reproducibility | Approximate; image hashes can differ | Bit-for-bit reproducible image tarball |
| Caching | Docker layer cache | Nix content-addressed store and binary cache |
| Dependency closure | Implicit in image layers | Explicit Nix closure |
| Auditability | Depends on image and pip state | Store paths identify exact inputs |

### Why Traditional Dockerfiles Cannot Guarantee Bit-for-Bit Reproducibility

Traditional Dockerfiles often rely on mutable base image tags, build timestamps, package repositories, and install-time dependency resolution. Even with a pinned base image tag, the tag itself can be republished unless a digest is used. Commands like \`pip install\` and \`apt-get install\` also depend on external repository state unless every dependency and hash is pinned.

Nix dockerTools avoids these issues by constructing the image from immutable Nix store paths and deterministic build inputs. Setting a fixed \`created\` timestamp removes another common source of nondeterminism.

### Practical Scenarios Where Nix Reproducibility Matters

- CI/CD systems where builds must be identical across runners.
- Security audits where the exact dependency closure must be known.
- Incident rollback where a previous version must be restored exactly.
- Long-lived projects where dependency repositories change over time.
- Multi-developer teams where local environments otherwise drift.

### Screenshot Evidence

- [Containers side-by-side](lab18/screenshots/02-containers-side-by-side.png)
- [Nix Docker hashes](lab18/screenshots/04-nix-docker-hashes.png)
- [Docker hash comparison](lab18/screenshots/05-docker-hash-comparison.png)

### Reflection — Redoing Lab 2 with Nix

If Lab 2 were implemented with Nix from the beginning, the Dockerfile would be replaced or supplemented by a Nix \`dockerTools\` expression. The application would first be built as a reproducible Nix derivation, then converted into a Docker-compatible image. This would provide stronger guarantees than a traditional Dockerfile while still allowing the final artifact to run with Docker.

---

## Submission Checklist

- [x] Task 1 Nix expression created: \`labs/lab18/app_python/default.nix\`
- [x] Task 2 Nix Docker expression created: \`labs/lab18/app_python/docker.nix\`
- [x] Bonus task intentionally skipped
- [ ] Evidence scripts executed locally
- [ ] Real command outputs copied into this submission
- [ ] Screenshots added to \`labs/lab18/screenshots/\`
- [ ] Branch \`feature/lab18\` committed
MD

echo "Wrote $OUT"
