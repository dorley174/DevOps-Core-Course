# Lab 13 — GitOps with ArgoCD

This report documents the ArgoCD-based GitOps deployment for the Helm chart located at `k8s/devops-info-service`.

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
```

**Installation evidence:**

```text
<COMMAND_OUTPUT_PLACEHOLDER>
```

### 1.2 UI access method
The ArgoCD API server was accessed through `kubectl port-forward`.

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

The initial admin password was retrieved with:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

The web UI was opened at:

```text
https://127.0.0.1:8080
```

Login credentials:
- Username: `admin`
- Password: value returned by the secret lookup command

**UI access evidence:**

```text
<COMMAND_OUTPUT_PLACEHOLDER>
```

### 1.3 CLI configuration
The `argocd` CLI was installed in WSL and authenticated against the port-forwarded ArgoCD server.

```bash
VERSION=$(curl -fsSL https://api.github.com/repos/argoproj/argo-cd/releases/latest | jq -r .tag_name)
curl -fsSL -o /tmp/argocd-linux-amd64 "https://github.com/argoproj/argo-cd/releases/download/${VERSION}/argocd-linux-amd64"
sudo install -m 0755 /tmp/argocd-linux-amd64 /usr/local/bin/argocd
argocd version --client
export ARGOCD_PASSWORD="REPLACE_WITH_REAL_PASSWORD"
argocd login localhost:8080 --username admin --password "$ARGOCD_PASSWORD" --insecure
argocd account get-user-info
```

**CLI evidence:**

```text
<COMMAND_OUTPUT_PLACEHOLDER>
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

- `repoURL`: `https://github.com/REPLACE_WITH_USERNAME/REPLACE_WITH_REPOSITORY.git`
- `targetRevision`: `REPLACE_WITH_BRANCH`
- `path`: `k8s/devops-info-service`

This makes Git the source of truth for the Kubernetes desired state.

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
<COMMAND_OUTPUT_PLACEHOLDER>
```

### 2.6 GitOps workflow verification
To verify drift detection from Git:

1. A change was made in the Helm chart, for example `replicaCount` or `env.appMessage`.
2. The change was committed and pushed to the tracked branch.
3. ArgoCD detected the repository change.
4. The application became `OutOfSync` until synchronized.
5. After sync, the cluster matched Git again.

Example commands:

```bash
git checkout -b lab13
sed -i 's/replicaCount: 1/replicaCount: 2/' k8s/devops-info-service/values-dev.yaml
git add k8s/devops-info-service/values-dev.yaml k8s/argocd/*.yaml k8s/ARGOCD.md
git commit -m "lab13: configure argocd applications"
git push -u origin lab13
argocd app get devops-info-service-dev
argocd app history devops-info-service-dev
```

**GitOps workflow evidence:**

```text
<COMMAND_OUTPUT_PLACEHOLDER>
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
<COMMAND_OUTPUT_PLACEHOLDER>
```

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
<COMMAND_OUTPUT_PLACEHOLDER>
```

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

**Expected behavior:**
- immediately after manual scaling, the Deployment no longer matches Git
- ArgoCD detects drift and restores the replica count defined in `values-dev.yaml`
- the deployment returns to the Git-defined replica count automatically

**Manual scale evidence:**

```text
<COMMAND_OUTPUT_PLACEHOLDER>
```

### 4.2 Pod deletion test
Deleting a Pod demonstrates Kubernetes healing, not ArgoCD healing.

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
<COMMAND_OUTPUT_PLACEHOLDER>
```

### 4.3 Configuration drift test
A live resource was edited manually to create drift.

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
<COMMAND_OUTPUT_PLACEHOLDER>
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

## 5. Screenshots

The following screenshots should be added before submission:

1. ArgoCD main UI showing both applications (`devops-info-service-dev` and `devops-info-service-prod`)
2. Application details page for `devops-info-service-dev`
3. Application details page for `devops-info-service-prod`
4. OutOfSync or diff view during a drift test
5. Healthy/Synced state after reconciliation

Recommended file names:

```text
k8s/evidence/argocd-ui-apps.png
k8s/evidence/argocd-ui-dev-details.png
k8s/evidence/argocd-ui-prod-details.png
k8s/evidence/argocd-ui-diff.png
k8s/evidence/argocd-ui-synced.png
```

---

## 6. Notes for Local Workflow

### 6.1 Docker image update for Lab 13
A separate image tag was prepared for this lab:

- image repository: `dorley174/devops-info-service`
- image tag: `lab13`

The Helm chart values were updated accordingly so ArgoCD deploys the Lab 13 image instead of the older `latest` tag.

### 6.2 Recommended order of work
1. Stop old local Docker containers from previous labs.
2. Build the new `lab13` image.
3. Ensure the image is available to the Kubernetes cluster.
4. Commit and push the Git changes.
5. Install ArgoCD.
6. Apply the Application manifests.
7. Perform the sync and drift tests.
8. Save screenshots and replace all output placeholders.

---

## 7. Submission Checklist

- `k8s/argocd/application.yaml` created
- `k8s/argocd/application-dev.yaml` created
- `k8s/argocd/application-prod.yaml` created
- `k8s/ARGOCD.md` completed in English
- screenshots saved
- all `<COMMAND_OUTPUT_PLACEHOLDER>` blocks replaced with real command results before submission
- bonus/ApplicationSet not implemented

