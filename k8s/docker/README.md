# Lab 16 Docker/kind Runner

This directory contains Docker-only helpers for Lab 16. It uses `kind`, so Kubernetes runs as Docker containers on the local machine. No Vagrant VM and no cloud provider are required.

## Requirements

- Docker Engine / Docker Desktop
- kind
- kubectl
- Helm

## Full run

From the repository root:

```bash
chmod +x k8s/docker/*.sh k8s/monitoring/*.sh
./k8s/docker/run-lab16-docker.sh
```

## Step-by-step

```bash
./k8s/docker/create-kind-cluster.sh
./k8s/docker/deploy-statefulset-app.sh
./k8s/monitoring/install-monitoring.sh
kubectl apply -f k8s/init-containers/
```

## Access UIs

Grafana:

```bash
./k8s/monitoring/port-forward-grafana.sh
```

Open `http://localhost:3000` with `admin / prom-operator`.

Alertmanager:

```bash
./k8s/monitoring/port-forward-alertmanager.sh
```

Open `http://localhost:9093`.

Prometheus:

```bash
./k8s/monitoring/port-forward-prometheus.sh
```

Open `http://localhost:9090`.

## Cleanup

```bash
./k8s/docker/delete-kind-cluster.sh
```
