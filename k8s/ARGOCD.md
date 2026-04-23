# Lab 13 — GitOps with ArgoCD

This report documents the ArgoCD-based GitOps deployment for the Helm chart located at `k8s/devops-info-service`.

Repository used:
- `repoURL`: `https://github.com/dorley174/DevOps-Core-Course.git`
- `targetRevision`: `lab13`
- `path`: `k8s/devops-info-service`

---

## 1. ArgoCD Setup

### 1.1 Installation verification
ArgoCD was installed into a dedicated `argocd` namespace by using the official Helm chart.

Commands used:

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
kubectl create namespace argocd
helm install argocd argo/argo-cd -n argocd
kubectl get pods -n argocd
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=180s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-application-controller -n argocd --timeout=180s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-repo-server -n argocd --timeout=180s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-dex-server -n argocd --timeout=180s
kubectl get pods -n argocd
```

**Installation evidence:**

```text
"argo" has been added to your repositories
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "hashicorp" chart repository
...Successfully got an update from the "argo" chart repository
...Successfully got an update from the "grafana" chart repository
...Successfully got an update from the "prometheus-community" chart repository
Update Complete. ⎈Happy Helming!⎈
namespace/argocd created
NAME: argocd
LAST DEPLOYED: Thu Apr 23 21:39:20 2026
NAMESPACE: argocd
STATUS: deployed
REVISION: 1
DESCRIPTION: Install complete

pod/argocd-server-7f857f54f-kzdq5 condition met
pod/argocd-application-controller-0 condition met
pod/argocd-repo-server-7b8447858f-f4rg5 condition met
pod/argocd-dex-server-8f5687997-hdvfn condition met

NAME                                                READY   STATUS    RESTARTS      AGE
argocd-application-controller-0                     1/1     Running   0             65s
argocd-applicationset-controller-559566846f-lq79x   1/1     Running   0             67s
argocd-dex-server-8f5687997-hdvfn                   1/1     Running   0             67s
argocd-notifications-controller-56c7d65875-vpxhl    1/1     Running   0             67s
argocd-redis-fcd76bcfb-8hptk                        1/1     Running   0             67s
argocd-repo-server-7b8447858f-f4rg5                 1/1     Running   0             67s
argocd-server-7f857f54f-kzdq5                       1/1     Running   1 (44s ago)   67s
```

### 1.2 UI access method
The ArgoCD API server was accessed through `kubectl port-forward`.

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Later, when port `8080` was already occupied, an additional local port was used:

```bash
kubectl port-forward svc/argocd-server -n argocd 8084:443
```

The initial admin password was retrieved with:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

The web UI was opened at:

```text
https://127.0.0.1:8080
https://127.0.0.1:8084
```

Login credentials:
- Username: `admin`
- Password: value returned by the secret lookup command

**UI access evidence:**

```text
Password was successfully retrieved from the initial admin secret.
The ArgoCD UI was opened locally through kubectl port-forward and the login was completed successfully.
When port 8080 was busy, port 8084 was used successfully instead.
```

**Screenshot evidence:**
- [ArgoCD applications UI](./evidence/proof1.png)

### 1.3 CLI configuration
The `argocd` CLI was installed in WSL and authenticated against the port-forwarded ArgoCD server.

Actual working installation method:

```bash
curl -fsSL -o /tmp/argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/download/v3.3.8/argocd-linux-amd64
sudo install -m 0755 /tmp/argocd-linux-amd64 /usr/local/bin/argocd
argocd version --client
export ARGOCD_PASSWORD="REDACTED"
argocd login localhost:8080 --username admin --password "$ARGOCD_PASSWORD" --insecure --grpc-web
argocd account get-user-info
```

Later, the CLI was also used via the alternative forwarded port:

```bash
argocd login localhost:8084 --username admin --password "$ARGOCD_PASSWORD" --insecure --grpc-web
```

**CLI evidence:**

```text
'admin:login' logged in successfully
Context 'localhost:8080' updated

'admin:login' logged in successfully
Context 'localhost:8084' updated
```

---

## 2. Application Configuration

### 2.1 Created manifests
The following ArgoCD manifests were added:

```text
k8s/argocd/application.yaml
k8s/argocd/application-dev.yaml
k8s/argocd/application-prod.yaml
```

### 2.2 Source configuration
All Application resources point to the same Git repository and the same Helm chart path:

- `repoURL`: `https://github.com/dorley174/DevOps-Core-Course.git`
- `targetRevision`: `lab13`
- `path`: `k8s/devops-info-service`

This makes Git the source of truth for the Kubernetes desired state.

Verification command:

```bash
grep -R "repoURL\|targetRevision\|path:" -n k8s/argocd
```

Verification result:

```text
k8s/argocd/application-dev.yaml:11:    repoURL: https://github.com/dorley174/DevOps-Core-Course.git
k8s/argocd/application-dev.yaml:12:    targetRevision: lab13
k8s/argocd/application-dev.yaml:13:    path: k8s/devops-info-service
k8s/argocd/application-prod.yaml:11:    repoURL: https://github.com/dorley174/DevOps-Core-Course.git
k8s/argocd/application-prod.yaml:12:    targetRevision: lab13
k8s/argocd/application-prod.yaml:13:    path: k8s/devops-info-service
k8s/argocd/application.yaml:11:    repoURL: https://github.com/dorley174/DevOps-Core-Course.git
k8s/argocd/application.yaml:12:    targetRevision: lab13
k8s/argocd/application.yaml:13:    path: k8s/devops-info-service
```

### 2.3 Destination configuration
The destination cluster is the in-cluster Kubernetes API server:

- `server`: `https://kubernetes.default.svc`

Namespaces used:
- `devops-lab13` for the initial single-application deployment
- `dev` for the development environment
- `prod` for the production environment

### 2.4 Values file selection
The applications use different Helm values files:

| Application | Values file | Namespace | Sync mode |
|---|---|---|---|
| `devops-info-service` | `values.yaml` | `devops-lab13` | Manual |
| `devops-info-service-dev` | `values-dev.yaml` | `dev` | Automatic |
| `devops-info-service-prod` | `values-prod.yaml` | `prod` | Manual |

### 2.5 Initial manual deployment
The initial Application was created and synced manually.

```bash
kubectl apply -f k8s/argocd/application.yaml
argocd app get devops-info-service
argocd app sync devops-info-service
argocd app wait devops-info-service --health --sync
kubectl get all -n devops-lab13
```

**Application deployment evidence:**

```text
application.argoproj.io/devops-info-service created

Name:               argocd/devops-info-service
Project:            default
Server:             https://kubernetes.default.svc
Namespace:          devops-lab13
Source:
- Repo:             https://github.com/dorley174/DevOps-Core-Course.git
  Target:           lab13
  Path:             k8s/devops-info-service
  Helm Values:      values.yaml
Sync Policy:        Manual

After resolving the initial repo-server and NodePort issues, the application resources were created successfully.

NAME                                         READY   STATUS      RESTARTS   AGE
pod/devops-info-service-5c89d67f5b-5xd2l     1/1     Running     0          3m35s
pod/devops-info-service-5c89d67f5b-f6764     1/1     Running     0          3m35s
pod/devops-info-service-5c89d67f5b-hj57r     1/1     Running     0          3m35s
pod/devops-info-service-pre-install-7g869    0/1     Completed   0          46s

NAME                          TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
service/devops-info-service   NodePort   10.110.84.248   <none>        80:30083/TCP   32s

NAME                                  READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/devops-info-service   3/3     3            3           3m35s

NAME                                         STATUS     COMPLETIONS   DURATION   AGE
job.batch/devops-info-service-pre-install    Complete   1/1           9s         46s
job.batch/devops-info-service-post-install   Failed     0/1           26s        26s
```

The application itself became reachable and healthy. The remaining failed `post-install` hook did not prevent the application from serving traffic.

Validation through service port-forward:

```bash
kubectl port-forward -n devops-lab13 svc/devops-info-service 8081:80
curl http://127.0.0.1:8081/
curl http://127.0.0.1:8081/health
curl http://127.0.0.1:8081/visits
```

Validation result:

```text
{"service":{"message":"Lab 13 GitOps deployment","version":"lab13-v1"}}
{"status":"healthy"}
{"visits":1}
```

### 2.6 GitOps workflow verification
To verify GitOps behavior, changes were made in the tracked Git repository and then pushed to the `lab13` branch.

Commands used during the workflow included:

```bash
git checkout lab12
git pull origin lab12
git checkout -b lab13
git add ...
git commit -m "lab13: add argocd configuration"
git push -u origin lab13
```

Additional chart changes were committed and pushed later, including:
- unique NodePort values for the initial, dev, and prod deployments
- an updated `values-dev.yaml` NodePort to avoid a clash with an older lab service
- `selfHeal: true` in `application-dev.yaml`

**GitOps workflow evidence:**

```text
ArgoCD detected and used the tracked branch:
- targetRevision: lab13

Git-driven changes were observed during the deployment process:
- initial application used values.yaml
- development application used values-dev.yaml
- production application used values-prod.yaml
- changes pushed to Git were applied through ArgoCD synchronization
```

---

## 3. Multi-Environment Deployment

### 3.1 Namespace separation
Separate namespaces were used for environment isolation:

```bash
kubectl create namespace dev
kubectl create namespace prod
kubectl get ns dev prod
```

**Namespace evidence:**

```text
Error from server (AlreadyExists): namespaces "dev" already exists
Error from server (AlreadyExists): namespaces "prod" already exists
```

The namespaces were already present when re-running the commands, which confirmed that they had been created successfully earlier in the process.

### 3.2 Dev vs Prod configuration differences
The development and production environments use different Helm values.

**Development (`values-dev.yaml`):**
- `replicaCount: 1`
- `service.type: NodePort`
- lighter CPU and memory requests/limits
- `config.environment: dev`
- `config.logLevel: DEBUG`
- auto-sync enabled in ArgoCD

**Production (`values-prod.yaml`):**
- `replicaCount: 3`
- `service.type: LoadBalancer`
- higher CPU and memory requests/limits
- `config.environment: prod`
- `config.logLevel: INFO`
- manual sync in ArgoCD

### 3.3 Sync policy differences and rationale
The development application uses:

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
```

This was selected because development should react quickly to Git changes and configuration drift.

The production application intentionally remains manual:
- deployment timing stays controlled
- changes can be reviewed before rollout
- release approval and rollback planning stay explicit

### 3.4 Multi-environment deployment commands
The initial single-application manifest was removed before the multi-environment deployment to avoid duplicate releases using the same chart.

```bash
kubectl delete -f k8s/argocd/application.yaml
kubectl create namespace dev
kubectl create namespace prod
kubectl apply -f k8s/argocd/application-dev.yaml
kubectl apply -f k8s/argocd/application-prod.yaml
argocd app get devops-info-service-dev
argocd app get devops-info-service-prod
argocd app sync devops-info-service-prod
argocd app wait devops-info-service-dev --health --sync
argocd app wait devops-info-service-prod --health --sync
kubectl get pods -n dev
kubectl get pods -n prod
```

**Multi-environment evidence:**

```text
application.argoproj.io "devops-info-service" deleted from argocd namespace
application.argoproj.io/devops-info-service-dev created
application.argoproj.io/devops-info-service-prod created

NAME                             CLUSTER                         NAMESPACE  PROJECT  STATUS     HEALTH       SYNCPOLICY
argocd/devops-info-service-dev   https://kubernetes.default.svc  dev        default  OutOfSync  Missing      Auto-Prune
argocd/devops-info-service-prod  https://kubernetes.default.svc  prod       default  Synced     Progressing  Manual

Later, after resolving service exposure issues, both environments became reachable:
- dev application returned "Lab 13 GitOps development deployment"
- prod application returned "Lab 13 GitOps production deployment"
```

Validation results:

Development environment:

```bash
kubectl port-forward -n dev svc/devops-info-service-dev 8082:80
curl http://127.0.0.1:8082/
curl http://127.0.0.1:8082/health
curl http://127.0.0.1:8082/visits
```

```text
{"service":{"message":"Lab 13 GitOps development deployment","version":"lab13-dev"}}
{"status":"healthy"}
{"visits":1}
```

Production environment:

```bash
kubectl port-forward -n prod svc/devops-info-service-prod 8083:80
curl http://127.0.0.1:8083/
curl http://127.0.0.1:8083/health
curl http://127.0.0.1:8083/visits
```

```text
{"service":{"message":"Lab 13 GitOps production deployment","version":"lab13-prod"}}
{"status":"healthy"}
{"visits":1}
```

For the production `LoadBalancer` service, `minikube tunnel` was used so the external IP could be assigned:

```bash
minikube tunnel
kubectl get svc -n prod
argocd app get devops-info-service-prod
```

Tunnel result:

```text
NAME                       TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
devops-info-service-prod   LoadBalancer   10.106.106.187   127.0.0.1     80:31973/TCP   35m

Sync Status:   Synced to lab13
Health Status: Healthy
```

**Screenshot evidence:**
- [Applications overview](./evidence/proof1.png)
- [Development application details](./evidence/argocd-ui-dev-details.png)
- [Production application details](./evidence/argocd-ui-prod-details.png)
- [Final work stage](./evidence/argocd-ui-synced.png)

---

## 4. Self-Healing Evidence

### 4.1 Manual scale test in dev
The development application has `selfHeal: true`, so a manual scale drift should be reverted automatically.

Commands used:

```bash
date -u
kubectl get deploy -n dev
kubectl scale deployment devops-info-service-dev -n dev --replicas=5
kubectl get deploy devops-info-service-dev -n dev
argocd app get devops-info-service-dev
kubectl get deploy devops-info-service-dev -n dev -w
```

**Observed behavior:**
- after manual scaling, the deployment changed from `1/1` to `5/5`
- ArgoCD marked the application `OutOfSync`
- the application remained `Healthy`

**Manual scale evidence:**

```text
NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
devops-info-service-dev   1/1     1            1           37m

deployment.apps/devops-info-service-dev scaled

NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
devops-info-service-dev   1/5     1            1           37m
devops-info-service-dev   1/5     5            1           37m
devops-info-service-dev   2/5     5            2           38m
devops-info-service-dev   3/5     5            3           38m
devops-info-service-dev   4/5     5            4           38m
devops-info-service-dev   5/5     5            5           38m

Name:               argocd/devops-info-service-dev
Sync Policy:        Automated (Prune)
Sync Status:        OutOfSync from lab13
Health Status:      Healthy

CONDITION  MESSAGE
SyncError  Failed last sync attempt ... one or more synchronization tasks completed unsuccessfully

GROUP  KIND        NAMESPACE  NAME                                  STATUS     HEALTH   HOOK      MESSAGE
apps   Deployment  dev        devops-info-service-dev               OutOfSync  Healthy
batch  Job         dev        devops-info-service-dev-post-install  Failed              PostSync  Job has reached the specified backoff limit
```

**Note:** in this environment the application did not automatically converge back to the Git-defined replica count because the failed `post-install` hook kept the application in a failed sync state. Drift detection itself was demonstrated successfully because the application was marked `OutOfSync` immediately after the manual scale operation.

### 4.2 Pod deletion test
Deleting a Pod demonstrates Kubernetes healing, not ArgoCD healing.

Commands used:

```bash
kubectl get pods -n dev
kubectl delete pod -n dev -l app.kubernetes.io/instance=devops-info-service-dev
kubectl get pods -n dev -w
```

**Explanation:**
- Kubernetes Deployment and ReplicaSet controllers recreate missing Pods to maintain the desired replica count.
- ArgoCD is not required for simple Pod recreation.

**Pod deletion evidence:**

```text
To be captured locally during the final evidence pass.
```

### 4.3 Configuration drift test
A live resource was edited manually to create drift.

Commands used:

```bash
kubectl label deployment devops-info-service-dev -n dev drift-test=true --overwrite
argocd app diff devops-info-service-dev
kubectl get deployment devops-info-service-dev -n dev --show-labels
kubectl get deployment devops-info-service-dev -n dev -w
```

**Expected behavior:**
- ArgoCD shows a diff between Git and the cluster
- because `selfHeal` is enabled, ArgoCD removes the manually added label and restores the declared state

**Configuration drift evidence:**

```text
To be captured locally during the final evidence pass.
```

### 4.4 When ArgoCD syncs vs when Kubernetes heals
**Kubernetes self-healing:**
- recreates Pods when they are deleted
- keeps the number of replicas defined in the live Deployment spec
- does not know or care about Git

**ArgoCD self-healing:**
- compares the live cluster state with the state declared in Git
- marks the application `OutOfSync` when the live configuration drifts
- automatically restores the Git-defined state only when auto-sync with `selfHeal` is enabled

### 4.5 What triggers ArgoCD sync
ArgoCD can synchronize after:
- a manual sync from the UI or CLI
- a detected Git change for an automated application
- live-state drift when `selfHeal: true` is enabled

### 4.6 Sync interval
ArgoCD checks tracked repositories on a reconciliation timer and can also refresh on live resource changes. The default reconciliation timeout is `120s` plus up to `60s` jitter, so the effective maximum polling interval is about `3 minutes`.

---
