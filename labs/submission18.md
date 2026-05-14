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
nix (Determinate Nix 3.20.0) 2.34.6
```

### Basic Nix test

Command used:

```bash
nix run nixpkgs#hello
```

Output:

```text
Hello, world!
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
/nix/store/d0d1zw0my13vdjj06m2d3zhzzgm90060-devops-info-service-1.0.0
```

Second Nix build store path:

```text
/nix/store/d0d1zw0my13vdjj06m2d3zhzzgm90060-devops-info-service-1.0.0
```

After deleting the output store path and rebuilding:

```text
/nix/store/d0d1zw0my13vdjj06m2d3zhzzgm90060-devops-info-service-1.0.0
```

The store paths are expected to be identical because Nix derives the output path from all build inputs, including the source, build instructions, Python interpreter, and dependencies.

### Nix Output Hashes

First output hash:

```text
dd2bd2abba01a00297ed14ad60f29a24b67ce457b1211cdb52dc3b5c2eb0a0fd
```

Second output hash:

```text
dd2bd2abba01a00297ed14ad60f29a24b67ce457b1211cdb52dc3b5c2eb0a0fd
```

After forced rebuild:

```text
dd2bd2abba01a00297ed14ad60f29a24b67ce457b1211cdb52dc3b5c2eb0a0fd
```

These hashes demonstrate that the Nix-built application output is reproducible when inputs do not change.

### Pip Comparison

The following comparison was produced by creating two virtual environments from an unpinned `requirements-unpinned.txt` containing only `flask`:

```text
--- freeze1.txt ---
Flask==3.1.3
Jinja2==3.1.6
MarkupSafe==3.0.3
Werkzeug==3.1.8
blinker==1.9.0
click==8.3.3
itsdangerous==2.2.0
--- freeze2.txt ---
Flask==3.1.3
Jinja2==3.1.6
MarkupSafe==3.0.3
Werkzeug==3.1.8
blinker==1.9.0
click==8.3.3
itsdangerous==2.2.0
--- diff freeze1 freeze2 ---
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
5d0bd401bee017ef30287e8411a576af3bc1a5f0545cadae4f6f705916977ae6  -
```

Traditional image hash from second `docker save`:

```text
81572d01b29834d3ae5db13a7b98c4f545b9ae0a4f7930d49b1372cd34485797  -
```

The traditional Docker image hashes are expected to differ because Docker image metadata and layer creation timestamps can vary between builds, even when the Dockerfile and source files are unchanged.

### Nix Docker Image Reproducibility Test

Nix dockerTools image hash from first build:

```text
aa3638c60f34d8cfda3136c3e29a797f4edd5ee4b215b9603cfc3e1a62450eb5  result
```

Nix dockerTools image hash from second build:

```text
aa3638c60f34d8cfda3136c3e29a797f4edd5ee4b215b9603cfc3e1a62450eb5  result
```

The Nix image hashes are expected to be identical because the image is built from content-addressed Nix store paths and uses a fixed creation timestamp.

### Side-by-Side Runtime Test

```text
--- docker ps ---
CONTAINER ID   IMAGE                           COMMAND                  CREATED          STATUS         PORTS                                         NAMES
9a7ceb173dd2   devops-info-service-nix:1.0.0   "/nix/store/06c4hlva…"   9 seconds ago    Up 8 seconds   0.0.0.0:5001->5000/tcp, [::]:5001->5000/tcp   nix-container
892f8c447961   lab2-app:v1                     "python app.py"          10 seconds ago   Up 9 seconds   0.0.0.0:5000->5000/tcp, [::]:5000->5000/tcp   lab2-container
--- lab2 container health ---
{"status":"healthy","timestamp":"2026-05-14T20:17:35.129Z","uptime_seconds":8,"variant":"primary"}

--- nix container health ---
{"status":"healthy","timestamp":"2026-05-14T20:17:35.144Z","uptime_seconds":8,"variant":"primary"}
```

The traditional Dockerfile-based container and the Nix dockerTools container both serve the same application and return healthy responses.

### Image Size Comparison

```text
lab2-app                        v2             3d1599933b32   4 weeks ago     189MB
lab2-app                        v1             8fc4113f4485   4 weeks ago     189MB
devops-info-service-nix         1.0.0          d5f5ad80fafd   56 years ago    396MB
```

### Docker History — Traditional Image

```text
IMAGE          CREATED         CREATED BY                                      SIZE      COMMENT
8fc4113f4485   4 weeks ago     CMD ["python" "app.py"]                         0B        buildkit.dockerfile.v0
<missing>      4 weeks ago     EXPOSE &{[{{28 0} {28 0}}] 0xc001a908c0}        0B        buildkit.dockerfile.v0
<missing>      4 weeks ago     USER 10001:10001                                0B        buildkit.dockerfile.v0
<missing>      4 weeks ago     COPY app.py ./ # buildkit                       28.7kB    buildkit.dockerfile.v0
<missing>      4 weeks ago     RUN /bin/sh -c pip install --no-cache-dir -r…   6.16MB    buildkit.dockerfile.v0
<missing>      4 weeks ago     COPY requirements.txt ./ # buildkit             12.3kB    buildkit.dockerfile.v0
<missing>      4 weeks ago     RUN /bin/sh -c addgroup --system --gid 10001…   57.3kB    buildkit.dockerfile.v0
<missing>      3 months ago    WORKDIR /app                                    8.19kB    buildkit.dockerfile.v0
<missing>      3 months ago    ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFER…   0B        buildkit.dockerfile.v0
<missing>      16 months ago   CMD ["python3"]                                 0B        buildkit.dockerfile.v0
<missing>      16 months ago   RUN /bin/sh -c set -eux;  for src in idle3 p…   16.4kB    buildkit.dockerfile.v0
<missing>      16 months ago   RUN /bin/sh -c set -eux;   savedAptMark="$(a…   41.3MB    buildkit.dockerfile.v0
<missing>      16 months ago   ENV PYTHON_SHA256=9cf9427bee9e2242e3877dd0f6…   0B        buildkit.dockerfile.v0
<missing>      16 months ago   ENV PYTHON_VERSION=3.13.1                       0B        buildkit.dockerfile.v0
<missing>      16 months ago   ENV GPG_KEY=7169605F62C751356D054A26A821E680…   0B        buildkit.dockerfile.v0
<missing>      16 months ago   RUN /bin/sh -c set -eux;  apt-get update;  a…   10.4MB    buildkit.dockerfile.v0
<missing>      16 months ago   ENV PATH=/usr/local/bin:/usr/local/sbin:/usr…   0B        buildkit.dockerfile.v0
<missing>      16 months ago   # debian.sh --arch 'amd64' out/ 'bookworm' '…   85.2MB    debuerreotype 0.15
```

### Docker History — Nix Image

```text
IMAGE          CREATED   CREATED BY   SIZE      COMMENT
d5f5ad80fafd   N/A                    28.7kB    store paths: ['/nix/store/cf8dk5gzsxx6r9xkx1ckvbqz67w1z0gz-devops-info-service-nix-customisation-layer']
<missing>      N/A                    53.2kB    store paths: ['/nix/store/06c4hlvac4h4l4jl4zsn3cgywbsqpna6-devops-info-service-1.0.0']
<missing>      N/A                    1.22MB    store paths: ['/nix/store/wij96d7izljw38kksg0q384ygi8hfvkk-python3-3.12.8-env']
<missing>      N/A                    856kB     store paths: ['/nix/store/a4v5qavdkzip0bnwhmnq2a7m62hpnnpc-python3.12-prometheus-client-0.21.0']
<missing>      N/A                    1.33MB    store paths: ['/nix/store/ijc606v1g5vhqxrjk4qmj787kymp6sal-python3.12-flask-3.0.3']
<missing>      N/A                    2.99MB    store paths: ['/nix/store/jcf93x7sly7l76hyaqwramfyydnbvsf4-python3.12-werkzeug-3.0.6']
<missing>      N/A                    2.06MB    store paths: ['/nix/store/jvrzvrbnxdk6wp1qy9k1iyjhgbzw3jv2-python3.12-jinja2-3.1.5']
<missing>      N/A                    246kB     store paths: ['/nix/store/0vrargkskpn2m47ka7cfkc1bgq35achi-python3.12-itsdangerous-2.2.0']
<missing>      N/A                    1.39MB    store paths: ['/nix/store/k1qzmvyvarz0pgjaz06wx0y5vsgwbhbw-python3.12-click-8.1.7']
<missing>      N/A                    172kB     store paths: ['/nix/store/hb6zkd7hqgqsjsc2dswifgcx8ycc43ag-python3.12-blinker-1.8.2']
<missing>      N/A                    176kB     store paths: ['/nix/store/s03icbxsi62xvd9bigwbgqlgbr5zhkdp-python3.12-markupsafe-3.0.2']
<missing>      N/A                    121MB     store paths: ['/nix/store/dksjvr69ckglyw1k2ss1qgshhcix73p8-python3-3.12.8']
<missing>      N/A                    1.1MB     store paths: ['/nix/store/izpczxh0wcm3ra6z0073zf9j0mv2wfl4-xz-5.6.3']
<missing>      N/A                    5.33MB    store paths: ['/nix/store/v87awkhzf3nr7nc5i4gg77xzqv4bqjy3-tzdata-2025b']
<missing>      N/A                    1.61MB    store paths: ['/nix/store/v9smapvfv1z340qs3p7xbw6zb6zplfcf-sqlite-3.46.1']
<missing>      N/A                    504kB     store paths: ['/nix/store/vb3dx18nky7cq63br7x2mi86isli529w-readline-8.2p13']
<missing>      N/A                    8.06MB    store paths: ['/nix/store/qzn96phpnb6c56mlqa1424hfgf5hp67s-openssl-3.3.3']
<missing>      N/A                    266kB     store paths: ['/nix/store/c25k325zh2b9g8s68b7ixbjfh3a916cb-mpdecimal-4.0.0']
<missing>      N/A                    164kB     store paths: ['/nix/store/n4gd4rqkr0p2rkdhklvbx1rnx78m6dkj-mailcap-2.1.54']
<missing>      N/A                    172kB     store paths: ['/nix/store/iissy6zslzyb85rzjgq4waag9dixvv6s-libxcrypt-4.4.36']
<missing>      N/A                    98.3kB    store paths: ['/nix/store/fm7yigp87wq0p58x92iynwscdmspzkrb-libffi-3.4.6']
<missing>      N/A                    643kB     store paths: ['/nix/store/jn8gi3mbjm6b2khxcbm3vf2c1h5wpv17-gdbm-1.24-lib']
<missing>      N/A                    328kB     store paths: ['/nix/store/h08i7wrlqmd48lnaimaz28pny9i8vmr8-expat-2.7.1']
<missing>      N/A                    106kB     store paths: ['/nix/store/vrqss3954zk1c52mda3xf1rv7wc5ygba-bzip2-1.0.8']
<missing>      N/A                    9.21MB    store paths: ['/nix/store/hh698a2nnpqr47lh52n26wi8fiah3hid-gcc-13.3.0-lib']
<missing>      N/A                    1.73MB    store paths: ['/nix/store/mjhcjikhxps97mq5z54j4gjjfzgmsir5-bash-5.2p37']
<missing>      N/A                    184kB     store paths: ['/nix/store/mkhhjfg2isjbfx87dz191bzpnwx1bbr9-gcc-13.3.0-libgcc']
<missing>      N/A                    164kB     store paths: ['/nix/store/b6mjyiadysqlh7nps52faznnqmp32604-zlib-1.3.1']
<missing>      N/A                    8.7MB     store paths: ['/nix/store/cn67k729khgnd9i1j7gbyh6lpzz11ci5-ncurses-6.4.20221231']
<missing>      N/A                    31.7MB    store paths: ['/nix/store/5m9amsvvh2z8sl7jrnc87hzy21glw6k1-glibc-2.40-66']
<missing>      N/A                    184kB     store paths: ['/nix/store/y4d9iir0yqmrcswaqfi368d8m1rkv14s-xgcc-13.3.0-libgcc']
<missing>      N/A                    639kB     store paths: ['/nix/store/c47b963idja6h1d8n91pf28v2jcq96kp-libidn2-2.3.7']
<missing>      N/A                    1.88MB    store paths: ['/nix/store/2745pvn6cv32yn9gp2rlqiqhqgs01pb5-libunistring-1.2']
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
- [x] Evidence scripts executed locally
- [x] Real command outputs copied into this submission
- [x] Screenshots added to `labs/lab18/screenshots/`
- [x] Branch `feature/lab18` committed
