# Lab 11 — Kubernetes Secrets & HashiCorp Vault

This report documents the Lab 11 secret-management work for the `devops-info-service` Helm chart.

**Bonus task was not implemented.**

---

## 0. Environment Bootstrap and Cluster Status

The lab environment was prepared inside a Vagrant-managed Ubuntu 22.04 VM.

### 0.1 Container runtime and local cluster tooling

```bash
groups
docker version
minikube delete --all --purge
docker system prune -af
minikube start --driver=docker --cpus=2 --memory=4096mb
kubectl get nodes
kubectl cluster-info
minikube status
```

```text
vagrant docker
Client: Docker Engine - Community
 Version:           29.4.0
 API version:       1.54
 Go version:        go1.26.1
 Git commit:        9d7ad9f
 Built:             Tue Apr  7 08:35:18 2026
 OS/Arch:           linux/amd64
 Context:           default

Server: Docker Engine - Community
 Engine:
  Version:          29.4.0
  API version:      1.54 (minimum version 1.40)
  Go version:       go1.26.1
  Git commit:       daa0cb7
  Built:            Tue Apr  7 08:35:18 2026
  OS/Arch:          linux/amd64
  Experimental:     false
 containerd:
  Version:          v2.2.2
  GitCommit:        301b2dac98f15c27117da5c8af12118a041a31d9
 runc:
  Version:          1.3.4
  GitCommit:        v1.3.4-0-gd6d73eb8
 docker-init:
  Version:          0.19.0
  GitCommit:        de40ad0

Total reclaimed space: 0B

😄  minikube v1.38.1 on Ubuntu 22.04 (vbox/amd64)
✨  Using the docker driver based on existing profile
👍  Starting "minikube" primary control-plane node in "minikube" cluster
🔥  Creating docker container (CPUs=2, Memory=4096MB) ...
🐳  Preparing Kubernetes v1.35.1 on Docker 29.2.1 ...
🔗  Configuring bridge CNI (Container Networking Interface) ...
🔎  Verifying Kubernetes components...
    ▪ Using image gcr.io/k8s-minikube/storage-provisioner:v5
🌟  Enabled addons: default-storageclass, storage-provisioner
🏄  Done! kubectl is now configured to use "minikube" cluster and "default" namespace by default

NAME       STATUS     ROLES           AGE   VERSION
minikube   NotReady   control-plane   95s   v1.35.1

Kubernetes control plane is running at https://192.168.49.2:8443
CoreDNS is running at https://192.168.49.2:8443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

minikube
type: Control Plane
host: Running
kubelet: Running
apiserver: Running
kubeconfig: Configured
```

### 0.2 Status interpretation
The cluster bootstrap completed successfully and `kubectl` was configured to use the `minikube` context. Immediately after startup, the single control-plane node still reported `NotReady`. This is normal during early convergence. Cluster-dependent validation should be executed only after the node becomes `Ready`.

---

## 1. Kubernetes Secrets

### 1.1 Secret creation with `kubectl`
The first part of the lab uses an imperative Kubernetes Secret created directly with `kubectl`.

```bash
kubectl create namespace devops-lab10 --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic app-credentials \
  -n devops-lab10 \
  --from-literal=username=lab-user \
  --from-literal=password=lab-password

kubectl get secret app-credentials -n devops-lab10 -o yaml
```

```yaml
namespace/devops-lab10 created
secret/app-credentials created
apiVersion: v1
data:
  password: bGFiLXBhc3N3b3Jk
  username: bGFiLXVzZXI=
kind: Secret
metadata:
  creationTimestamp: "2026-04-09T20:01:19Z"
  name: app-credentials
  namespace: devops-lab10
  resourceVersion: "546"
  uid: d23b9236-d99b-4435-9797-2aac34866697
type: Opaque
```

### 1.2 Base64 decoding demonstration
The Secret manifest stores values under the `data` field as base64-encoded strings.

```bash
echo "bGFiLXVzZXI=" | base64 -d
echo
echo "bGFiLXBhc3N3b3Jk" | base64 -d
echo
```

```text
lab-user
lab-password
```

### 1.3 Base64 encoding vs encryption
Base64 is **encoding**, not **encryption**.

- **Encoding** changes representation so binary or special characters can be transported safely.
- **Encryption** protects confidentiality and requires a cryptographic key for decryption.
- A Kubernetes Secret stored only as base64 can be trivially decoded by anyone who can read it.

### 1.4 Security implications
By default, Kubernetes stores Secret objects unencrypted in `etcd` unless encryption at rest is explicitly enabled.

**What etcd encryption means:**
- the Kubernetes API server encrypts selected resources before writing them to `etcd`;
- this protects Secret values from direct plaintext exposure in the backing datastore;
- it is an additional control on top of disk or filesystem protection.

**When to enable it:**
- always in shared clusters;
- always in staging and production;
- whenever `etcd` backups exist outside tightly controlled admin access;
- whenever compliance or internal security policies require protection of credentials at rest.

---

## 2. Helm Secret Integration

### 2.1 Chart structure
The Lab 10 Helm chart was extended with native secret management and a dedicated service account for Vault authentication.

```text
k8s/devops-info-service/
├── Chart.yaml
├── values.yaml
├── values-dev.yaml
├── values-prod.yaml
└── templates/
    ├── _helpers.tpl
    ├── deployment.yaml
    ├── secrets.yaml
    ├── service.yaml
    ├── serviceaccount.yaml
    ├── NOTES.txt
    └── hooks/
        ├── post-install-job.yaml
        └── pre-install-job.yaml
```

### 2.2 Secret values in `values.yaml`
Real credentials must never be committed to Git, so the chart stores placeholder defaults only.

```yaml
secrets:
  enabled: true
  name: ""
  existingSecret: ""
  type: Opaque
  data:
    username: "change-me-username"
    password: "change-me-password"
```

This design supports two safe patterns:
1. create a Secret from chart values for local learning and testing;
2. reference an externally managed Secret through `secrets.existingSecret`.

### 2.3 Secret template implementation
A new template was added at `templates/secrets.yaml`.

```yaml
{{- if and .Values.secrets.enabled (not .Values.secrets.existingSecret) }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "devops-info-service.secretName" . }}
  labels:
    {{- include "devops-info-service.labels" . | nindent 4 }}
type: {{ .Values.secrets.type }}
stringData:
  username: {{ .Values.secrets.data.username | quote }}
  password: {{ .Values.secrets.data.password | quote }}
{{- end }}
```

`stringData` is used for readable plaintext input, while Kubernetes stores the object under the `data` field in base64 form.

### 2.4 Secret consumption in the Deployment
The Deployment reads secret keys through explicit `secretKeyRef` entries.

```yaml
env:
  - name: APP_USERNAME
    valueFrom:
      secretKeyRef:
        name: {{ include "devops-info-service.secretName" . }}
        key: username
  - name: APP_PASSWORD
    valueFrom:
      secretKeyRef:
        name: {{ include "devops-info-service.secretName" . }}
        key: password
```

This keeps secret values out of the Deployment manifest itself.

### 2.5 Service account for Vault authentication
A dedicated service account was added with a Helm helper for stable naming.

Why this matters:
- Vault Kubernetes auth binds access to a service account and namespace;
- a dedicated service account is clearer and safer than using the namespace default account;
- the same identity can be reused across upgrades.

### 2.6 Chart rendering verification
The chart was successfully checked with `helm lint` and rendered with `helm template`.

```bash
helm lint ./k8s/devops-info-service
helm template devops-app ./k8s/devops-info-service \
  -n devops-lab10 \
  -f ./k8s/devops-info-service/values-dev.yaml
```

```text
==> Linting ./k8s/devops-info-service
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed
```

Relevant rendered fragments:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: devops-app-devops-info-service
```

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: devops-app-devops-info-service-secret
...
type: Opaque
stringData:
  username: "change-me-username"
  password: "change-me-password"
```

```yaml
env:
  - name: APP_USERNAME
    valueFrom:
      secretKeyRef:
        name: devops-app-devops-info-service-secret
        key: username
  - name: APP_PASSWORD
    valueFrom:
      secretKeyRef:
        name: devops-app-devops-info-service-secret
        key: password
```

### 2.7 Runtime verification status
The runtime deployment and in-cluster pod verification were prepared, but a successful chart install output was not captured in the submitted command transcript because the project directory was not yet copied into the Vagrant VM at the time of the first Helm deployment attempt.

Planned verification commands:

```bash
helm upgrade --install devops-app ./k8s/devops-info-service \
  -n devops-lab10 \
  --create-namespace \
  -f ./k8s/devops-info-service/values-dev.yaml \
  --set secrets.data.username=lab-user \
  --set secrets.data.password=lab-password

kubectl get secret -n devops-lab10
kubectl get pods -n devops-lab10
kubectl exec deploy/devops-app-devops-info-service -n devops-lab10 -c devops-info-service -- printenv | grep '^APP_'
kubectl describe pod -n devops-lab10 \
  $(kubectl get pod -n devops-lab10 -l app.kubernetes.io/instance=devops-app -o jsonpath='{.items[0].metadata.name}')
```

Expected verification result:
- `APP_USERNAME` and `APP_PASSWORD` exist inside the container;
- `kubectl describe pod` references the secret keys but does not print actual secret values.

---

## 3. Resource Management

### 3.1 Configured requests and limits
The chart defines explicit CPU and memory requests/limits.

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 250m
    memory: 256Mi
```

For development overrides, `values-dev.yaml` uses smaller lab-friendly values:

```yaml
resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 100m
    memory: 128Mi
```

### 3.2 Requests vs limits
- **Requests** reserve the minimum resources the scheduler uses for placement.
- **Limits** define the upper bound a container may consume.
- Proper values improve scheduling stability and reduce noisy-neighbor effects.

### 3.3 Why these values were chosen
These values are intentionally small and lab-friendly:
- the Flask service is lightweight;
- requests are high enough to avoid startup starvation;
- limits leave controlled headroom for bursts without overcommitting too aggressively.

For production usage, these values should be refined with metrics from real traffic and load testing.

---

## 4. HashiCorp Vault Integration

### 4.1 Vault installation with Helm
Vault is designed to be installed with the official HashiCorp Helm chart in dev mode for learning purposes.

```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

helm install vault hashicorp/vault \
  -n vault \
  --create-namespace \
  --set "server.dev.enabled=true" \
  --set "injector.enabled=true"

kubectl get pods -n vault
```

### 4.2 Enable KV v2 and create an application secret
A KV v2 secrets engine should be enabled at the `secret/` path and populated with application credentials.

```bash
kubectl exec -n vault vault-0 -- sh -c 'vault secrets enable -path=secret kv-v2'
kubectl exec -n vault vault-0 -- sh -c 'vault kv put secret/devops-info-service/config username="vault-user" password="vault-password"'
kubectl exec -n vault vault-0 -- sh -c 'vault kv get secret/devops-info-service/config'
```

### 4.3 Enable Kubernetes authentication
Vault should be configured to trust Kubernetes service account tokens.

```bash
kubectl exec -n vault vault-0 -- sh -c 'vault auth enable kubernetes'
kubectl exec -n vault vault-0 -- sh -c 'vault write auth/kubernetes/config kubernetes_host="https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT"'
```

### 4.4 Policy and role configuration
A minimal read-only policy for this chart is:

```hcl
path "secret/data/devops-info-service/config" {
  capabilities = ["read"]
}
```

Role binding command:

```bash
kubectl exec -n vault vault-0 -- sh -c 'vault write auth/kubernetes/role/devops-info-service-role \
  bound_service_account_names="devops-app-devops-info-service" \
  bound_service_account_namespaces="devops-lab10" \
  policies="devops-info-service" \
  ttl="1h"'
```

### 4.5 Vault Agent Injector annotations in the Deployment
The Helm chart already supports conditional Vault annotations on the pod template.

```yaml
annotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: "devops-info-service-role"
  vault.hashicorp.com/auth-path: "auth/kubernetes"
  vault.hashicorp.com/agent-inject-secret-app-config: "secret/data/devops-info-service/config"
  vault.hashicorp.com/secret-volume-path-app-config: "/vault/secrets"
  vault.hashicorp.com/agent-inject-file-app-config: "app-config.txt"
```

These annotations are rendered only when `vault.enabled=true`.

### 4.6 Deploy the application with Vault injection enabled
Example command:

```bash
helm upgrade --install devops-app ./k8s/devops-info-service \
  -n devops-lab10 \
  --create-namespace \
  -f ./k8s/devops-info-service/values-dev.yaml \
  --set secrets.data.username=lab-user \
  --set secrets.data.password=lab-password \
  --set vault.enabled=true \
  --set vault.role=devops-info-service-role \
  --set vault.service=http://vault.vault.svc:8200
```

### 4.7 Proof of secret injection
The expected injected file path is `/vault/secrets/app-config.txt`.

Verification commands:

```bash
kubectl get pods -n devops-lab10
kubectl exec deploy/devops-app-devops-info-service -n devops-lab10 -c devops-info-service -- ls -la /vault/secrets
kubectl exec deploy/devops-app-devops-info-service -n devops-lab10 -c devops-info-service -- cat /vault/secrets/app-config.txt
```

Expected verification result:
- the pod shows the injected agent containers after mutation;
- `/vault/secrets` exists inside the application pod;
- `app-config.txt` is present at the configured path.

### 4.8 Sidecar injection pattern explanation
Vault Agent Injector uses a mutating admission webhook.

High-level flow:
1. the Deployment creates a Pod with Vault annotations;
2. the webhook intercepts the Pod definition before scheduling completes;
3. Vault Agent containers and an in-memory secret volume are injected;
4. the agent authenticates to Vault using the pod service account token;
5. the agent reads the authorized secret path and renders the result as a file inside the pod.

This pattern keeps the main application container Vault-unaware while still giving it access to secret material.

---

## 5. Security Analysis

### 5.1 Kubernetes Secrets vs Vault

| Aspect | Kubernetes Secret | HashiCorp Vault |
|---|---|---|
| Primary scope | Native cluster object | External centralized secret platform |
| Storage location | etcd | Vault storage backend |
| Default protection | base64 only | authenticated access with policies |
| Rotation support | manual or custom automation | stronger operational patterns |
| Access control | Kubernetes RBAC | Vault policies + auth methods |
| Best fit | simple apps, local labs, bootstrap cases | production workloads, shared platforms, stronger governance |

### 5.2 When to use each approach
**Use Kubernetes Secrets when:**
- the application is simple;
- the cluster is small and centrally administered;
- secrets are few and rotation requirements are minimal;
- native Kubernetes integration is enough.

**Use Vault when:**
- multiple applications or teams need controlled access;
- auditability and centralized policy enforcement matter;
- secret rotation is important;
- you want to reduce secret sprawl across Git repositories and clusters.

### 5.3 Production recommendations
1. Enable encryption at rest for Secrets in etcd.
2. Restrict Secret access with RBAC and namespace boundaries.
3. Never commit real credentials to Git repositories or default `values.yaml` files.
4. Prefer external secret delivery for production, such as Vault.
5. Run Vault in a non-dev-mode configuration with persistent storage, TLS, backups, and operational monitoring.
6. Prefer short-lived credentials and rotation processes wherever possible.
7. Treat environment variables as lower-trust secret exposure than file-based or direct retrieval patterns because they are easier to leak through debugging and process inspection.

---

## 6. Conclusion
The required Lab 11 implementation is prepared in the chart and partially verified with direct command evidence.

Completed with command evidence:
- Secret created via `kubectl`;
- Secret viewed in YAML form;
- Secret values decoded from base64;
- Helm chart checked with `helm lint`;
- Helm chart rendered successfully with the new Secret and ServiceAccount resources.

Implemented in chart and documented, but still awaiting final in-cluster runtime proof in the command transcript:
- full Helm deployment verification inside the pod;
- Vault installation and runtime validation;
- Vault-authenticated secret injection into the application pod.

The chart and documentation are aligned with the required design for the mandatory part of the lab, and the remaining runtime verification can be completed by running the prepared commands inside the Vagrant VM after the project directory is copied there.
