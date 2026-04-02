# Lab 10 — Helm Package Manager

This report documents the Helm implementation for the Kubernetes manifests created in Lab 09.

---

## 1. Helm Fundamentals & Setup

### 1.1 What Helm gives us
Helm is the package manager for Kubernetes. In this lab, Helm improves the Lab 09 manifests in four major ways:

1. **Templating** — the same manifests can be reused in multiple environments.
2. **Values-driven configuration** — image, replicas, ports, resources, and probes are configurable without editing YAML templates.
3. **Release management** — Helm tracks installs, upgrades, rollbacks, and uninstall operations.
4. **Lifecycle hooks** — pre-install and post-install jobs can validate configuration and run smoke checks.

### 1.2 Helm installation in WSL
Recommended installation method for WSL/Linux:

```bash
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
chmod 700 get_helm.sh
./get_helm.sh
helm version
```

**Evidence — Helm version:**

```text
version.BuildInfo{Version:"v4.1.3", GitCommit:"c94d381b03be117e7e57908edbf642104e00eb8f", GitTreeState:"clean", GoVersion:"go1.25.8", KubeClientVersion:"v1.35"}
```

### 1.3 Public chart repositories explored
Commands used:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm search repo prometheus
helm show chart prometheus-community/prometheus
```

**Evidence — repository search:**

```text
NAME                                                    CHART VERSION   APP VERSION     DESCRIPTION
prometheus-community/kube-prometheus-stack              82.16.1         v0.89.0         kube-prometheus-stack collects Kubernetes manif...
prometheus-community/prometheus                         28.15.0         v3.11.0         Prometheus is a monitoring system and time seri...
prometheus-community/prometheus-adapter                 5.3.0           v0.12.0         A Helm chart for k8s prometheus adapter
prometheus-community/prometheus-blackbox-exporter       11.9.1          v0.28.0         Prometheus Blackbox Exporter
prometheus-community/prometheus-cloudwatch-expo...      0.28.1          0.16.0          A Helm chart for prometheus cloudwatch-exporter
prometheus-community/prometheus-conntrack-stats...      0.5.35          v0.4.42         A Helm chart for conntrack-stats-exporter
prometheus-community/prometheus-consul-exporter         1.1.1           v0.13.0         A Helm chart for the Prometheus Consul Exporter
prometheus-community/prometheus-couchdb-exporter        1.0.1           1.0             A Helm chart to export the metrics from couchdb...
prometheus-community/prometheus-druid-exporter          1.2.0           v0.11.0         Druid exporter to monitor druid metrics with Pr...
prometheus-community/prometheus-elasticsearch-e...      7.2.1           v1.10.0         Elasticsearch stats exporter for Prometheus
prometheus-community/prometheus-fastly-exporter         0.11.0          v10.2.0         A Helm chart for the Prometheus Fastly Exporter
prometheus-community/prometheus-ipmi-exporter           0.8.0           v1.10.1         This is an IPMI exporter for Prometheus.
prometheus-community/prometheus-json-exporter           0.19.2          v0.7.0          Install prometheus-json-exporter
prometheus-community/prometheus-kafka-exporter          3.0.1           v1.9.0          A Helm chart to export metrics from Kafka in Pr...
prometheus-community/prometheus-memcached-exporter      0.4.5           v0.15.5         Prometheus exporter for Memcached metrics
prometheus-community/prometheus-modbus-exporter         0.1.4           0.4.1           A Helm chart for prometheus-modbus-exporter
prometheus-community/prometheus-mongodb-exporter        3.18.0          0.49.0          A Prometheus exporter for MongoDB metrics
prometheus-community/prometheus-mysql-exporter          2.13.0          v0.19.0         A Helm chart for prometheus mysql exporter with...
prometheus-community/prometheus-nats-exporter           2.22.1          0.19.2          A Helm chart for prometheus-nats-exporter
prometheus-community/prometheus-nginx-exporter          1.20.8          1.5.1           A Helm chart for NGINX Prometheus Exporter
prometheus-community/prometheus-node-exporter           4.52.2          1.10.2          A Helm chart for prometheus node-exporter
prometheus-community/prometheus-opencost-exporter       0.1.2           1.108.0         Prometheus OpenCost Exporter
prometheus-community/prometheus-operator                9.3.2           0.38.1          DEPRECATED - This chart will be renamed. See ht...
prometheus-community/prometheus-operator-admiss...      0.38.0          0.90.1          Prometheus Operator Admission Webhook
prometheus-community/prometheus-operator-crds           28.0.1          v0.90.1         A Helm chart that collects custom resource defi...
prometheus-community/prometheus-pgbouncer-exporter      0.10.0          v0.12.0         A Helm chart for prometheus pgbouncer-exporter
prometheus-community/prometheus-pingdom-exporter        3.4.2           v0.5.6          A Helm chart for Prometheus Pingdom Exporter
prometheus-community/prometheus-pingmesh-exporter       0.4.3           v1.2.2          Prometheus Pingmesh Exporter
prometheus-community/prometheus-postgres-exporter       7.5.2           v0.19.1         A Helm chart for prometheus postgres-exporter
prometheus-community/prometheus-pushgateway             3.6.0           v1.11.2         A Helm chart for prometheus pushgateway
prometheus-community/prometheus-rabbitmq-exporter       2.1.2           1.0.0           Rabbitmq metrics exporter for prometheus
prometheus-community/prometheus-redis-exporter          6.22.0          v1.82.0         Prometheus exporter for Redis metrics
prometheus-community/prometheus-smartctl-exporter       0.16.0          v0.14.0         A Helm chart for Kubernetes
prometheus-community/prometheus-snmp-exporter           9.13.1          v0.30.1         Prometheus SNMP Exporter
prometheus-community/prometheus-sql-exporter            0.5.0           v0.8            Prometheus SQL Exporter
prometheus-community/prometheus-stackdriver-exp...      4.12.2          v0.18.0         Stackdriver exporter for Prometheus
prometheus-community/prometheus-statsd-exporter         1.0.0           v0.28.0         A Helm chart for prometheus stats-exporter
prometheus-community/prometheus-systemd-exporter        0.5.2           0.7.0           A Helm chart for prometheus systemd-exporter
prometheus-community/prometheus-to-sd                   0.5.1           v0.9.2          Scrape metrics stored in prometheus format and ...
prometheus-community/prometheus-windows-exporter        0.12.6          0.31.6          A Helm chart for prometheus windows-exporter
prometheus-community/prometheus-yet-another-clo...      0.43.0          v0.64.0         Yace - Yet Another CloudWatch Exporter
prometheus-community/alertmanager                       1.34.0          v0.31.1         The Alertmanager handles alerts sent by client ...
prometheus-community/alertmanager-snmp-notifier         2.1.0           v2.1.0          The SNMP Notifier handles alerts coming from Pr...
prometheus-community/jiralert                           1.8.2           v1.3.0          A Helm chart for Kubernetes to install jiralert
prometheus-community/kube-state-metrics                 7.2.2           2.18.0          Install kube-state-metrics to generate and expo...
prometheus-community/prom-label-proxy                   0.18.0          v0.12.1         A proxy that enforces a given label in a given ...
prometheus-community/yet-another-cloudwatch-exp...      0.39.1          v0.62.1         Yace - Yet Another CloudWatch Exporter
grafana/cloudcost-exporter                              1.1.2           0.25.0          Cloud Cost Exporter exports cloud provider agno...
grafana/loki                                            2.16.0          v2.6.1          Loki: like Prometheus, but for logs.
grafana/loki-stack                                      2.10.3          v2.9.3          Loki: like Prometheus, but for logs.
grafana/snyk-exporter                                   0.1.0           v1.4.1          Prometheus exporter for Snyk.
```

**Evidence — public chart inspection:**

```text
annotations:
  artifacthub.io/license: Apache-2.0
  artifacthub.io/links: |
    - name: Chart Source
      url: https://github.com/prometheus-community/helm-charts
    - name: Upstream Project
      url: https://github.com/prometheus/prometheus
apiVersion: v2
appVersion: v3.11.0
dependencies:
- condition: alertmanager.enabled
  name: alertmanager
  repository: https://prometheus-community.github.io/helm-charts
  version: 1.34.*
- condition: kube-state-metrics.enabled
  name: kube-state-metrics
  repository: https://prometheus-community.github.io/helm-charts
  version: 7.2.*
- condition: prometheus-node-exporter.enabled
  name: prometheus-node-exporter
  repository: https://prometheus-community.github.io/helm-charts
  version: 4.52.*
- condition: prometheus-pushgateway.enabled
  name: prometheus-pushgateway
  repository: https://prometheus-community.github.io/helm-charts
  version: 3.6.*
description: Prometheus is a monitoring system and time series database.
home: https://prometheus.io/
icon: https://raw.githubusercontent.com/prometheus/prometheus.github.io/master/assets/prometheus_logo-cb55bb5c346.png
keywords:
- monitoring
- prometheus
kubeVersion: '>=1.19.0-0'
maintainers:
- email: gianrubio@gmail.com
  name: gianrubio
  url: https://github.com/gianrubio
- email: zanhsieh@gmail.com
  name: zanhsieh
  url: https://github.com/zanhsieh
- email: miroslav.hadzhiev@gmail.com
  name: Xtigyro
  url: https://github.com/Xtigyro
- email: naseem@transit.app
  name: naseemkullah
  url: https://github.com/naseemkullah
- email: rootsandtrees@posteo.de
  name: zeritti
  url: https://github.com/zeritti
name: prometheus
sources:
- https://github.com/prometheus/alertmanager
- https://github.com/prometheus/prometheus
- https://github.com/prometheus/pushgateway
- https://github.com/prometheus/node_exporter
- https://github.com/kubernetes/kube-state-metrics
type: application
version: 28.15.0
```

---

## 2. Chart Overview

### 2.1 Implemented chart structure
I created the following Helm structure inside `k8s/`:

```text
k8s/
├── HELM.md
├── common-lib/
│   ├── Chart.yaml
│   └── templates/
│       └── _helpers.tpl
├── devops-info-service/
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── values-dev.yaml
│   ├── values-prod.yaml
│   ├── charts/
│   │   └── common-lib/
│   └── templates/
│       ├── _helpers.tpl
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── NOTES.txt
│       └── hooks/
│           ├── pre-install-job.yaml
│           └── post-install-job.yaml
└── devops-info-service-app2/
    ├── Chart.yaml
    ├── values.yaml
    ├── charts/
    │   └── common-lib/
    └── templates/
        ├── _helpers.tpl
        ├── deployment.yaml
        ├── service.yaml
        ├── NOTES.txt
        └── hooks/
            ├── pre-install-job.yaml
            └── post-install-job.yaml
```

### 2.2 Main chart purpose
The main application chart is `k8s/devops-info-service/`.

It converts the Lab 09 Kubernetes resources into Helm templates:
- `templates/deployment.yaml` — primary application Deployment
- `templates/service.yaml` — Service exposing the application
- `templates/hooks/pre-install-job.yaml` — validation Job before install
- `templates/hooks/post-install-job.yaml` — smoke-test Job after install
- `values.yaml` — shared default configuration
- `values-dev.yaml` — development overrides
- `values-prod.yaml` — production overrides

### 2.3 Values organization strategy
The values file is organized by concern:
- `image.*` — image repository, tag, pull policy
- `service.*` — type, ports, NodePort configuration
- `resources.*` — CPU and memory requests/limits
- `env.*` — application runtime variables
- `readinessProbe.*` and `livenessProbe.*` — health-check parameters
- `hooks.*` — hook image, weights, and wait timing

### 2.4 Helper strategy
The charts use a shared library chart named `common-lib`.

The library chart centralizes:
- chart name generation
- fullname generation
- chart labels
- selector labels

Each application chart also contains a small local `_helpers.tpl` file with wrapper templates, so the application templates remain readable and consistent.

---

## 3. Configuration Guide

### 3.1 Important values

| Value | Purpose | Default |
|------|---------|---------|
| `replicaCount` | Number of Pod replicas | `3` |
| `image.repository` | Container image repository | `dorley174/devops-info-service` |
| `image.tag` | Container image tag | `latest` |
| `service.type` | Service exposure mode | `NodePort` |
| `service.port` | Service port | `80` |
| `service.targetPort` | Target container port | `5000` |
| `service.nodePort` | Fixed NodePort for dev/local access | `30080` |
| `resources.requests.*` | Guaranteed resources | `100m / 128Mi` |
| `resources.limits.*` | Hard resource limits | `250m / 256Mi` |
| `env.appVariant` | Application variant identifier | `app1` |
| `env.appMessage` | Human-readable deployment message | `Lab 10 Helm deployment` |
| `env.serviceVersion` | Version string exposed by the app | `lab10-v1` |
| `readinessProbe.*` | Readiness check configuration | `/ready` |
| `livenessProbe.*` | Liveness check configuration | `/health` |
| `hooks.preInstall.*` | Pre-install validation Job settings | enabled |
| `hooks.postInstall.*` | Post-install smoke-test Job settings | enabled |

### 3.2 Environment-specific values

#### Development profile (`values-dev.yaml`)
- `replicaCount: 1`
- `service.type: NodePort`
- smaller resource requests and limits
- faster probe timings
- dev-specific application message and service version

#### Production profile (`values-prod.yaml`)
- `replicaCount: 3`
- `service.type: LoadBalancer`
- higher requests and limits
- slower and more realistic probe timings
- prod-specific application message and service version

### 3.3 Rendering and installation commands
Render with defaults:

```bash
helm template devops-app ./k8s/devops-info-service
```

Render with development values:

```bash
helm template devops-app ./k8s/devops-info-service -f ./k8s/devops-info-service/values-dev.yaml
```

Install development release:

```bash
helm install devops-app ./k8s/devops-info-service \
  -n devops-lab10 \
  --create-namespace \
  -f ./k8s/devops-info-service/values-dev.yaml \
  --set service.nodePort=30081 \
  --set hooks.postInstall.sleepSeconds=20 \
  --wait
```

Upgrade the same release to production:

```bash
helm upgrade devops-app ./k8s/devops-info-service \
  -n devops-lab10 \
  -f ./k8s/devops-info-service/values-prod.yaml \
  --set service.nodePort=30081 \
  --set hooks.postInstall.sleepSeconds=20 \
  --wait
```

---

## 4. Hook Implementation

### 4.1 Implemented hooks
Two lifecycle hooks were implemented in the main chart:

1. **Pre-install hook**
   - resource type: `Job`
   - purpose: validate that required chart values are present before installation
   - annotation: `helm.sh/hook: pre-install`
   - weight: `-5`

2. **Post-install hook**
   - resource type: `Job`
   - purpose: run a smoke test against the deployed Service `/ready` endpoint
   - annotation: `helm.sh/hook: post-install`
   - weight: `5`

### 4.2 Execution order
Hook execution order is controlled with hook weights:
- lower weight runs first
- `pre-install` uses `-5`
- `post-install` uses `5`

### 4.3 Deletion policy
Both hooks use this delete policy:

```text
before-hook-creation,hook-succeeded
```

This means:
- the previous hook resource is removed before a new hook is created
- successful hook Jobs are automatically deleted after completion

### 4.4 Important operational note
The post-install smoke-test hook is most reliable when the release is installed with `--wait`, because Helm will wait for regular resources to become ready before executing `post-install`.

---

## 5. Installation Evidence

### 5.1 Local chart validation
Commands used:

```bash
helm lint ./k8s/devops-info-service
helm template devops-app ./k8s/devops-info-service > /tmp/devops-app-rendered.yaml
helm install --dry-run --debug devops-app ./k8s/devops-info-service \
  -n devops-lab10 \
  --create-namespace \
  -f ./k8s/devops-info-service/values-dev.yaml
```

**Evidence — `helm lint`:**

```text
==> Linting ./k8s/devops-info-service
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed
```

**Evidence — `helm template` verification:**

```text
---
# Source: devops-info-service/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: devops-app-devops-info-service
  labels:
    helm.sh/chart: devops-info-service-0.1.0
    app.kubernetes.io/name: devops-info-service
    app.kubernetes.io/instance: devops-app
    app.kubernetes.io/version: "latest"
    app.kubernetes.io/managed-by: Helm

    app.kubernetes.io/component: "web"


    app.kubernetes.io/part-of: "devops-core-course"


spec:
  type: NodePort
  selector:
    app.kubernetes.io/name: devops-info-service
    app.kubernetes.io/instance: devops-app
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: 5000

      nodePort: 30080
---
# Source: devops-info-service/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: devops-app-devops-info-service
  labels:
    helm.sh/chart: devops-info-service-0.1.0
    app.kubernetes.io/name: devops-info-service
    app.kubernetes.io/instance: devops-app
    app.kubernetes.io/version: "latest"
    app.kubernetes.io/managed-by: Helm

    app.kubernetes.io/component: "web"


    app.kubernetes.io/part-of: "devops-core-course"


spec:
  replicas: 3
  revisionHistoryLimit: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app.kubernetes.io/name: devops-info-service
      app.kubernetes.io/instance: devops-app
  template:
    metadata:
      labels:
        helm.sh/chart: devops-info-service-0.1.0
        app.kubernetes.io/name: devops-info-service
        app.kubernetes.io/instance: devops-app
        app.kubernetes.io/version: "latest"
        app.kubernetes.io/managed-by: Helm

        app.kubernetes.io/component: "web"


        app.kubernetes.io/part-of: "devops-core-course"


    spec:
      securityContext:
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: devops-info-service
          image: "dorley174/devops-info-service:latest"
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 5000
              protocol: TCP
          env:
            - name: PORT
              value: "5000"
            - name: DEBUG
              value: "False"
            - name: APP_VARIANT
              value: "app1"
            - name: APP_MESSAGE
              value: "Lab 10 Helm deployment"
            - name: SERVICE_VERSION
              value: "lab10-v1"
          resources:
            limits:
              cpu: 250m
              memory: 256Mi
            requests:
              cpu: 100m
              memory: 128Mi
          readinessProbe:
            httpGet:
              path: /ready
              port: http
            initialDelaySeconds: 5
            periodSeconds: 5
            timeoutSeconds: 2
            failureThreshold: 3
          livenessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 15
            periodSeconds: 10
            timeoutSeconds: 2
            failureThreshold: 3
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
            runAsNonRoot: true
---
# Source: devops-info-service/templates/hooks/post-install-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: devops-app-devops-info-service-post-install
  labels:
    helm.sh/chart: devops-info-service-0.1.0
    app.kubernetes.io/name: devops-info-service
    app.kubernetes.io/instance: devops-app
    app.kubernetes.io/version: "latest"
    app.kubernetes.io/managed-by: Helm

    app.kubernetes.io/component: "web"


    app.kubernetes.io/part-of: "devops-core-course"


  annotations:
    "helm.sh/hook": post-install
    "helm.sh/hook-weight": "5"
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  backoffLimit: 0
  template:
    metadata:
      labels:
        helm.sh/chart: devops-info-service-0.1.0
        app.kubernetes.io/name: devops-info-service
        app.kubernetes.io/instance: devops-app
```

**Evidence — dry-run/debug output:**

```text
level=WARN msg="--dry-run is deprecated and should be replaced with '--dry-run=client'"
level=DEBUG msg="Original chart version" version=""
level=DEBUG msg="Chart path" path=/mnt/c/DevOps/DevOps-Core-Course/k8s/devops-info-service
level=DEBUG msg="number of dependencies in the chart" chart=devops-info-service dependencies=1
level=DEBUG msg="number of dependencies in the chart" chart=common-lib dependencies=0
NAME: devops-app
LAST DEPLOYED: Thu Apr  2 21:17:47 2026
NAMESPACE: devops-lab10
STATUS: pending-install
REVISION: 1
DESCRIPTION: Dry run complete
TEST SUITE: None
USER-SUPPLIED VALUES:
env:
  appMessage: Lab 10 Helm development deployment
  serviceVersion: lab10-dev
livenessProbe:
  initialDelaySeconds: 5
  periodSeconds: 10
readinessProbe:
  initialDelaySeconds: 3
  periodSeconds: 5
replicaCount: 1
resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 50m
    memory: 64Mi
service:
  nodePort: 30080
  port: 80
  targetPort: 5000
  type: NodePort

COMPUTED VALUES:
common-lib:
  global: {}
commonLabels: {}
component: web
containerPort: 5000
env:
  appMessage: Lab 10 Helm development deployment
  appVariant: app1
  debug: "False"
  port: "5000"
  serviceVersion: lab10-dev
fullnameOverride: ""
hooks:
  image:
    pullPolicy: IfNotPresent
    repository: busybox
    tag: "1.36"
  postInstall:
    enabled: true
    sleepSeconds: 5
    weight: 5
  preInstall:
    enabled: true
    sleepSeconds: 3
    weight: -5
image:
  pullPolicy: IfNotPresent
  repository: dorley174/devops-info-service
  tag: latest
livenessProbe:
  failureThreshold: 3
  initialDelaySeconds: 5
  path: /health
  periodSeconds: 10
  port: http
  timeoutSeconds: 2
nameOverride: ""
partOf: devops-core-course
readinessProbe:
  failureThreshold: 3
  initialDelaySeconds: 3
  path: /ready
  periodSeconds: 5
  port: http
  timeoutSeconds: 2
replicaCount: 1
resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 50m
    memory: 64Mi
revisionHistoryLimit: 10
service:
  nodePort: 30080
  port: 80
  targetPort: 5000
  type: NodePort
strategy:
  maxSurge: 1
  maxUnavailable: 0

HOOKS:
---
# Source: devops-info-service/templates/hooks/post-install-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: devops-app-devops-info-service-post-install
  labels:
    helm.sh/chart: devops-info-service-0.1.0
    app.kubernetes.io/name: devops-info-service
    app.kubernetes.io/instance: devops-app
    app.kubernetes.io/version: "latest"
    app.kubernetes.io/managed-by: Helm

    app.kubernetes.io/component: "web"


    app.kubernetes.io/part-of: "devops-core-course"


  annotations:
    "helm.sh/hook": post-install
    "helm.sh/hook-weight": "5"
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  backoffLimit: 0
  template:
    metadata:
      labels:
        helm.sh/chart: devops-info-service-0.1.0
        app.kubernetes.io/name: devops-info-service
        app.kubernetes.io/instance: devops-app
        app.kubernetes.io/version: "latest"
        app.kubernetes.io/managed-by: Helm

        app.kubernetes.io/component: "web"


        app.kubernetes.io/part-of: "devops-core-course"


    spec:
      restartPolicy: Never
      containers:
        - name: post-install-smoke-test
          image: busybox:1.36
          imagePullPolicy: IfNotPresent
          command:
            - sh
            - -c
            - >-
              echo "[post-install] running smoke test against devops-app-devops-info-service" &&
              sleep 5 &&
              wget -qO- http://devops-app-devops-info-service:80/ready &&
              echo &&
              echo "[post-install] smoke test passed"
---
# Source: devops-info-service/templates/hooks/pre-install-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: devops-app-devops-info-service-pre-install
  labels:
    helm.sh/chart: devops-info-service-0.1.0
    app.kubernetes.io/name: devops-info-service
    app.kubernetes.io/instance: devops-app
    app.kubernetes.io/version: "latest"
    app.kubernetes.io/managed-by: Helm

    app.kubernetes.io/component: "web"


    app.kubernetes.io/part-of: "devops-core-course"


  annotations:
    "helm.sh/hook": pre-install
    "helm.sh/hook-weight": "-5"
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  backoffLimit: 0
  template:
    metadata:
      labels:
        helm.sh/chart: devops-info-service-0.1.0
        app.kubernetes.io/name: devops-info-service
        app.kubernetes.io/instance: devops-app
        app.kubernetes.io/version: "latest"
        app.kubernetes.io/managed-by: Helm

        app.kubernetes.io/component: "web"


        app.kubernetes.io/part-of: "devops-core-course"


    spec:
      restartPolicy: Never
      containers:
        - name: pre-install-validation
          image: busybox:1.36
          imagePullPolicy: IfNotPresent
          command:
            - sh
            - -c
            - >-
              echo "[pre-install] validating chart values for devops-app-devops-info-service" &&
              test -n "dorley174/devops-info-service" &&
              echo "[pre-install] image repository is set" &&
              sleep 3 &&
              echo "[pre-install] validation completed"
MANIFEST:
---
# Source: devops-info-service/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: devops-app-devops-info-service
  labels:
    helm.sh/chart: devops-info-service-0.1.0
    app.kubernetes.io/name: devops-info-service
    app.kubernetes.io/instance: devops-app
    app.kubernetes.io/version: "latest"
    app.kubernetes.io/managed-by: Helm

    app.kubernetes.io/component: "web"


    app.kubernetes.io/part-of: "devops-core-course"


spec:
  type: NodePort
  selector:
    app.kubernetes.io/name: devops-info-service
    app.kubernetes.io/instance: devops-app
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: 5000

      nodePort: 30080
---
# Source: devops-info-service/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: devops-app-devops-info-service
  labels:
    helm.sh/chart: devops-info-service-0.1.0
    app.kubernetes.io/name: devops-info-service
    app.kubernetes.io/instance: devops-app
    app.kubernetes.io/version: "latest"
    app.kubernetes.io/managed-by: Helm

    app.kubernetes.io/component: "web"


    app.kubernetes.io/part-of: "devops-core-course"


spec:
  replicas: 1
  revisionHistoryLimit: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app.kubernetes.io/name: devops-info-service
      app.kubernetes.io/instance: devops-app
  template:
    metadata:
      labels:
        helm.sh/chart: devops-info-service-0.1.0
        app.kubernetes.io/name: devops-info-service
        app.kubernetes.io/instance: devops-app
        app.kubernetes.io/version: "latest"
        app.kubernetes.io/managed-by: Helm

        app.kubernetes.io/component: "web"


        app.kubernetes.io/part-of: "devops-core-course"


    spec:
      securityContext:
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: devops-info-service
          image: "dorley174/devops-info-service:latest"
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 5000
              protocol: TCP
          env:
            - name: PORT
              value: "5000"
            - name: DEBUG
              value: "False"
            - name: APP_VARIANT
              value: "app1"
            - name: APP_MESSAGE
              value: "Lab 10 Helm development deployment"
            - name: SERVICE_VERSION
              value: "lab10-dev"
          resources:
            limits:
              cpu: 100m
              memory: 128Mi
            requests:
              cpu: 50m
              memory: 64Mi
          readinessProbe:
            httpGet:
              path: /ready
              port: http
            initialDelaySeconds: 3
            periodSeconds: 5
            timeoutSeconds: 2
            failureThreshold: 3
          livenessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 5
            periodSeconds: 10
            timeoutSeconds: 2
            failureThreshold: 3
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
            runAsNonRoot: true

NOTES:
1. Get the release status:
   helm status devops-app -n devops-lab10

2. Inspect the rendered Service:
   kubectl get svc devops-app-devops-info-service -n devops-lab10

3. For local verification through port-forward:
   kubectl port-forward -n devops-lab10 service/devops-app-devops-info-service 8080:80
   curl http://127.0.0.1:8080/health
   curl http://127.0.0.1:8080/ready
```

During the first deployment attempts, two local environment issues were encountered. First, the Minikube kubeconfig context was stale and pointed to an outdated API server endpoint, which caused a cluster reachability error. After restarting Minikube and fixing the context, the next installation attempt failed because NodePort `30080` was already used by the Lab 09 Service in the `devops-lab09` namespace. To avoid modifying the previous lab environment, the Helm release was installed with `--set service.nodePort=30081`. A final adjustment was required for the `post-install` hook: the smoke-test Job initially ran too early, so the hook delay was increased with `--set hooks.postInstall.sleepSeconds=20`.

### 5.2 Development installation evidence
Commands used:

```bash
helm install devops-app ./k8s/devops-info-service \
  -n devops-lab10 \
  --create-namespace \
  -f ./k8s/devops-info-service/values-dev.yaml \
  --set service.nodePort=30081 \
  --set hooks.postInstall.sleepSeconds=20 \
  --wait

helm list -n devops-lab10
kubectl get all -n devops-lab10
kubectl describe deployment devops-app-devops-info-service -n devops-lab10
kubectl get svc devops-app-devops-info-service -n devops-lab10
```

**Evidence — `helm install`:**

```text
NAME: devops-app
LAST DEPLOYED: Thu Apr  2 21:37:40 2026
NAMESPACE: devops-lab10
STATUS: deployed
REVISION: 1
DESCRIPTION: Install complete
TEST SUITE: None
NOTES:
1. Get the release status:
   helm status devops-app -n devops-lab10

2. Inspect the rendered Service:
   kubectl get svc devops-app-devops-info-service -n devops-lab10

3. For local verification through port-forward:
   kubectl port-forward -n devops-lab10 service/devops-app-devops-info-service 8080:80
   curl http://127.0.0.1:8080/health
   curl http://127.0.0.1:8080/ready
```

**Evidence — `helm list`:**

```text
NAME            NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                           APP VERSION
devops-app      devops-lab10    1               2026-04-02 21:37:40.003860076 +0300 MSK deployed        devops-info-service-0.1.0       latest
```

**Evidence — `kubectl get all`:**

```text
NAME                                                 READY   STATUS    RESTARTS   AGE
pod/devops-app-devops-info-service-b9966ddc4-49k97   1/1     Running   0          101s

NAME                                     TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
service/devops-app-devops-info-service   NodePort   10.108.253.122   <none>        80:30081/TCP   102s

NAME                                             READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/devops-app-devops-info-service   1/1     1            1           102s

NAME                                                       DESIRED   CURRENT   READY   AGE
replicaset.apps/devops-app-devops-info-service-b9966ddc4   1         1         1       102s
```

**Evidence — `kubectl describe deployment`:**

```text
Name:                   devops-app-devops-info-service
Namespace:              devops-lab10
CreationTimestamp:      Thu, 02 Apr 2026 21:37:47 +0300
Labels:                 app.kubernetes.io/component=web
                        app.kubernetes.io/instance=devops-app
                        app.kubernetes.io/managed-by=Helm
                        app.kubernetes.io/name=devops-info-service
                        app.kubernetes.io/part-of=devops-core-course
                        app.kubernetes.io/version=latest
                        helm.sh/chart=devops-info-service-0.1.0
Annotations:            deployment.kubernetes.io/revision: 1
                        meta.helm.sh/release-name: devops-app
                        meta.helm.sh/release-namespace: devops-lab10
Selector:               app.kubernetes.io/instance=devops-app,app.kubernetes.io/name=devops-info-service
Replicas:               1 desired | 1 updated | 1 total | 1 available | 0 unavailable
StrategyType:           RollingUpdate
MinReadySeconds:        0
RollingUpdateStrategy:  0 max unavailable, 1 max surge
Pod Template:
  Labels:  app.kubernetes.io/component=web
           app.kubernetes.io/instance=devops-app
           app.kubernetes.io/managed-by=Helm
           app.kubernetes.io/name=devops-info-service
           app.kubernetes.io/part-of=devops-core-course
           app.kubernetes.io/version=latest
           helm.sh/chart=devops-info-service-0.1.0
  Containers:
   devops-info-service:
    Image:      dorley174/devops-info-service:latest
    Port:       5000/TCP (http)
    Host Port:  0/TCP (http)
    Limits:
      cpu:     100m
      memory:  128Mi
    Requests:
      cpu:      50m
      memory:   64Mi
    Liveness:   http-get http://:http/health delay=5s timeout=2s period=10s #success=1 #failure=3
    Readiness:  http-get http://:http/ready delay=3s timeout=2s period=5s #success=1 #failure=3
    Environment:
      PORT:             5000
      DEBUG:            False
      APP_VARIANT:      app1
      APP_MESSAGE:      Lab 10 Helm development deployment
      SERVICE_VERSION:  lab10-dev
    Mounts:             <none>
  Volumes:              <none>
  Node-Selectors:       <none>
  Tolerations:          <none>
Conditions:
  Type           Status  Reason
  ----           ------  ------
  Available      True    MinimumReplicasAvailable
  Progressing    True    NewReplicaSetAvailable
OldReplicaSets:  <none>
NewReplicaSet:   devops-app-devops-info-service-b9966ddc4 (1/1 replicas created)
Events:
  Type    Reason             Age   From                   Message
  ----    ------             ----  ----                   -------
  Normal  ScalingReplicaSet  101s  deployment-controller  Scaled up replica set devops-app-devops-info-service-b9966ddc4 from 0 to 1
```

**Evidence — `kubectl get svc`:**

```text
NAME                             TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
devops-app-devops-info-service   NodePort   10.108.253.122   <none>        80:30081/TCP   103s
```

### 5.3 Upgrade from development to production
Commands used:

```bash
helm upgrade devops-app ./k8s/devops-info-service \
  -n devops-lab10 \
  -f ./k8s/devops-info-service/values-prod.yaml \
  --set service.nodePort=30081 \
  --set hooks.postInstall.sleepSeconds=20 \
  --wait

helm list -n devops-lab10
kubectl get deploy,svc,pods -n devops-lab10 -o wide
kubectl describe deployment devops-app-devops-info-service -n devops-lab10
kubectl get svc devops-app-devops-info-service -n devops-lab10 -o wide
```

**Evidence — upgrade status:**

```text
Not executed yet. Fill this section with the real output of:
- helm upgrade ...
- helm list -n devops-lab10
- kubectl get deploy,svc,pods -n devops-lab10 -o wide
- kubectl describe deployment devops-app-devops-info-service -n devops-lab10
- kubectl get svc devops-app-devops-info-service -n devops-lab10 -o wide
```

### 5.4 Hook execution evidence
Commands used:

```bash
kubectl get jobs -n devops-lab10
kubectl describe job devops-app-devops-info-service-pre-install -n devops-lab10 || true
kubectl describe job devops-app-devops-info-service-post-install -n devops-lab10 || true
kubectl logs job/devops-app-devops-info-service-pre-install -n devops-lab10 || true
kubectl logs job/devops-app-devops-info-service-post-install -n devops-lab10 || true
```

If the delete policy already removed the Jobs, that is valid evidence too. In that case, show that `kubectl get jobs -n devops-lab10` no longer lists them.

**Evidence — `kubectl get jobs`:**

```text
No resources found in devops-lab10 namespace.
```

**Evidence — hook details or proof of deletion:**

```text
Error from server (NotFound): jobs.batch "devops-app-devops-info-service-pre-install" not found
Error from server (NotFound): jobs.batch "devops-app-devops-info-service-post-install" not found
```

This is expected because both hooks use the delete policy `before-hook-creation,hook-succeeded`, so successful hook Jobs are automatically removed after completion.

### 5.5 Application accessibility verification
Recommended local check via port-forward:

```bash
kubectl port-forward -n devops-lab10 service/devops-app-devops-info-service 8080:80
curl http://127.0.0.1:8080/health
curl http://127.0.0.1:8080/ready
curl http://127.0.0.1:8080/ | python3 -m json.tool
```

**Evidence — `/health`:**

```text
{"status":"healthy","timestamp":"2026-04-02T18:39:48.600Z","uptime_seconds":107,"variant":"app1"}
```

**Evidence — `/ready`:**

```text
{"message":"Lab 10 Helm development deployment","status":"ready","timestamp":"2026-04-02T18:39:54.967Z","uptime_seconds":114,"variant":"app1"}
```

**Evidence — root endpoint JSON:**

```text
{
    "endpoints": [
        {
            "description": "Service information",
            "method": "GET",
            "path": "/"
        },
        {
            "description": "Liveness health check",
            "method": "GET",
            "path": "/health"
        },
        {
            "description": "Readiness health check",
            "method": "GET",
            "path": "/ready"
        },
        {
            "description": "Prometheus metrics",
            "method": "GET",
            "path": "/metrics"
        }
    ],
    "request": {
        "client_ip": "127.0.0.1",
        "method": "GET",
        "path": "/",
        "user_agent": "curl/8.5.0"
    },
    "runtime": {
        "current_time": "2026-04-02T18:39:44.233Z",
        "timezone": "UTC",
        "uptime_human": "0 hours, 1 minute",
        "uptime_seconds": 102
    },
    "service": {
        "description": "DevOps course info service",
        "framework": "Flask",
        "message": "Lab 10 Helm development deployment",
        "name": "devops-info-service",
        "variant": "app1",
        "version": "lab10-dev"
    },
    "system": {
        "architecture": "x86_64",
        "cpu_count": 20,
        "hostname": "devops-app-devops-info-service-b9966ddc4-49k97",
        "platform": "Linux",
        "platform_version": "Linux-5.15.153.1-microsoft-standard-WSL2-x86_64-with-glibc2.36",
        "python_version": "3.13.1"
    }
}
```

---

## 6. Operations

### 6.1 Install

```bash
helm install devops-app ./k8s/devops-info-service \
  -n devops-lab10 \
  --create-namespace \
  -f ./k8s/devops-info-service/values-dev.yaml \
  --set service.nodePort=30081 \
  --set hooks.postInstall.sleepSeconds=20 \
  --wait
```

### 6.2 Upgrade

```bash
helm upgrade devops-app ./k8s/devops-info-service \
  -n devops-lab10 \
  -f ./k8s/devops-info-service/values-prod.yaml \
  --set service.nodePort=30081 \
  --set hooks.postInstall.sleepSeconds=20 \
  --wait
```

### 6.3 Rollback

```bash
helm history devops-app -n devops-lab10
helm rollback devops-app 1 -n devops-lab10 --wait
helm list -n devops-lab10
```

**Evidence — `helm history`:**

```text
TO_FILL_HELM_HISTORY
```

**Evidence — rollback result:**

```text
TO_FILL_HELM_ROLLBACK
```

### 6.4 Uninstall

```bash
helm uninstall devops-app -n devops-lab10
kubectl get all -n devops-lab10
```

**Evidence — uninstall result:**

```text
TO_FILL_HELM_UNINSTALL
```

---

## 7. Testing & Validation

### 7.1 Commands used for validation

```bash
helm lint ./k8s/devops-info-service
helm template devops-app ./k8s/devops-info-service
helm install --dry-run --debug devops-app ./k8s/devops-info-service \
  -n devops-lab10 \
  --create-namespace \
  -f ./k8s/devops-info-service/values-dev.yaml
```

### 7.2 Validation conclusion
The chart is considered valid when:
- `helm lint` finishes successfully
- `helm template` renders Kubernetes manifests without template errors
- `helm install --dry-run --debug` renders the release successfully
- the real installation creates a Deployment, a Service, Pods, and the hook Jobs
- the application responds on `/health` and `/ready`

**Short conclusion:**

`The Helm chart is valid. helm lint completed successfully, helm template rendered Kubernetes manifests without template errors, helm install --dry-run --debug rendered the release correctly, and the real installation created the expected Kubernetes resources. The application also responded successfully on /health and /ready.`

---

## 8. Bonus — Library Chart

### 8.1 Why a library chart was added
After creating a second application chart, helper logic became repetitive. The library chart removes duplication in these areas:
- naming logic
- common labels
- selector labels
- reusable helper patterns

### 8.2 Library chart details
The shared library chart is stored in:

```text
k8s/common-lib/
```

Its `Chart.yaml` uses:

```yaml
type: library
```

### 8.3 How the application charts use the library
Both application charts declare `common-lib` as a dependency in `Chart.yaml` and call the shared helper templates from their local wrappers.

### 8.4 Bonus deployment commands

```bash
helm install devops-app2 ./k8s/devops-info-service-app2 \
  -n devops-lab10 \
  --create-namespace \
  --set service.nodePort=30082 \
  --wait

helm list -n devops-lab10
kubectl get deploy,svc,pods -n devops-lab10 -o wide
kubectl port-forward -n devops-lab10 service/devops-app2-devops-info-service-app2 8081:80
curl http://127.0.0.1:8081/health
curl http://127.0.0.1:8081/ready
```

**Evidence — second chart install:**

```text
TO_FILL_BONUS_HELM_INSTALL
```

**Evidence — both releases present:**

```text
TO_FILL_BONUS_HELM_LIST
```

**Evidence — second app accessibility:**

```text
TO_FILL_BONUS_APP_CHECK
```

### 8.5 Benefits of the library approach
1. **DRY** — shared helper logic is defined once.
2. **Consistency** — both application charts render names and labels the same way.
3. **Maintainability** — future helper changes can be done in one place.
4. **Scalability** — additional application charts can reuse the same helper library.

---
