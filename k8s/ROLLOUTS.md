# Lab 14 — Progressive Delivery with Argo Rollouts

This report documents the implementation and verification of progressive delivery for the `devops-info-service` Helm chart. The Lab 13 Kubernetes `Deployment` was replaced with an Argo Rollouts `Rollout`, and both required deployment strategies were implemented and tested: **canary** and **blue-green**.

The lab was completed from **VS Code + WSL** using a local **minikube** Kubernetes cluster. No bonus or extra-credit analysis template was implemented.

---

## 1. Environment and Argo Rollouts Setup

### 1.1 Kubernetes cluster

The local Kubernetes cluster was started with minikube and `kubectl` was configured to use the `minikube` context.

Commands used:

```bash
minikube start --driver=docker
kubectl cluster-info
kubectl get nodes
kubectl config current-context
```

Evidence:

```text
Kubernetes control plane is running at https://127.0.0.1:57403
CoreDNS is running at https://127.0.0.1:57403/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   34d   v1.35.1

minikube
```

### 1.2 Argo Rollouts controller installation

Commands used:

```bash
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
kubectl get pods -n argo-rollouts
```

Evidence:

```text
namespace/argo-rollouts created
customresourcedefinition.apiextensions.k8s.io/analysisruns.argoproj.io created
customresourcedefinition.apiextensions.k8s.io/analysistemplates.argoproj.io created
customresourcedefinition.apiextensions.k8s.io/clusteranalysistemplates.argoproj.io created
customresourcedefinition.apiextensions.k8s.io/experiments.argoproj.io created
customresourcedefinition.apiextensions.k8s.io/rollouts.argoproj.io created
serviceaccount/argo-rollouts created
clusterrole.rbac.authorization.k8s.io/argo-rollouts created
clusterrolebinding.rbac.authorization.k8s.io/argo-rollouts created
configmap/argo-rollouts-config created
secret/argo-rollouts-notification-secret created
service/argo-rollouts-metrics created
deployment.apps/argo-rollouts created

NAME                            READY   STATUS    RESTARTS   AGE
argo-rollouts-5f64f8d68-rl29d   1/1     Running   0          70s
```

### 1.3 kubectl Argo Rollouts plugin

Commands used:

```bash
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
chmod +x kubectl-argo-rollouts-linux-amd64
sudo mv kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts
kubectl argo rollouts version
```

Evidence:

```text
kubectl-argo-rollouts: v1.9.0+838d4e7
  BuildDate: 2026-03-20T21:08:11Z
  GitCommit: 838d4e792be666ec11bd0c80331e0c5511b5010e
  GitTreeState: clean
  GoVersion: go1.24.13
  Compiler: gc
  Platform: linux/amd64
```

### 1.4 Dashboard access

The dashboard resources were installed in the `argo-rollouts` namespace. The standalone dashboard service was created successfully, but the working dashboard view was opened through the kubectl plugin.

Commands used:

```bash
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/dashboard-install.yaml
kubectl get pods -n argo-rollouts
kubectl get svc -n argo-rollouts
kubectl argo rollouts dashboard -n devops-lab14
```

Evidence:

```text
serviceaccount/argo-rollouts-dashboard created
clusterrole.rbac.authorization.k8s.io/argo-rollouts-dashboard created
clusterrolebinding.rbac.authorization.k8s.io/argo-rollouts-dashboard created
service/argo-rollouts-dashboard created
deployment.apps/argo-rollouts-dashboard created

NAME                                      READY   STATUS    RESTARTS   AGE
argo-rollouts-5f64f8d68-rl29d             1/1     Running   0          11m
argo-rollouts-dashboard-755bbc64c-zgbpx   1/1     Running   0          5m8s

NAME                      TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
argo-rollouts-dashboard   ClusterIP   10.97.126.126    <none>        3100/TCP   0s
argo-rollouts-metrics     ClusterIP   10.109.225.192   <none>        8090/TCP   6m16s
```

Dashboard screenshots captured during verification:

![Canary rollout paused at 20 percent](screenshots/lab14-canary-paused.png)

![Blue-green preview rollout before promotion](screenshots/lab14-bluegreen-preview.png)

### 1.5 Rollout vs Deployment

A regular Kubernetes `Deployment` supports rolling updates and rollbacks, but it does not provide first-class progressive delivery controls. An Argo `Rollout` keeps the familiar `replicas`, `selector`, and `template` structure while adding advanced strategy configuration under `spec.strategy`.

| Area | Kubernetes Deployment | Argo Rollout |
|---|---|---|
| API kind | `Deployment` | `Rollout` |
| API group | `apps/v1` | `argoproj.io/v1alpha1` |
| Update strategy | `RollingUpdate` or `Recreate` | `canary` or `blueGreen` |
| Manual promotion | Not built in | Supported with `kubectl argo rollouts promote` |
| Abort during release | Limited to normal rollback behavior | Supported with `kubectl argo rollouts abort` |
| Dashboard | Standard Kubernetes tools only | Argo Rollouts dashboard |
| Preview service | Not native | Native blue-green preview service support |
| Progression steps | Not native | Step-based progressive delivery |

---

## 2. Helm Chart Implementation

### 2.1 Files changed

| File | Purpose |
|---|---|
| `k8s/devops-info-service/templates/rollout.yaml` | Adds the Argo `Rollout` resource. |
| `k8s/devops-info-service/templates/deployment.yaml` | Disables the old `Deployment` when `.Values.rollout.enabled=true`. |
| `k8s/devops-info-service/templates/service-preview.yaml` | Adds the blue-green preview Service. |
| `k8s/devops-info-service/templates/service.yaml` | Keeps the active Service and avoids managing `.spec.selector` during blue-green rollouts. |
| `k8s/devops-info-service/values.yaml` | Adds rollout defaults and hook image configuration. |
| `k8s/devops-info-service/values-canary.yaml` | Canary-specific values. |
| `k8s/devops-info-service/values-bluegreen.yaml` | Blue-green-specific values. |
| `k8s/devops-info-service/templates/NOTES.txt` | Adds operational commands for Argo Rollouts. |

Two practical fixes were also applied during verification:

1. The Lab 14 values disable the old Helm `postInstall` hook because the application is already verified through rollout status and service checks.
2. For blue-green mode, Helm does not render Service selectors. Argo Rollouts owns the active and preview Service selectors during blue-green promotion.

### 2.2 Chart validation

Commands used:

```bash
ls k8s/devops-info-service
helm lint k8s/devops-info-service
helm template devops-info-service k8s/devops-info-service \
  -n devops-lab14 \
  -f k8s/devops-info-service/values-bluegreen.yaml \
  --set env.appMessage="Lab 14 blue-green green version" \
  --set env.serviceVersion="lab14-bg-green" \
  | sed -n '/kind: Service/,/---/p'
```

Evidence:

```text
Chart.yaml  charts  files  templates  values-bluegreen.yaml  values-canary.yaml  values-dev.yaml  values-prod.yaml  values.yaml

==> Linting k8s/devops-info-service
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed
```

Rendered blue-green Services do not include static selectors, allowing Argo Rollouts to manage them:

```text
kind: Service
metadata:
  name: devops-info-service-preview
spec:
  type: ClusterIP
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: 5000
---
kind: Service
metadata:
  name: devops-info-service
spec:
  type: NodePort
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: 5000
      nodePort: 30083
---
```

---

## 3. Canary Deployment

### 3.1 Strategy configuration

The canary strategy is configured through `values.yaml` and `values-canary.yaml`.

```yaml
rollout:
  enabled: true
  strategy: canary
  canary:
    maxSurge: 1
    maxUnavailable: 0
    steps:
      - setWeight: 20
      - pause: {}
      - setWeight: 40
      - pause:
          duration: 30s
      - setWeight: 60
      - pause:
          duration: 30s
      - setWeight: 80
      - pause:
          duration: 30s
      - setWeight: 100
```

The first pause is manual. After the rollout reaches the 20% step, it waits for an explicit promotion. The later pauses are timed and progress automatically after 30 seconds.

### 3.2 Initial canary deployment

Commands used:

```bash
kubectl create namespace devops-lab14 --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install devops-info-service k8s/devops-info-service \
  -n devops-lab14 \
  -f k8s/devops-info-service/values-canary.yaml
helm list -n devops-lab14
kubectl get rollout,pods,svc,jobs -n devops-lab14
kubectl argo rollouts get rollout devops-info-service -n devops-lab14
```

Evidence:

```text
Release "devops-info-service" does not exist. Installing it now.
NAME: devops-info-service
LAST DEPLOYED: Thu Apr 30 21:22:43 2026
NAMESPACE: devops-lab14
STATUS: deployed
REVISION: 1
DESCRIPTION: Install complete

NAME                    NAMESPACE       REVISION   UPDATED                                 STATUS    CHART                       APP VERSION
devops-info-service     devops-lab14    1          2026-04-30 21:22:43.424672352 +0300 MSK deployed  devops-info-service-0.4.0   latest

NAME                                      DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
rollout.argoproj.io/devops-info-service   3         3         3            3           16s

NAME                                       READY   STATUS    RESTARTS   AGE
pod/devops-info-service-85bfc4dd4d-ptc6w   1/1     Running   0          15s
pod/devops-info-service-85bfc4dd4d-r2nns   1/1     Running   0          15s
pod/devops-info-service-85bfc4dd4d-r6pf2   1/1     Running   0          15s

NAME                          TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
service/devops-info-service   NodePort   10.107.46.137   <none>        80:30083/TCP   16s
```

Initial rollout status:

```text
Name:            devops-info-service
Namespace:       devops-lab14
Status:          ✔ Healthy
Strategy:        Canary
  Step:          9/9
  SetWeight:     100
  ActualWeight:  100
Images:          dorley174/devops-info-service:lab13 (stable)
Replicas:
  Desired:       3
  Current:       3
  Updated:       3
  Ready:         3
  Available:     3
```

### 3.3 Canary update paused at 20%

A new canary revision was triggered by changing the application message and service version.

Commands used:

```bash
helm upgrade devops-info-service k8s/devops-info-service \
  -n devops-lab14 \
  -f k8s/devops-info-service/values-canary.yaml \
  --set env.appMessage="Lab 14 canary version 2" \
  --set env.serviceVersion="lab14-canary-v2"

kubectl argo rollouts get rollout devops-info-service -n devops-lab14 -w
```

Evidence:

```text
Name:            devops-info-service
Namespace:       devops-lab14
Status:          ॥ Paused
Message:         CanaryPauseStep
Strategy:        Canary
  Step:          1/9
  SetWeight:     20
  ActualWeight:  25
Images:          dorley174/devops-info-service:lab13 (canary, stable)
Replicas:
  Desired:       3
  Current:       4
  Updated:       1
  Ready:         4
  Available:     4

NAME                                             KIND        STATUS     AGE    INFO
⟳ devops-info-service                            Rollout     ॥ Paused   3m10s
├──# revision:2
│  └──⧉ devops-info-service-7f899598bd           ReplicaSet  ✔ Healthy  11s    canary
│     └──□ devops-info-service-7f899598bd-g7ps4  Pod         ✔ Running  11s    ready:1/1
└──# revision:1
   └──⧉ devops-info-service-85bfc4dd4d           ReplicaSet  ✔ Healthy  3m10s  stable
      ├──□ devops-info-service-85bfc4dd4d-ptc6w  Pod         ✔ Running  3m9s   ready:1/1
      ├──□ devops-info-service-85bfc4dd4d-r2nns  Pod         ✔ Running  3m9s   ready:1/1
      └──□ devops-info-service-85bfc4dd4d-r6pf2  Pod         ✔ Running  3m9s   ready:1/1
```

Dashboard evidence:

![Canary rollout paused at 20 percent](/k8s/evidence/lab14-canary-paused.png)

### 3.4 Canary promotion and completion

Commands used:

```bash
kubectl argo rollouts promote devops-info-service -n devops-lab14
kubectl argo rollouts get rollout devops-info-service -n devops-lab14 -w
```

Evidence:

```text
Name:            devops-info-service
Namespace:       devops-lab14
Status:          ✔ Healthy
Strategy:        Canary
  Step:          9/9
  SetWeight:     100
  ActualWeight:  100
Images:          dorley174/devops-info-service:lab13 (stable)
Replicas:
  Desired:       3
  Current:       3
  Updated:       3
  Ready:         3
  Available:     3

NAME                                             KIND        STATUS        AGE    INFO
⟳ devops-info-service                            Rollout     ✔ Healthy     10m
├──# revision:2
│  └──⧉ devops-info-service-7f899598bd           ReplicaSet  ✔ Healthy     7m17s  stable
│     ├──□ devops-info-service-7f899598bd-g7ps4  Pod         ✔ Running     7m17s  ready:1/1
│     ├──□ devops-info-service-7f899598bd-lsd6s  Pod         ✔ Running     2m49s  ready:1/1
│     └──□ devops-info-service-7f899598bd-4chms  Pod         ✔ Running     2m8s   ready:1/1
└──# revision:1
   └──⧉ devops-info-service-85bfc4dd4d           ReplicaSet  • ScaledDown  10m
```

### 3.5 Canary abort and rollback behavior

A third revision was started and then aborted during the manual pause.

Commands used:

```bash
helm upgrade devops-info-service k8s/devops-info-service \
  -n devops-lab14 \
  -f k8s/devops-info-service/values-canary.yaml \
  --set env.appMessage="Lab 14 canary version to abort" \
  --set env.serviceVersion="lab14-canary-abort"

kubectl argo rollouts get rollout devops-info-service -n devops-lab14
kubectl argo rollouts abort devops-info-service -n devops-lab14
kubectl argo rollouts get rollout devops-info-service -n devops-lab14
kubectl get pods -n devops-lab14
```

Evidence before abort:

```text
Name:            devops-info-service
Namespace:       devops-lab14
Status:          ॥ Paused
Message:         CanaryPauseStep
Strategy:        Canary
  Step:          1/9
  SetWeight:     20
  ActualWeight:  25

NAME                                             KIND        STATUS        AGE    INFO
⟳ devops-info-service                            Rollout     ॥ Paused      11m
├──# revision:3
│  └──⧉ devops-info-service-54b58d48df           ReplicaSet  ✔ Healthy     16s    canary
│     └──□ devops-info-service-54b58d48df-w7cp7  Pod         ✔ Running     15s    ready:1/1
├──# revision:2
│  └──⧉ devops-info-service-7f899598bd           ReplicaSet  ✔ Healthy     8m10s  stable
```

Evidence after abort:

```text
rollout 'devops-info-service' aborted

Name:            devops-info-service
Namespace:       devops-lab14
Status:          ✖ Degraded
Message:         RolloutAborted: Rollout aborted update to revision 3
Strategy:        Canary
  Step:          0/9
  SetWeight:     0
  ActualWeight:  0
Images:          dorley174/devops-info-service:lab13 (stable)
Replicas:
  Desired:       3
  Current:       3
  Updated:       0
  Ready:         3
  Available:     3

NAME                                             KIND        STATUS         AGE    INFO
⟳ devops-info-service                            Rollout     ✖ Degraded     11m
├──# revision:3
│  └──⧉ devops-info-service-54b58d48df           ReplicaSet  • ScaledDown   63s    canary
│     └──□ devops-info-service-54b58d48df-w7cp7  Pod         ◌ Terminating  62s    ready:1/1
├──# revision:2
│  └──⧉ devops-info-service-7f899598bd           ReplicaSet  ✔ Healthy      8m57s  stable
```

Stable pods after abort:

```text
NAME                                   READY   STATUS    RESTARTS   AGE
devops-info-service-7f899598bd-4chms   1/1     Running   0          6m44s
devops-info-service-7f899598bd-g7ps4   1/1     Running   0          11m
devops-info-service-7f899598bd-lsd6s   1/1     Running   0          7m25s
```

The abort stopped the canary revision and kept the previously stable ReplicaSet serving traffic.

---

## 4. Blue-Green Deployment

### 4.1 Strategy configuration

The blue-green strategy is configured in `values-bluegreen.yaml`.

```yaml
rollout:
  enabled: true
  strategy: blueGreen
  blueGreen:
    autoPromotionEnabled: false
    scaleDownDelaySeconds: 30
    autoPromotionSeconds: null
```

The generated `Rollout` uses the active and preview Services:

```yaml
strategy:
  blueGreen:
    activeService: devops-info-service
    previewService: devops-info-service-preview
    autoPromotionEnabled: false
    scaleDownDelaySeconds: 30
```

With `autoPromotionEnabled: false`, the new green version is created and exposed through the preview service, but active traffic is not switched until manual promotion.

### 4.2 Initial blue-green deployment

Commands used:

```bash
helm upgrade devops-info-service k8s/devops-info-service \
  -n devops-lab14 \
  -f k8s/devops-info-service/values-bluegreen.yaml

kubectl get rollout,pods,svc -n devops-lab14
kubectl argo rollouts get rollout devops-info-service -n devops-lab14
```

Evidence:

```text
Release "devops-info-service" has been upgraded. Happy Helming!
NAME: devops-info-service
LAST DEPLOYED: Thu Apr 30 21:39:33 2026
NAMESPACE: devops-lab14
STATUS: deployed
REVISION: 4
DESCRIPTION: Upgrade complete

NAME                                      DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
rollout.argoproj.io/devops-info-service   3         6         3            3           16m

NAME                                       READY   STATUS              RESTARTS   AGE
pod/devops-info-service-5fff8cf6c7-hmqhn   0/1     ContainerCreating   0          2s
pod/devops-info-service-5fff8cf6c7-lczzs   0/1     ContainerCreating   0          2s
pod/devops-info-service-5fff8cf6c7-rrdxf   0/1     ContainerCreating   0          2s
pod/devops-info-service-7f899598bd-4chms   1/1     Running             0          8m39s
pod/devops-info-service-7f899598bd-g7ps4   1/1     Running             0          13m
pod/devops-info-service-7f899598bd-lsd6s   1/1     Running             0          9m20s

NAME                                  TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
service/devops-info-service           NodePort    10.107.46.137   <none>        80:30083/TCP   16m
service/devops-info-service-preview   ClusterIP   10.105.216.66   <none>        80/TCP         2s
```

After the initial blue-green deployment completed:

```text
Name:            devops-info-service
Namespace:       devops-lab14
Status:          ✔ Healthy
Strategy:        BlueGreen
Images:          dorley174/devops-info-service:lab13 (stable, active)
Replicas:
  Desired:       3
  Current:       3
  Updated:       3
  Ready:         3
  Available:     3

NAME                                             KIND        STATUS        AGE    INFO
⟳ devops-info-service                            Rollout     ✔ Healthy     18m
├──# revision:4
│  └──⧉ devops-info-service-5fff8cf6c7           ReplicaSet  ✔ Healthy     89s    stable,active
│     ├──□ devops-info-service-5fff8cf6c7-hmqhn  Pod         ✔ Running     89s    ready:1/1
│     ├──□ devops-info-service-5fff8cf6c7-lczzs  Pod         ✔ Running     89s    ready:1/1
│     └──□ devops-info-service-5fff8cf6c7-rrdxf  Pod         ✔ Running     89s    ready:1/1
```

### 4.3 Green preview before promotion

A new green revision was triggered by changing the message and service version.

Commands used:

```bash
helm upgrade devops-info-service k8s/devops-info-service \
  -n devops-lab14 \
  -f k8s/devops-info-service/values-bluegreen.yaml \
  --set env.appMessage="Lab 14 blue-green green version" \
  --set env.serviceVersion="lab14-bg-green"

kubectl argo rollouts get rollout devops-info-service -n devops-lab14
```

Evidence:

```text
Name:            devops-info-service
Namespace:       devops-lab14
Status:          ॥ Paused
Message:         BlueGreenPause
Strategy:        BlueGreen
Images:          dorley174/devops-info-service:lab13 (active, preview, stable)
Replicas:
  Desired:       3
  Current:       6
  Updated:       3
  Ready:         3
  Available:     3

NAME                                             KIND        STATUS        AGE    INFO
⟳ devops-info-service                            Rollout     ॥ Paused      21m
├──# revision:5
│  └──⧉ devops-info-service-f67d49585            ReplicaSet  ✔ Healthy     110s   preview
│     ├──□ devops-info-service-f67d49585-r4tlq   Pod         ✔ Running     110s   ready:1/1
│     ├──□ devops-info-service-f67d49585-sws2w   Pod         ✔ Running     110s   ready:1/1
│     └──□ devops-info-service-f67d49585-z9g7f   Pod         ✔ Running     110s   ready:1/1
├──# revision:4
│  └──⧉ devops-info-service-5fff8cf6c7           ReplicaSet  ✔ Healthy     4m55s  stable,active
│     ├──□ devops-info-service-5fff8cf6c7-hmqhn  Pod         ✔ Running     4m55s  ready:1/1
│     ├──□ devops-info-service-5fff8cf6c7-lczzs  Pod         ✔ Running     4m55s  ready:1/1
│     └──□ devops-info-service-5fff8cf6c7-rrdxf  Pod         ✔ Running     4m55s  ready:1/1
```

Dashboard evidence:

![Blue-green preview rollout before promotion](/k8s/evidence/lab14-bluegreen-preview.png)

### 4.4 Active and preview service comparison

The active Service and preview Service were exposed locally with separate port-forwards.

Commands used:

```bash
kubectl port-forward -n devops-lab14 service/devops-info-service 8080:80
kubectl port-forward -n devops-lab14 service/devops-info-service-preview 8081:80
curl http://127.0.0.1:8080/ready
curl http://127.0.0.1:8081/ready
```

Evidence:

```text
{"message":"Lab 14 blue-green active deployment","status":"ready","timestamp":"2026-04-30T18:57:01.749Z","uptime_seconds":1039,"variant":"app1"}
{"message":"Lab 14 blue-green green version","status":"ready","timestamp":"2026-04-30T18:57:01.770Z","uptime_seconds":857,"variant":"app1"}
```

The active Service still returned the currently active deployment, while the preview Service returned the new green version before promotion.

### 4.5 Blue-green promotion

Commands used:

```bash
kubectl argo rollouts promote devops-info-service -n devops-lab14
kubectl argo rollouts get rollout devops-info-service -n devops-lab14
curl http://127.0.0.1:8080/ready
```

Evidence:

```text
rollout 'devops-info-service' promoted

Name:            devops-info-service
Namespace:       devops-lab14
Status:          ✔ Healthy
Strategy:        BlueGreen
Images:          dorley174/devops-info-service:lab13 (active, stable)
Replicas:
  Desired:       3
  Current:       6
  Updated:       3
  Ready:         3
  Available:     3

NAME                                             KIND        STATUS        AGE  INFO
⟳ devops-info-service                            Rollout     ✔ Healthy     36m
├──# revision:5
│  └──⧉ devops-info-service-f67d49585            ReplicaSet  ✔ Healthy     17m  stable,active
│     ├──□ devops-info-service-f67d49585-r4tlq   Pod         ✔ Running     17m  ready:1/1
│     ├──□ devops-info-service-f67d49585-sws2w   Pod         ✔ Running     17m  ready:1/1
│     └──□ devops-info-service-f67d49585-z9g7f   Pod         ✔ Running     17m  ready:1/1
├──# revision:4
│  └──⧉ devops-info-service-5fff8cf6c7           ReplicaSet  ✔ Healthy     20m  delay:26s
```

After restarting the active Service port-forward, the active Service returned the promoted green version:

```text
{"message":"Lab 14 blue-green green version","status":"ready","timestamp":"2026-04-30T19:01:54.098Z","uptime_seconds":1149,"variant":"app1"}
```

### 4.6 Final blue-green status

Commands used:

```bash
helm list -n devops-lab14
kubectl argo rollouts get rollout devops-info-service -n devops-lab14
kubectl get pods,svc -n devops-lab14
```

Evidence:

```text
NAME                    NAMESPACE       REVISION        UPDATED                                 STATUS    CHART                       APP VERSION
devops-info-service     devops-lab14    6               2026-04-30 21:54:14.691576447 +0300 MSK deployed  devops-info-service-0.4.0   latest

Name:            devops-info-service
Namespace:       devops-lab14
Status:          ✔ Healthy
Strategy:        BlueGreen
Images:          dorley174/devops-info-service:lab13 (stable, active)
Replicas:
  Desired:       3
  Current:       3
  Updated:       3
  Ready:         3
  Available:     3

NAME                                            KIND        STATUS        AGE  INFO
⟳ devops-info-service                           Rollout     ✔ Healthy     40m
├──# revision:5
│  └──⧉ devops-info-service-f67d49585           ReplicaSet  ✔ Healthy     20m  stable,active
│     ├──□ devops-info-service-f67d49585-r4tlq  Pod         ✔ Running     20m  ready:1/1
│     ├──□ devops-info-service-f67d49585-sws2w  Pod         ✔ Running     20m  ready:1/1
│     └──□ devops-info-service-f67d49585-z9g7f  Pod         ✔ Running     20m  ready:1/1
├──# revision:4
│  └──⧉ devops-info-service-5fff8cf6c7          ReplicaSet  • ScaledDown  23m
├──# revision:3
│  └──⧉ devops-info-service-54b58d48df          ReplicaSet  • ScaledDown  29m
├──# revision:2
│  └──⧉ devops-info-service-7f899598bd          ReplicaSet  • ScaledDown  37m
└──# revision:1
   └──⧉ devops-info-service-85bfc4dd4d          ReplicaSet  • ScaledDown  40m

NAME                                      READY   STATUS    RESTARTS   AGE
pod/devops-info-service-f67d49585-r4tlq   1/1     Running   0          20m
pod/devops-info-service-f67d49585-sws2w   1/1     Running   0          20m
pod/devops-info-service-f67d49585-z9g7f   1/1     Running   0          20m

NAME                                  TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
service/devops-info-service           NodePort    10.107.46.137   <none>        80:30083/TCP   40m
service/devops-info-service-preview   ClusterIP   10.105.216.66   <none>        80/TCP         23m
```

---

## 5. Strategy Comparison

| Strategy | Best for | Strengths | Trade-offs |
|---|---|---|---|
| Canary | Gradual releases where risk should be reduced step by step | Small blast radius, controlled progression, manual gate at 20%, visible rollout progress | More complex rollout timeline; during rollout, old and new versions may run together |
| Blue-green | Fast releases where the full new version should be tested before active traffic switches | Separate preview Service, manual promotion, fast active Service cutover | Requires enough resources to run old and new versions at the same time |

The canary test demonstrated controlled progressive delivery with a manual pause at 20%, successful promotion to 100%, and an abort that preserved the stable ReplicaSet. The blue-green test demonstrated a separate preview ReplicaSet and preview Service, manual promotion, and successful active Service cutover to the green version.

---

## 6. Final Result

The Lab 14 implementation meets the required scope:

- The application is deployed with an Argo Rollouts `Rollout` instead of the Lab 13 `Deployment`.
- Canary strategy is implemented with manual and timed steps.
- Canary promotion and abort behavior were verified.
- Blue-green strategy is implemented with active and preview Services.
- The green version was validated through the preview Service before promotion.
- Manual blue-green promotion successfully switched the active Service to the green version.
- The final Helm release status is `deployed`.
- The final Rollout status is `Healthy`.
- Dashboard screenshots were captured for canary and blue-green rollout states.
