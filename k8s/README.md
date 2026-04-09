# Lab 09 — Kubernetes Fundamentals

This report documents the Kubernetes deployment of the Flask-based `devops-info-service` application.

---

## 1. Architecture Overview

### 1.1 Selected local Kubernetes tool
I selected **minikube** with the **Docker driver** on **Windows + VS Code + WSL + Docker Desktop**.

**Why this option fits my environment:**
1. It runs completely locally and does not require a cloud provider.
2. It works well with my Windows + VS Code + WSL workflow.
3. Docker Desktop provides the container runtime, and minikube uses the Docker driver directly from WSL.
4. It is practical in my region because the lab can be completed locally after the required images are downloaded.

### 1.2 Deployment architecture
The main application is deployed with a Kubernetes **Deployment** and exposed with a **NodePort Service**.

**Main application path:**
- `Deployment/devops-info-service`
- `Service/devops-info-service`
- `3 replicas` by default
- `NodePort 30080`
- container port `5000`

**Bonus manifests prepared in the repository:**
- `Deployment/devops-info-service-app2`
- `Service/devops-info-service-app2`
- `Ingress/devops-course-ingress`
- host `local.example.com`
- routes `/app1` and `/app2`

### 1.3 Networking flow
#### Base task
1. A client sends a request to the local cluster.
2. The NodePort Service exposes the application on port `30080`.
3. The Service selects Pods by label `app.kubernetes.io/name=devops-info-service`.
4. Traffic is forwarded to container port `5000`.

#### Local verification flow actually used
In my WSL + Docker Desktop setup, direct NodePort access through `minikube ip` was not reliable. I verified the application with:

```bash
kubectl port-forward -n devops-lab09 service/devops-info-service 8080:80
```

This mapped local port `8080` to Service port `80` and allowed stable validation with `curl`.

### 1.4 Resource allocation strategy
Each container defines conservative lab-friendly resources:
- **Requests:** `100m CPU`, `128Mi memory`
- **Limits:** `250m CPU`, `256Mi memory`

These values are appropriate for a lightweight Flask service on a local minikube cluster running through WSL and Docker Desktop.

---

## 2. Manifest Files

### 2.1 `k8s/namespace.yml`
Creates a dedicated namespace `devops-lab09` for logical isolation of all lab resources.

### 2.2 `k8s/deployment.yml`
Creates the primary Deployment.

**Key implementation choices:**
1. `replicas: 3` satisfies the requirement for at least three Pod replicas.
2. `RollingUpdate` uses `maxSurge: 1` and `maxUnavailable: 0` to avoid downtime during updates.
3. `readinessProbe` checks `/ready`.
4. `livenessProbe` checks `/health`.
5. Resource requests and limits are defined.
6. Runtime hardening is enabled with `runAsNonRoot`, dropped capabilities, disabled privilege escalation, and `RuntimeDefault` seccomp.

### 2.3 `k8s/service.yml`
Creates a `NodePort` Service.

**Key implementation choices:**
1. Service port `80` is user-friendly.
2. `targetPort: http` forwards traffic to container port `5000`.
3. `nodePort: 30080` is fixed explicitly to simplify local testing.

### 2.4 `k8s/deployment-app2.yml`
Creates a second Deployment for the bonus part, using the same image with different environment values.

### 2.5 `k8s/service-app2.yml`
Creates a second NodePort Service on `30081` for the bonus application.

### 2.6 `k8s/ingress.yml`
Defines nginx Ingress with path-based routing and TLS.

### 2.7 Helper scripts
- `k8s/deploy.sh` — deploys the namespace, main Deployment, and Service.
- `k8s/deploy-bonus.sh` — deploys the bonus resources.
- `k8s/collect-evidence.sh` — saves Kubernetes evidence into `k8s/evidence/`.

### 2.8 Docker image security fix
The initial deployment failed because Kubernetes could not validate a named non-root user with `runAsNonRoot: true`.

I fixed this by updating `app_python/Dockerfile` to use a **numeric UID/GID**:

```dockerfile
RUN addgroup --system --gid 10001 app \
    && adduser --system --uid 10001 --ingroup app --no-create-home app

USER 10001:10001
```

---

## 3. Deployment Evidence

### 3.1 Cluster setup evidence

```text
$ kubectl cluster-info
Kubernetes control plane is running at https://127.0.0.1:60412
CoreDNS is running at https://127.0.0.1:60412/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

```text
$ kubectl get nodes -o wide
NAME       STATUS   ROLES           AGE   VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE                         KERNEL-VERSION                       CONTAINER-RUNTIME
minikube   Ready    control-plane   14m   v1.35.1   192.168.49.2   <none>        Debian GNU/Linux 12 (bookworm)   5.15.153.1-microsoft-standard-WSL2   docker://29.2.1
```

### 3.2 Deployment evidence

```text
$ kubectl get all -n devops-lab09 -o wide
NAME                                       READY   STATUS    RESTARTS   AGE     IP           NODE       NOMINATED NODE   READINESS GATES
pod/devops-info-service-7b48589b6b-2cf77   1/1     Running   0          5m26s   10.244.0.6   minikube   <none>           <none>
pod/devops-info-service-7b48589b6b-52j4f   1/1     Running   0          5m9s    10.244.0.8   minikube   <none>           <none>
pod/devops-info-service-7b48589b6b-wrvvj   1/1     Running   0          5m19s   10.244.0.7   minikube   <none>           <none>

NAME                          TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE   SELECTOR
service/devops-info-service   NodePort   10.100.203.165   <none>        80:30080/TCP   13m   app.kubernetes.io/name=devops-info-service

NAME                                  READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS            IMAGES                                 SELECTOR
deployment.apps/devops-info-service   3/3     3            3           13m   devops-info-service   dorley174/devops-info-service:latest   app.kubernetes.io/name=devops-info-service
```

```text
$ kubectl get pods,svc -n devops-lab09 -o wide
NAME                                       READY   STATUS    RESTARTS   AGE     IP           NODE       NOMINATED NODE   READINESS GATES
pod/devops-info-service-7b48589b6b-2cf77   1/1     Running   0          5m27s   10.244.0.6   minikube   <none>           <none>
pod/devops-info-service-7b48589b6b-52j4f   1/1     Running   0          5m10s   10.244.0.8   minikube   <none>           <none>
pod/devops-info-service-7b48589b6b-wrvvj   1/1     Running   0          5m20s   10.244.0.7   minikube   <none>           <none>

NAME                          TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE   SELECTOR
service/devops-info-service   NodePort   10.100.203.165   <none>        80:30080/TCP   13m   app.kubernetes.io/name=devops-info-service
```

```text
$ kubectl describe deployment devops-info-service -n devops-lab09
Name:                   devops-info-service
Namespace:              devops-lab09
Replicas:               3 desired | 3 updated | 3 total | 3 available | 0 unavailable
StrategyType:           RollingUpdate
RollingUpdateStrategy:  0 max unavailable, 1 max surge
Image:                  dorley174/devops-info-service:latest
Liveness:               http-get http://:http/health delay=15s timeout=2s period=10s #success=1 #failure=3
Readiness:              http-get http://:http/ready delay=5s timeout=2s period=5s #success=1 #failure=3
Environment:
  PORT:             5000
  DEBUG:            False
  APP_VARIANT:      app1
  APP_MESSAGE:      Lab 09 primary deployment
  SERVICE_VERSION:  lab09-v1
```

### 3.3 Application verification
I verified the running Service with `kubectl port-forward`.

```bash
kubectl port-forward -n devops-lab09 service/devops-info-service 8080:80
```

```text
$ curl http://127.0.0.1:8080/health
{"status":"healthy","timestamp":"2026-03-26T19:47:24.216Z","uptime_seconds":264,"variant":"app1"}
```

```text
$ curl http://127.0.0.1:8080/ready
{"message":"Lab 09 primary deployment","status":"ready","timestamp":"2026-03-26T19:47:24.232Z","uptime_seconds":264,"variant":"app1"}
```

```json
$ curl http://127.0.0.1:8080/ | python3 -m json.tool
{
    "service": {
        "description": "DevOps course info service",
        "framework": "Flask",
        "message": "Lab 09 primary deployment",
        "name": "devops-info-service",
        "variant": "app1",
        "version": "lab09-v1"
    }
}
```

### 3.4 Evidence collection helper

```text
$ ./k8s/collect-evidence.sh
Evidence saved to k8s/evidence
```

The raw evidence files are included in `k8s/evidence/`.

---

## 4. Operations Performed

### 4.1 Deploy the application
I deployed the namespace, Deployment, and Service declaratively with `kubectl apply` and confirmed that the Deployment reached `3/3` available replicas.

### 4.2 Scale the Deployment to 5 replicas

```bash
kubectl scale deployment/devops-info-service -n devops-lab09 --replicas=5
kubectl rollout status deployment/devops-info-service -n devops-lab09
kubectl get pods -n devops-lab09 -o wide
```

**Result:** the Deployment was successfully scaled from 3 to 5 replicas.

```text
deployment.apps/devops-info-service scaled
Waiting for deployment "devops-info-service" rollout to finish: 3 of 5 updated replicas are available...
Waiting for deployment "devops-info-service" rollout to finish: 4 of 5 updated replicas are available...
deployment "devops-info-service" successfully rolled out
```

```text
NAME                                   READY   STATUS    RESTARTS   AGE     IP            NODE       NOMINATED NODE   READINESS GATES
devops-info-service-7b48589b6b-2b97b   1/1     Running   0          8m32s   10.244.0.14   minikube   <none>           <none>
devops-info-service-7b48589b6b-7fttq   1/1     Running   0          8m25s   10.244.0.15   minikube   <none>           <none>
devops-info-service-7b48589b6b-jjtsm   1/1     Running   0          8s      10.244.0.17   minikube   <none>           <none>
devops-info-service-7b48589b6b-wmf6g   1/1     Running   0          7s      10.244.0.18   minikube   <none>           <none>
devops-info-service-7b48589b6b-zhkpz   1/1     Running   0          8m18s   10.244.0.16   minikube   <none>           <none>
```

### 4.3 Demonstrate a rolling update
Instead of editing the YAML by hand during the live test, I used `kubectl set env` to trigger a Deployment rollout by changing the Pod template environment variables.

```bash
kubectl set env deployment/devops-info-service -n devops-lab09 \
  APP_MESSAGE="Lab 09 rolling update" \
  SERVICE_VERSION="lab09-v2"
kubectl rollout status deployment/devops-info-service -n devops-lab09
kubectl rollout history deployment/devops-info-service -n devops-lab09
```

**Result:** rollout completed successfully and the Deployment spec reflected the updated values.

```text
deployment.apps/devops-info-service env updated
Waiting for deployment "devops-info-service" rollout to finish: 1 out of 5 new replicas have been updated...
...
deployment "devops-info-service" successfully rolled out
```

```text
$ kubectl rollout history deployment/devops-info-service -n devops-lab09
REVISION  CHANGE-CAUSE
1         <none>
4         <none>
5         <none>
```

```text
$ kubectl get deployment devops-info-service -n devops-lab09 -o yaml | grep -A1 -E 'APP_MESSAGE|SERVICE_VERSION'
- name: APP_MESSAGE
  value: Lab 09 rolling update
- name: SERVICE_VERSION
  value: lab09-v2
```

### 4.4 Demonstrate rollback

```bash
kubectl rollout undo deployment/devops-info-service -n devops-lab09
kubectl rollout status deployment/devops-info-service -n devops-lab09
kubectl rollout history deployment/devops-info-service -n devops-lab09
```

**Result:** rollback completed successfully and the Deployment returned to the original values.

```text
deployment.apps/devops-info-service rolled back
Waiting for deployment "devops-info-service" rollout to finish: 1 out of 5 new replicas have been updated...
...
deployment "devops-info-service" successfully rolled out
```

```text
$ kubectl rollout history deployment/devops-info-service -n devops-lab09
REVISION  CHANGE-CAUSE
1         <none>
5         <none>
6         <none>
```

```text
$ kubectl get deployment devops-info-service -n devops-lab09 -o yaml | grep -A1 -E 'APP_MESSAGE|SERVICE_VERSION'
- name: APP_MESSAGE
  value: Lab 09 primary deployment
- name: SERVICE_VERSION
  value: lab09-v1
```

Rollback response check:

```json
$ curl http://127.0.0.1:8082/ | python3 -m json.tool
{
    "service": {
        "description": "DevOps course info service",
        "framework": "Flask",
        "message": "Lab 09 primary deployment",
        "name": "devops-info-service",
        "variant": "app1",
        "version": "lab09-v1"
    }
}
```

### 4.5 Bonus status
The repository includes bonus manifests for the second application and Ingress, but I did not complete final runtime verification for the bonus part during this execution session.

---

## 5. Production Considerations

### 5.1 Health checks
Two probes are implemented:
1. **Liveness probe** on `/health` checks whether the process is alive.
2. **Readiness probe** on `/ready` checks whether the Pod is ready to receive traffic.

### 5.2 Resource limits rationale
The application is lightweight, so the selected requests and limits are sufficient for local development while still demonstrating correct Kubernetes resource configuration.

### 5.3 Security choices
1. Non-root execution is enforced.
2. Privilege escalation is disabled.
3. All Linux capabilities are dropped.
4. `RuntimeDefault` seccomp is enabled.
5. The Docker image now uses a numeric UID/GID to satisfy Kubernetes non-root validation.

### 5.4 Suggested production improvements
For a real production deployment, I would additionally introduce:
1. `ConfigMap` and `Secret` resources.
2. `HorizontalPodAutoscaler`.
3. `NetworkPolicy` rules.
4. `PodDisruptionBudget`.
5. immutable image tags instead of `latest`.
6. CI/CD-driven promotion between environments.
7. centralized monitoring, logging, and alerting.

---

## 6. Challenges & Solutions

### 6.1 Vagrant was more complex than necessary
I initially tried the lab with Vagrant, but the workflow was slower and more fragile than needed for this local setup. I switched to **WSL + Docker Desktop + minikube**, which was simpler and more reliable.

### 6.2 Docker Desktop / WSL networking behavior
Direct access through `minikube ip` and the NodePort was not reliable in my environment. The stable solution was to verify the application with `kubectl port-forward`.

### 6.3 `CreateContainerConfigError`
The first deployment failed with:

```text
Error: container has runAsNonRoot and image has non-numeric user (app), cannot verify user is non-root
```

I fixed this by updating the Docker image to use a numeric UID/GID (`10001:10001`) and rebuilding the image inside minikube's Docker environment.

### 6.4 Rolling update evidence capture
During update verification, one local `port-forward` session was interrupted. To keep the evidence trustworthy, I documented the successful rollout with:
- rollout status
- rollout history
- Deployment environment values after update
- rollback verification with a successful application response

---

## 7. Recommended Local Execution Order

### 7.1 Prerequisites
- Windows host
- Docker Desktop
- WSL
- `kubectl` installed in WSL
- `minikube` installed in WSL

### 7.2 Cluster startup
```bash
minikube start --driver=docker
kubectl cluster-info
kubectl get nodes -o wide
```

### 7.3 Build and deploy
```bash
eval $(minikube -p minikube docker-env)
docker build -t dorley174/devops-info-service:latest ./app_python
./k8s/deploy.sh
```

### 7.4 Verify the application
```bash
kubectl port-forward -n devops-lab09 service/devops-info-service 8080:80
curl http://127.0.0.1:8080/health
curl http://127.0.0.1:8080/ready
curl http://127.0.0.1:8080/ | python3 -m json.tool
```

### 7.5 Scale, update, rollback
Use the commands from Section 4.

---

## 8. Conclusion

The lab requirements for the base task were completed:
- local Kubernetes cluster started successfully
- application deployed with 3 replicas
- Service exposed through NodePort
- readiness and liveness probes implemented
- resource requests and limits configured
- Deployment scaled to 5 replicas
- rolling update demonstrated
- rollback demonstrated
- evidence collected into `k8s/evidence/`

The repository also contains prepared bonus manifests for a second app and Ingress.
