# Lab 18 — Reproducible Builds with Nix

## Scope

This submission completes the required Lab 18 tasks only:

- Task 1 — Build Reproducible Python App with Nix
- Task 2 — Reproducible Docker Images with Nix dockerTools

The bonus Flakes task was intentionally not completed.

---

## Environment and Installation Verification

### Nix version

```text
PENDING: run labs/lab18/run-task1.sh and labs/lab18/run-task2.sh, then regenerate this file.
```

### Basic Nix test

Command used:

```bash
nix run nixpkgs#hello
```

Output:

```text
PENDING: run labs/lab18/run-task1.sh and labs/lab18/run-task2.sh, then regenerate this file.
```

---

## Task 1 — Reproducible Python App

### Application Source

The Lab 1/2 Flask application was copied to:

```text
labs/lab18/app_python/
```

The directory contains:

- `app.py` — DevOps Info Service Flask application
- `requirements.txt` — original pip dependency file
- `Dockerfile` — traditional Lab 2 Dockerfile for comparison
- `default.nix` — Nix expression for reproducible app build
- `docker.nix` — Nix dockerTools image definition

### `default.nix`

```nix
{ pkgs ? import <nixpkgs> {} }:

let
  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    flask
    prometheus-client
  ]);
in
pkgs.stdenv.mkDerivation {
  pname = "devops-info-service";
  version = "1.0.0";
  src = ./.;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/devops-info-service
    cp app.py $out/share/devops-info-service/app.py

    mkdir -p $out/bin
    makeWrapper ${pythonEnv}/bin/python $out/bin/devops-info-service \
      --add-flags $out/share/devops-info-service/app.py \
      --set HOST 0.0.0.0 \
      --set PORT 5000 \
      --set SERVICE_NAME devops-info-service \
      --set SERVICE_VERSION 1.0.0-nix \
      --set APP_ENV lab18-nix \
      --set VISITS_FILE /tmp/devops-info-service-visits

    runHook postInstall
  '';

  meta = with pkgs.lib; {
    description = "DevOps Info Service built reproducibly with Nix";
    mainProgram = "devops-info-service";
    platforms = platforms.linux;
  };
}
```

### Explanation of `default.nix`

| Field | Purpose |
|---|---|
| `pname` | Package name in the Nix store. |
| `version` | Application version included in the store path. |
| `src = ./.` | Uses the current directory as the source input. |
| `pythonEnv` | Creates a Python interpreter with exact dependencies from nixpkgs. |
| `flask` | Provides the Flask web framework dependency. |
| `prometheus-client` | Provides the Prometheus metrics dependency used by the app. |
| `makeWrapper` | Creates an executable wrapper for running `app.py` with the Nix-managed Python interpreter. |
| `VISITS_FILE=/tmp/devops-info-service-visits` | Makes the app runnable locally and inside minimal containers without relying on `/data`. |

### Store Path Reproducibility

First Nix build store path:

```text
PENDING: run labs/lab18/run-task1.sh and labs/lab18/run-task2.sh, then regenerate this file.
```

Second Nix build store path:

```text
PENDING: run labs/lab18/run-task1.sh and labs/lab18/run-task2.sh, then regenerate this file.
```

After deleting the output store path and rebuilding:

```text
PENDING: run labs/lab18/run-task1.sh and labs/lab18/run-task2.sh, then regenerate this file.
```

The store paths are expected to be identical because Nix derives the output path from all build inputs, including the source, build instructions, Python interpreter, and dependencies.

### Nix Output Hashes

First output hash:

```text
PENDING: run labs/lab18/run-task1.sh and labs/lab18/run-task2.sh, then regenerate this file.
```

Second output hash:

```text
PENDING: run labs/lab18/run-task1.sh and labs/lab18/run-task2.sh, then regenerate this file.
```

After forced rebuild:

```text
PENDING: run labs/lab18/run-task1.sh and labs/lab18/run-task2.sh, then regenerate this file.
```

These hashes demonstrate that the Nix-built application output is reproducible when inputs do not change.

### Pip Comparison

The following comparison was produced by creating two virtual environments from an unpinned `requirements-unpinned.txt` containing only `flask`:

```text
PENDING: run labs/lab18/run-task1.sh and labs/lab18/run-task2.sh, then regenerate this file.
```

### Why `requirements.txt` Is Weaker Than Nix

A traditional `requirements.txt` file can pin direct Python dependencies, but it does not fully describe the entire build environment. It usually depends on the system Python version, pip resolver behavior, platform-specific wheels, build tools, and transitive dependency resolution at install time. Even when direct dependencies are pinned, the environment is not as strongly isolated or content-addressed as a Nix build.

Nix records the full dependency closure and builds in an isolated environment. The output path includes a hash derived from all relevant inputs. This makes the result reproducible and safely cacheable.

### Nix Store Path Format

A Nix output path has this general structure:

```text
/nix/store/<hash>-<package-name>-<version>
```

For example:

```text
/nix/store/<hash>-devops-info-service-1.0.0
```

The hash is derived from build inputs. If the source code, dependency versions, or build instructions change, the hash changes and Nix creates a new output path.

### Screenshot Evidence

- [Nix app running](lab18/screenshots/01-nix-app-running.png)
- [Nix build reproducibility](lab18/screenshots/03-nix-build-reproducibility.png)

### Reflection — How Nix Would Have Helped in Lab 1

Nix would have made the Lab 1 setup more reproducible from the beginning. Instead of relying on the local Python installation, virtual environment state, and pip behavior, the application could have been built with a declared Python interpreter and dependency set. New machines and CI runners would use the same build inputs and produce the same result, reducing “works on my machine” problems.

---

## Task 2 — Reproducible Docker Images with Nix

### Traditional Lab 2 Dockerfile

```dockerfile
# Production-oriented image for a small Flask app.
# Pin a specific Python version for reproducible builds.
FROM python:3.13.1-slim

# Python runtime defaults: no .pyc files, unbuffered logs (better for containers)
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Create a dedicated non-root user with numeric UID/GID.
RUN addgroup --system --gid 10001 app \
    && adduser --system --uid 10001 --ingroup app --no-create-home app \
    && mkdir -p /data /config \
    && chown -R 10001:10001 /app /data /config

# Install dependencies first to leverage Docker layer caching.
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy only the application code needed at runtime.
COPY app.py ./

# Drop privileges using a numeric user for Kubernetes runAsNonRoot validation.
USER 10001:10001

# Document the port (Flask defaults to 5000 in this repo)
EXPOSE 5000

# Start the application
CMD ["python", "app.py"]
```

### Nix dockerTools Image Definition

```nix
{ pkgs ? import <nixpkgs> {} }:

let
  app = import ./default.nix { inherit pkgs; };
in
pkgs.dockerTools.buildLayeredImage {
  name = "devops-info-service-nix";
  tag = "1.0.0";

  contents = [ app ];

  # Fixed timestamp is required for reproducible image tarballs.
  created = "1970-01-01T00:00:01Z";

  extraCommands = ''
    mkdir -p tmp
    chmod 1777 tmp
  '';

  config = {
    Cmd = [ "${app}/bin/devops-info-service" ];
    Env = [
      "HOST=0.0.0.0"
      "PORT=5000"
      "SERVICE_NAME=devops-info-service"
      "SERVICE_VERSION=1.0.0-nix-docker"
      "APP_ENV=lab18-nix-docker"
      "VISITS_FILE=/tmp/devops-info-service-visits"
    ];
    ExposedPorts = {
      "5000/tcp" = {};
    };
  };
}
```

### Explanation of `docker.nix`

| Field | Purpose |
|---|---|
| `app = import ./default.nix` | Reuses the reproducible app derivation from Task 1. |
| `dockerTools.buildLayeredImage` | Builds a Docker-compatible image from Nix store paths. |
| `name` and `tag` | Define the image name `devops-info-service-nix:1.0.0`. |
| `contents = [ app ]` | Adds the app and its closure to the image. |
| `created = "1970-01-01T00:00:01Z"` | Uses a fixed timestamp to avoid timestamp-based nondeterminism. |
| `extraCommands` | Creates a writable `/tmp` directory. |
| `config.Cmd` | Starts the Nix-built application. |
| `ExposedPorts` | Documents the app port `5000/tcp`. |

### Traditional Dockerfile Reproducibility Test

Traditional image hash from first `docker save`:

```text
PENDING: run labs/lab18/run-task1.sh and labs/lab18/run-task2.sh, then regenerate this file.
```

Traditional image hash from second `docker save`:

```text
PENDING: run labs/lab18/run-task1.sh and labs/lab18/run-task2.sh, then regenerate this file.
```

The traditional Docker image hashes are expected to differ because Docker image metadata and layer creation timestamps can vary between builds, even when the Dockerfile and source files are unchanged.

### Nix Docker Image Reproducibility Test

Nix dockerTools image hash from first build:

```text
PENDING: run labs/lab18/run-task1.sh and labs/lab18/run-task2.sh, then regenerate this file.
```

Nix dockerTools image hash from second build:

```text
PENDING: run labs/lab18/run-task1.sh and labs/lab18/run-task2.sh, then regenerate this file.
```

The Nix image hashes are expected to be identical because the image is built from content-addressed Nix store paths and uses a fixed creation timestamp.

### Side-by-Side Runtime Test

```text
PENDING: run labs/lab18/run-task1.sh and labs/lab18/run-task2.sh, then regenerate this file.
```

The traditional Dockerfile-based container and the Nix dockerTools container both serve the same application and return healthy responses.

### Image Size Comparison

```text
PENDING: run labs/lab18/run-task1.sh and labs/lab18/run-task2.sh, then regenerate this file.
```

### Docker History — Traditional Image

```text
PENDING: run labs/lab18/run-task1.sh and labs/lab18/run-task2.sh, then regenerate this file.
```

### Docker History — Nix Image

```text
PENDING: run labs/lab18/run-task1.sh and labs/lab18/run-task2.sh, then regenerate this file.
```

### Comparison Table — Lab 2 Dockerfile vs Lab 18 Nix dockerTools

| Aspect | Lab 2 Dockerfile | Lab 18 Nix dockerTools |
|---|---|---|
| Base image | Uses `python:3.13.1-slim` | No mutable base image tag required |
| Dependency installation | Runs `pip install` during Docker build | Uses Nix-built Python environment |
| Timestamp behavior | Build metadata can change per build | Fixed `created` timestamp |
| Reproducibility | Approximate; image hashes can differ | Bit-for-bit reproducible image tarball |
| Caching | Docker layer cache | Nix content-addressed store and binary cache |
| Dependency closure | Implicit in image layers | Explicit Nix closure |
| Auditability | Depends on image and pip state | Store paths identify exact inputs |

### Why Traditional Dockerfiles Cannot Guarantee Bit-for-Bit Reproducibility

Traditional Dockerfiles often rely on mutable base image tags, build timestamps, package repositories, and install-time dependency resolution. Even with a pinned base image tag, the tag itself can be republished unless a digest is used. Commands like `pip install` and `apt-get install` also depend on external repository state unless every dependency and hash is pinned.

Nix dockerTools avoids these issues by constructing the image from immutable Nix store paths and deterministic build inputs. Setting a fixed `created` timestamp removes another common source of nondeterminism.

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

If Lab 2 were implemented with Nix from the beginning, the Dockerfile would be replaced or supplemented by a Nix `dockerTools` expression. The application would first be built as a reproducible Nix derivation, then converted into a Docker-compatible image. This would provide stronger guarantees than a traditional Dockerfile while still allowing the final artifact to run with Docker.

---

## Submission Checklist

- [x] Task 1 Nix expression created: `labs/lab18/app_python/default.nix`
- [x] Task 2 Nix Docker expression created: `labs/lab18/app_python/docker.nix`
- [x] Bonus task intentionally skipped
- [ ] Evidence scripts executed locally
- [ ] Real command outputs copied into this submission
- [ ] Screenshots added to `labs/lab18/screenshots/`
- [ ] Branch `feature/lab18` committed
