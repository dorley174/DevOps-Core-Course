# Lab 16 — Kubernetes Monitoring & Init Containers Report

## Environment

| Component | Value |
|---|---|
| Cluster | kind `lab16-monitoring` |
| Kubernetes context | `kind-lab16-monitoring` |
| Application namespace | `default` |
| Monitoring namespace | `monitoring` |
| Monitoring stack | `kube-prometheus-stack` |
| Grafana URL | `http://localhost:3001` |
| Alertmanager URL | `http://localhost:9093` |

---

## Task 1 — Kube-Prometheus Stack

### Stack Components

| Component | Role |
|---|---|
| Prometheus Operator | Manages Prometheus, Alertmanager, ServiceMonitor, and related custom resources inside Kubernetes. |
| Prometheus | Collects, stores, and queries metrics from Kubernetes components and monitored workloads. |
| Alertmanager | Receives alerts from Prometheus, groups them, and exposes alert state through the Alertmanager UI. |
| Grafana | Provides dashboards for visualizing Kubernetes, node, pod, network, and application metrics. |
| kube-state-metrics | Exposes Kubernetes object state metrics such as pods, deployments, StatefulSets, services, and PVCs. |
| node-exporter | Exposes node-level metrics such as CPU, memory, disk, filesystem, and network usage. |

### Installation Commands

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts/ || true
helm repo update

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --create-namespace \
  -f k8s/monitoring/values.yaml \
  --timeout 30m \
  --wait \
  --debug
```

### Installation Evidence

```bash
kubectl get po,svc -n monitoring
```

```text
NAME                                                         READY   STATUS    RESTARTS        AGE
pod/alertmanager-monitoring-kube-prometheus-alertmanager-0   2/2     Running   0               23m
pod/monitoring-grafana-64cb777489-mzmfz                     3/3     Running   0               2m19s
pod/monitoring-kube-prometheus-operator-86c4b6bddf-blhkv     1/1     Running   0               23m
pod/monitoring-kube-state-metrics-6d6b9cd8bc-8tvml           1/1     Running   0               23m
pod/monitoring-prometheus-node-exporter-9n4c5                1/1     Running   0               23m
pod/prometheus-monitoring-kube-prometheus-prometheus-0       2/2     Running   0               23m

NAME                                              TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
service/alertmanager-operated                     ClusterIP   None            <none>        9093/TCP,9094/TCP,9094/UDP   23m
service/monitoring-grafana                        ClusterIP   10.96.165.0     <none>        80/TCP                       23m
service/monitoring-kube-prometheus-alertmanager   ClusterIP   10.96.194.250   <none>        9093/TCP,8080/TCP            23m
service/monitoring-kube-prometheus-operator       ClusterIP   10.96.13.180    <none>        443/TCP                      23m
service/monitoring-kube-prometheus-prometheus     ClusterIP   10.96.37.250    <none>        9090/TCP,8080/TCP            23m
service/monitoring-kube-state-metrics             ClusterIP   10.96.20.92     <none>        8080/TCP                     23m
service/monitoring-prometheus-node-exporter       ClusterIP   10.96.16.174    <none>        9100/TCP                     23m
service/prometheus-operated                       ClusterIP   None            <none>        9090/TCP                     23m
```

```bash
helm list -A
```

```text
NAME                    NAMESPACE    REVISION   STATUS     CHART                         APP VERSION
devops-info-service     default      4          deployed   devops-info-service-0.4.0     latest
monitoring              monitoring   1          deployed   kube-prometheus-stack-85.0.3  v0.90.1
```

Screenshot: [Monitoring pods and services](screenshots/monitoring/01-monitoring-pods-services.png)

---

## Task 2 — Grafana Dashboard Exploration

### Grafana Access

```bash
kubectl port-forward svc/monitoring-grafana -n monitoring 3001:80 --address 127.0.0.1
```

Grafana health check:

```bash
curl http://localhost:3001/api/health
```

```json
{
  "database": "ok",
  "version": "13.0.1+security-01",
  "commit": "9bbe672d"
}
```

### 1. Pod Resources — StatefulSet CPU and Memory Usage

Dashboard used:

```text
Kubernetes / Compute Resources / Pod
```

Filters:

```text
namespace = default
pod = devops-info-service-0
```

Observed values for `devops-info-service-0`:

| Metric | Value |
|---|---:|
| CPU usage | `0.000940` cores |
| CPU request | `0.100` cores |
| CPU limit | `0.250` cores |
| CPU throttling | `0%` |
| Memory WSS | `30.0 MiB` |
| Memory request | `128 MiB` |
| Memory limit | `256 MiB` |

Screenshot: [StatefulSet pod resources](screenshots/monitoring/02-grafana-statefulset-pod-resources.png)

### 2. Namespace Analysis — Pods Using Most and Least CPU

Dashboard used:

```text
Kubernetes / Compute Resources / Namespace (Pods)
```

Filter:

```text
namespace = default
```

Observed CPU usage table:

| Pod | CPU Usage | CPU Requests | CPU Requests % | CPU Limits | CPU Limits % |
|---|---:|---:|---:|---:|---:|
| `devops-info-service-0` | `0.000966` | `0.100` | `0.966%` | `0.250` | `0.387%` |
| `devops-info-service-2` | `0.000965` | `0.100` | `0.965%` | `0.250` | `0.386%` |
| `devops-info-service-1` | `0.000907` | `0.100` | `0.907%` | `0.250` | `0.363%` |
| `init-download-demo` | `0` | `0` | `0%` | `0` | `0%` |
| `wait-for-service-demo` | `0` | `0` | `0%` | `0` | `0%` |

Most CPU usage in the `default` namespace was observed on `devops-info-service-0`. Lowest CPU usage was observed on the completed/demo pods `init-download-demo` and `wait-for-service-demo`.

Namespace-level summary:

| Metric | Value |
|---|---:|
| CPU utilisation from requests | `0.946%` |
| CPU utilisation from limits | `0.379%` |
| Memory utilisation from requests | `23.9%` |
| Memory utilisation from limits | `11.9%` |

Screenshot: [Default namespace pod CPU](screenshots/monitoring/03-grafana-default-namespace-pods-cpu.png)

### 3. Node Metrics — Memory Usage and CPU Cores

Dashboard used:

```text
Node Exporter / Nodes
```

Observed node metrics:

| Metric | Value |
|---|---:|
| Memory usage | `46.6%` |
| `/etc/hostname` disk size | `1.08 TiB` |
| `/etc/hostname` disk available | `1.01 TiB` |
| `/etc/hostname` disk used | `75.1 GiB` |
| `/etc/hostname` disk used % | `6.95%` |
| `/run` disk size | `4.07 GiB` |
| `/run` disk available | `4.05 GiB` |
| `/run` disk used | `12.4 MiB` |
| `/run` disk used % | `0.306%` |
| Logical CPU cores shown on dashboard | `20` |

Screenshot: [Node metrics](screenshots/monitoring/04-grafana-node-metrics.png)

### 4. Kubelet — Pods and Containers Managed

Dashboard used:

```text
Kubernetes / Kubelet
```

Observed kubelet metrics:

| Metric | Value |
|---|---:|
| Running kubelets | `1` |
| Running pods | `20` |
| Running containers | `24` |
| Actual volume count | `71` |
| Desired volume count | `71` |
| Config error count | `No data` |

Screenshot: [Kubelet pods and containers](screenshots/monitoring/05-grafana-kubelet-pods-containers.png)

### 5. Network Traffic

Dashboard used:

```text
Kubernetes / Networking / Namespace (Pods)
```

Screenshot captured with:

```text
namespace = kube-system
```

Observed current traffic:

| Metric | Value |
|---|---:|
| Current rate of bits received | `3.03 kb/s` |
| Current rate of bits transmitted | `5.10 kb/s` |

Observed pod-level network traffic:

| Pod | Receive Bandwidth | Transmit Bandwidth | Received Packets | Transmitted Packets | Dropped Packets |
|---|---:|---:|---:|---:|---:|
| `coredns-66bc5c9577-8bgx4` | `1.65 kb/s` | `2.88 kb/s` | `1.80 p/s` | `2.42 p/s` | `0 p/s` |
| `coredns-66bc5c9577-42fvq` | `1.26 kb/s` | `2.05 kb/s` | `1.58 p/s` | `2.12 p/s` | `0 p/s` |

Screenshot: [Namespace network traffic](screenshots/monitoring/06-grafana-default-namespace-network.png)

### 6. Alerts — Alertmanager UI

Alertmanager access:

```bash
kubectl port-forward svc/monitoring-kube-prometheus-alertmanager -n monitoring 9093:9093 --address 0.0.0.0
```

Observed active alerts:

| Group | Count |
|---|---:|
| Not grouped | `1` |
| `namespace="kube-system"` | `9` |
| `namespace="monitoring"` | `1` |
| Total active alerts | `11` |

Screenshot: [Alertmanager active alerts](screenshots/monitoring/07-alertmanager-active-alerts.png)

---

## Task 3 — Init Containers

### Init Container Manifests

Applied manifests:

```bash
kubectl apply -f k8s/init-containers/
```

Result:

```text
pod/init-download-demo created
pod/wait-for-service-demo created
```

Current pod state:

```bash
kubectl get pods
```

```text
NAME                    READY   STATUS    RESTARTS   AGE
devops-info-service-0   1/1     Running   0          43m
devops-info-service-1   1/1     Running   0          43m
devops-info-service-2   1/1     Running   0          43m
init-download-demo      1/1     Running   0          6m57s
wait-for-service-demo   1/1     Running   0          6m57s
```

### 1. Download Init Container

Command:

```bash
kubectl logs init-download-demo -c init-download
```

Output:

```text
Connecting to example.com (172.66.147.243:443)
wget: note: TLS certificate validation not implemented
saving to '/work-dir/index.html'
index.html           100% |********************************|   528  0:00:00 ETA
'/work-dir/index.html' saved
Download complete
```

Command:

```bash
kubectl exec init-download-demo -- cat /data/index.html
```

Output:

```html
<!doctype html><html lang="en"><head><title>Example Domain</title><meta name="viewport" content="width=device-width, initial-scale=1"><style>body{background:#eee;width:60vw;margin:15vh auto;font-family:system-ui,sans-serif}h1{font-size:1.5em}div{opacity:0.8}a:link,a:visited{color:#348}</style></head><body><div><h1>Example Domain</h1><p>This domain is for use in documentation examples without needing permission. Avoid use in operations.</p><p><a href="https://iana.org/domains/example">Learn more</a></p></div></body></html>
```

The init container downloaded `index.html` into a shared volume, and the main container successfully read the file from `/data/index.html`.

### 2. Wait-for-Service Pattern

Command:

```bash
kubectl logs wait-for-service-demo -c wait-for-grafana
```

Output:

```text
Server:         10.96.0.10
Address:        10.96.0.10:53

Name:   monitoring-grafana.monitoring.svc.cluster.local
Address: 10.96.165.0

Dependency is ready
```

Command:

```bash
kubectl logs wait-for-service-demo -c main-app
```

Output:

```text
Main container started after dependency check
```

The `wait-for-service` init container resolved `monitoring-grafana.monitoring.svc.cluster.local` before the main container started.

Screenshot: [Init container proof](screenshots/monitoring/08-init-services-states-proof.png)

---

## Final Cluster State

```bash
kubectl get pods -A
```

```text
NAMESPACE            NAME                                                     READY   STATUS    RESTARTS   AGE
default              devops-info-service-0                                    1/1     Running   0          43m
default              devops-info-service-1                                    1/1     Running   0          43m
default              devops-info-service-2                                    1/1     Running   0          43m
default              init-download-demo                                       1/1     Running   0          6m57s
default              wait-for-service-demo                                    1/1     Running   0          6m57s
kube-system          coredns-66bc5c9577-42fvq                                 1/1     Running   0          65m
kube-system          coredns-66bc5c9577-8bgx4                                 1/1     Running   0          65m
kube-system          etcd-lab16-monitoring-control-plane                      1/1     Running   0          65m
kube-system          kindnet-2nlf6                                            1/1     Running   0          65m
kube-system          kube-apiserver-lab16-monitoring-control-plane            1/1     Running   0          65m
kube-system          kube-controller-manager-lab16-monitoring-control-plane   1/1     Running   0          65m
kube-system          kube-proxy-cxlwb                                         1/1     Running   0          65m
kube-system          kube-scheduler-lab16-monitoring-control-plane            1/1     Running   0          65m
local-path-storage   local-path-provisioner-5c4cdb564f-87fpm                  1/1     Running   0          65m
monitoring           alertmanager-monitoring-kube-prometheus-alertmanager-0   2/2     Running   0          10m
monitoring           monitoring-grafana-84679f6c87-5c8c9                      3/3     Running   1          10m
monitoring           monitoring-kube-prometheus-operator-86c4b6bddf-blhkv     1/1     Running   0          10m
monitoring           monitoring-kube-state-metrics-6d6b9cd8bc-8tvml           1/1     Running   0          10m
monitoring           monitoring-prometheus-node-exporter-9n4c5                1/1     Running   0          10m
monitoring           prometheus-monitoring-kube-prometheus-prometheus-0       2/2     Running   0          10m
```

## Screenshot Index

| Screenshot | File |
|---|---|
| Monitoring pods and services | [01-monitoring-pods-services.png](screenshots/monitoring/01-monitoring-pods-services.png) |
| StatefulSet pod CPU and memory | [02-grafana-statefulset-pod-resources.png](screenshots/monitoring/02-grafana-statefulset-pod-resources.png) |
| Namespace pod CPU and memory | [03-grafana-default-namespace-pods-cpu.png](screenshots/monitoring/03-grafana-default-namespace-pods-cpu.png) |
| Node metrics | [04-grafana-node-metrics.png](screenshots/monitoring/04-grafana-node-metrics.png) |
| Kubelet pods and containers | [05-grafana-kubelet-pods-containers.png](screenshots/monitoring/05-grafana-kubelet-pods-containers.png) |
| Namespace network traffic | [06-grafana-default-namespace-network.png](screenshots/monitoring/06-grafana-default-namespace-network.png) |
| Alertmanager active alerts | [07-alertmanager-active-alerts.png](screenshots/monitoring/07-alertmanager-active-alerts.png) |
| Init container proof | [08-init-services-states-proof.png](screenshots/monitoring/08-init-services-states-proof.png) |
