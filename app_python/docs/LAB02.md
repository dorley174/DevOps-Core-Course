# LAB02 — Docker Containerization

This document describes how the Flask app from Lab 1 was containerized using Docker best practices.

---

## 1) Docker Best Practices Applied

### 1.1 Pinned base image version
Using a specific tag makes builds reproducible and avoids unexpected changes when a floating tag updates.

```dockerfile
FROM python:3.13.1-slim
```

### 1.2 Non-root user
Containers should not run as root to reduce the blast radius if the process is compromised.

```dockerfile
RUN addgroup --system app \
    && adduser --system --ingroup app --no-create-home app
USER app
```

### 1.3 Layer caching (install deps before copying source)
Copy `requirements.txt` first and install dependencies. When you change only `app.py`, Docker can reuse the cached dependency layer.

```dockerfile
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py ./
```

### 1.4 Minimal copy & build context (.dockerignore)
`.dockerignore` keeps your build context small and avoids shipping dev artifacts, docs, and VCS metadata.

Examples excluded:
- `.git/`
- `__pycache__/`
- `docs/`, `tests/`

---

## 2) Image Information & Decisions

### 2.1 Base image choice
- **Chosen:** `python:3.13.1-slim`
- **Why:** small Debian-based runtime, good compatibility for Python wheels, smaller than full images.

### 2.2 Image size
Record final size:

```bash
docker images | grep <image>
```

**Result:** 
```bash
CONTAINER ID   IMAGE                                  COMMAND           CREATED          STATUS          PORTS                                     NAMES
9b452f420205   dorley174/devops-info-service:lab02     "python app.py"   28 seconds ago   Up 28 seconds   0.0.0.0:8080->5000/tcp, [::]:8080->5000/tcp   keen_cannon
```

### 2.3 Layer structure
Explain key layers:
1. Base runtime layer (Python slim)
2. User creation (security)
3. Dependencies install (cached)
4. App code copy

### 2.4 Optimizations
- `pip install --no-cache-dir` to avoid keeping pip cache in the image
- `.dockerignore` to reduce build context and speed up builds

---

## 3) Build & Run Process

### 3.1 Build output
```bash
docker build -t devops-info-service:lab02 .
```

**Output:**
```text
[+] Building 141.0s (13/13) FINISHED                                                                        docker:desktop-linux
 => [internal] load build definition from Dockerfile                                                                        0.1s
 => => transferring dockerfile: 860B                                                                                        0.0s
 => resolve image config for docker-image://docker.io/docker/dockerfile:1                                                   4.3s
 => docker-image://docker.io/docker/dockerfile:1@sha256:b6afd42430b15f2d2a4c5a02b919e98a525b785b1aaff16747d2f623364e39b6   48.9s
 => => resolve docker.io/docker/dockerfile:1@sha256:b6afd42430b15f2d2a4c5a02b919e98a525b785b1aaff16747d2f623364e39b6        0.0s
 => => sha256:77246a01651da592b7bae79e0e20ed3b4f2e4c00a1b54b7c921c91ae3fa9ef07 13.57MB / 13.57MB                           48.7s
 => => extracting sha256:77246a01651da592b7bae79e0e20ed3b4f2e4c00a1b54b7c921c91ae3fa9ef07                                   0.1s
 => [internal] load metadata for docker.io/library/python:3.13.1-slim                                                       2.4s
 => [internal] load .dockerignore                                                                                           0.0s
 => => transferring context: 260B                                                                                           0.0s
 => [1/6] FROM docker.io/library/python:3.13.1-slim@sha256:031ebf3cde9f3719d2db385233bcb18df5162038e9cda20e64e08f49f4b47a  73.5s
 => => resolve docker.io/library/python:3.13.1-slim@sha256:031ebf3cde9f3719d2db385233bcb18df5162038e9cda20e64e08f49f4b47a2  0.0s
 => => sha256:e18acc4841d040a12b49e06abbb2c9096bb559fa8d853543ff7ddc2e410531ff 249B / 249B                                  0.5s
 => => sha256:a9910b4c71585ea2d9ca0acc308ab5ed7cc807819405bb23b5de7538142e4f36 12.58MB / 12.58MB                           29.6s
 => => sha256:ad24708d5ee00d90d30e51e59ffce29e5764775c877a74798e85bcc3176cde76 3.51MB / 3.51MB                             15.2s
 => => sha256:c29f5b76f736a8b555fd191c48d6581bb918bcd605a7cbcc76205dd6acff3260 28.21MB / 28.21MB                           69.4s
 => => extracting sha256:c29f5b76f736a8b555fd191c48d6581bb918bcd605a7cbcc76205dd6acff3260                                   0.7s 
 => => extracting sha256:ad24708d5ee00d90d30e51e59ffce29e5764775c877a74798e85bcc3176cde76                                   0.0s 
 => => extracting sha256:a9910b4c71585ea2d9ca0acc308ab5ed7cc807819405bb23b5de7538142e4f36                                   3.2s
 => => extracting sha256:e18acc4841d040a12b49e06abbb2c9096bb559fa8d853543ff7ddc2e410531ff                                   0.0s
 => [internal] load build context                                                                                           0.1s 
 => => transferring context: 6.51kB                                                                                         0.0s 
 => [2/6] WORKDIR /app                                                                                                      0.3s 
 => [3/6] RUN addgroup --system app     && adduser --system --ingroup app --no-create-home app                              0.4s 
 => [4/6] COPY requirements.txt ./                                                                                          0.0s 
 => [5/6] RUN pip install --no-cache-dir -r requirements.txt                                                                9.2s 
 => [6/6] COPY app.py ./                                                                                                    0.0s 
 => exporting to image                                                                                                      0.6s 
 => => exporting layers                                                                                                     0.4s 
 => => exporting manifest sha256:409e654da6806d719714cca291fe908afa3a7a1f78a444630451c3b6aea4fd52                           0.0s 
 => => exporting config sha256:09310faf41ce8b42a107e1ec5a0e880b29a6aa7664b862574ecfa84c92183f4a                             0.0s 
 => => exporting attestation manifest sha256:fccefc3ee604d7bca7e605be0deb0341e96a260a53534af34245a6e2013a34ec               0.0s 

View build details: docker-desktop://dashboard/build/desktop-linux/desktop-linux/vg7v11zlyt4npch7bw4olkcat
```

### 3.2 Run output
```bash
docker run --rm -p 8080:5000 --name devops-info devops-info-service:lab02
```

**Output:**
```text
 * Serving Flask app 'app'
 * Debug mode: off
2026-02-04 19:29:00,312 - devops-info-service - INFO - Starting devops-info-service v1.0.0 (Flask)
2026-02-04 19:29:00,312 - devops-info-service - INFO - Config: HOST=0.0.0.0 PORT=5000 DEBUG=False
2026-02-04 19:29:00,322 - werkzeug - INFO - WARNING: This is a development server. Do not use it in a production deployment. Use a production WSGI server instead.
 * Running on all addresses (0.0.0.0)
 * Running on http://127.0.0.1:5000
 * Running on http://172.17.0.2:5000
2026-02-04 19:29:00,322 - werkzeug - INFO - Press CTRL+C to quit
2026-02-04 19:30:45,863 - werkzeug - INFO - 172.17.0.1 - - [04/Feb/2026 19:30:45] "GET / HTTP/1.1" 200 -
2026-02-04 19:30:59,367 - werkzeug - INFO - 172.17.0.1 - - [04/Feb/2026 19:30:59] "GET /health HTTP/1.1" 200 -
```

### 3.3 Endpoint tests
```bash
curl http://localhost:5000/health
curl http://localhost:5000/
```

**Output:**
```text
https://hub.docker.com/r/dorley174/devops-info-service
```

### 3.4 Docker Hub
- **Repo URL:** `https://hub.docker.com/r/dorley174/devops-info-service`
- **Tags pushed:** `latest, lab02`

---

## 4) Technical Analysis

### Why does this Dockerfile work?
- The app listens on `0.0.0.0` and port `5000` by default, so it is reachable from outside the container when `-p 5000:5000` is used.
- Dependencies are installed before source code to maximize cache hits.

### What happens if you change layer order?
If you copy `app.py` before installing dependencies, any change in source invalidates the cache and forces dependency reinstall, making rebuilds slower.

### Security considerations implemented
- Non-root user with `USER app`
- Minimal base image (`slim`)
- No extra tools installed

### How does `.dockerignore` help?
- Smaller build context → faster builds
- Prevents shipping irrelevant files into the image (security + size)

---

## 5) Challenges & Solutions

Document what happened on your machine. Typical examples:
- **Port not reachable:** fixed by ensuring the app binds to `0.0.0.0` (already default in `app.py`) and using `-p host:container`.
- **Permission issues:** ensured runtime user exists and app files are readable by it.

What you learned:
- How Docker layer caching changes rebuild speed
- Why non-root matters
- How `.dockerignore` affects build context and image size
