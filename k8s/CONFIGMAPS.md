# Lab 12 — ConfigMaps & Persistent Volumes

This report documents the Lab 12 implementation for `devops-info-service`.

**Bonus task was not implemented.**

**Command outputs in this report were taken from the recorded WSL terminal sessions.**

---

## 1. Application Changes

### 1.1 Visits counter implementation
The application was upgraded to persist a visits counter in a file.

Implemented behavior:
1. The counter file path is controlled through the `VISITS_FILE` environment variable.
2. The default path is `/data/visits`.
3. The application creates the parent directory automatically if it does not exist.
4. On startup, the service initializes the visits file with `0` when the file is missing.
5. Every request to `GET /` reads, increments, and persists the counter.
6. The `GET /visits` endpoint returns the current persisted counter value without incrementing it.

### 1.2 Concurrency handling
A process-level `threading.Lock()` protects the read-modify-write sequence. The file is persisted with an atomic replace operation using a temporary file and `os.replace(...)`.

This is sufficient for the lab because it prevents race conditions inside a single Flask process.

### 1.3 New and updated endpoints
The following endpoint behavior is now implemented:

- `GET /` — increments the persisted visits counter and returns application metadata
- `GET /visits` — returns the current visits counter from the file
- `GET /health` — liveness probe endpoint
- `GET /ready` — readiness probe endpoint
- `GET /metrics` — Prometheus metrics endpoint

### 1.4 Local Docker Compose test setup
A new file was added:

```text
app_python/docker-compose.yml
```

The compose configuration mounts a local host directory into the container:

```yaml
volumes:
  - ./data:/data
```

This allows the visits file to remain on the host across container restarts.

### 1.5 Local test procedure
```bash
cd app_python
mkdir -p data
docker compose up --build -d
curl http://127.0.0.1:5000/
curl http://127.0.0.1:5000/
curl http://127.0.0.1:5000/visits
cat ./data/visits
docker compose restart
curl http://127.0.0.1:5000/visits
cat ./data/visits
```

```text
Local Docker Compose output was not captured in the provided terminal sessions.
The implementation was verified live in Kubernetes after the Helm deployment was fixed and the updated image was loaded into Minikube.
```

### 1.6 Application README update
`app_python/README.md` was updated with:
1. the new `/visits` endpoint;
2. the `VISITS_FILE` environment variable;
3. Docker Compose persistence testing steps.

---

## 2. ConfigMap Implementation

### 2.1 Helm chart files added
The main Helm chart was extended with these new files:

```text
k8s/devops-info-service/files/config.json
k8s/devops-info-service/templates/configmap.yaml
```

### 2.2 File-based configuration
The chart now contains a static configuration file stored under `files/config.json`.

Implemented JSON structure:
- application name
- environment
- description
- feature flags
- basic settings such as log level and config source

### 2.3 ConfigMap created from file
The first ConfigMap is defined in `templates/configmap.yaml` and loads the file content through Helm `.Files.Get`.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "devops-info-service.fullname" . }}-config
data:
  config.json: |-
{{ .Files.Get "files/config.json" | indent 4 }}
```

### 2.4 ConfigMap created for environment variables
The same template file also defines a second ConfigMap used for environment variables.

Injected keys:
- `APP_ENV`
- `LOG_LEVEL`
- `FEATURE_VISITS_ENDPOINT`
- `FEATURE_PERSISTENT_COUNTER`
- `CONFIG_FILE_PATH`

### 2.5 Deployment changes for ConfigMaps
The Deployment was updated in three ways.

#### File mount
The file-based ConfigMap is mounted as a directory:

```yaml
volumeMounts:
  - name: config-volume
    mountPath: /config
    readOnly: true
```

and the corresponding volume is:

```yaml
volumes:
  - name: config-volume
    configMap:
      name: {{ include "devops-info-service.fullname" . }}-config
```

#### Environment variable injection
The environment ConfigMap is injected with `envFrom`:

```yaml
envFrom:
  - configMapRef:
      name: {{ include "devops-info-service.fullname" . }}-env
```

#### Application path wiring
The application reads:
- `CONFIG_FILE_PATH=/config/config.json`
- `VISITS_FILE=/data/visits`

### 2.6 Verification commands
```bash
helm lint ./k8s/devops-info-service
helm template devops-app ./k8s/devops-info-service -n devops-lab12 -f ./k8s/devops-info-service/values-dev.yaml
helm upgrade --install devops-app ./k8s/devops-info-service \
  -n devops-lab12 \
  --create-namespace \
  -f ./k8s/devops-info-service/values-dev.yaml
kubectl get configmap -n devops-lab12
kubectl exec -n devops-lab12 deploy/devops-app -- cat /config/config.json
kubectl exec -n devops-lab12 deploy/devops-app -- printenv | grep -E 'APP_|LOG_LEVEL|CONFIG_FILE_PATH'
```

```text
$ helm lint ./k8s/devops-info-service
==> Linting ./k8s/devops-info-service
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed

$ helm template devops-app ./k8s/devops-info-service -n devops-lab12 -f ./k8s/devops-info-service/values-dev.yaml
Rendered resources included:
- ServiceAccount devops-app-devops-info-service
- Secret devops-app-devops-info-service-secret
- ConfigMap devops-app-devops-info-service-config
- ConfigMap devops-app-devops-info-service-env
- PersistentVolumeClaim devops-app-devops-info-service-data
- Service devops-app-devops-info-service
- Deployment devops-app-devops-info-service
- pre-install and post-install hook Jobs

$ helm upgrade --install devops-app ./k8s/devops-info-service -n devops-lab12 --create-namespace -f ./k8s/devops-info-service/values-dev.yaml
Error: kubernetes cluster unreachable: Get "https://127.0.0.1:52858/version": dial tcp 127.0.0.1:52858: connect: connection refused

$ minikube start
😄  minikube v1.38.1 on Ubuntu 24.04 (amd64)
✨  Using the docker driver based on existing profile
👍  Starting "minikube" primary control-plane node in "minikube" cluster
🐳  Preparing Kubernetes v1.35.1 on Docker 29.2.1 ...
🌟  Enabled addons: default-storageclass, storage-provisioner
🏄  Done! kubectl is now configured to use "minikube" cluster and "default" namespace by default

$ kubectl get nodes
NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   20d   v1.35.1

$ helm upgrade --install devops-app ./k8s/devops-info-service -n devops-lab12 --create-namespace -f ./k8s/devops-info-service/values-dev.yaml
Release "devops-app" does not exist. Installing it now.
Error: Service "devops-app-devops-info-service" is invalid: spec.ports[0].nodePort: Invalid value: 30080: provided port is already allocated

$ kubectl get svc -A | grep 30080
devops-lab09   devops-info-service   NodePort   10.100.203.165   <none>   80:30080/TCP   20d

$ helm upgrade --install devops-app ./k8s/devops-info-service -n devops-lab12 --create-namespace -f ./k8s/devops-info-service/values-dev.yaml --set service.type=ClusterIP
Release "devops-app" has been upgraded. Happy Helming!
NAME: devops-app
LAST DEPLOYED: Thu Apr 16 16:16:50 2026
NAMESPACE: devops-lab12
STATUS: deployed
REVISION: 3
DESCRIPTION: Upgrade complete

$ kubectl get all -n devops-lab12
NAME                                                  READY   STATUS    RESTARTS   AGE
pod/devops-app-devops-info-service-6d7c866977-dg42z   1/1     Running   0          5m13s

NAME                                     TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
service/devops-app-devops-info-service   ClusterIP   10.102.167.101   <none>        80/TCP    15s

NAME                                             READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/devops-app-devops-info-service   1/1     1            1           5m13s

NAME                                                        DESIRED   CURRENT   READY   AGE
replicaset.apps/devops-app-devops-info-service-6d7c866977   1         1         1       5m13s

$ kubectl get configmap,pvc -n devops-lab12
NAME                                              DATA   AGE
configmap/devops-app-devops-info-service-config   1      5m13s
configmap/devops-app-devops-info-service-env      5      5m13s
configmap/kube-root-ca.crt                        1      5m19s

NAME                                                        STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/devops-app-devops-info-service-data   Bound    pvc-ec55758d-3d54-45cc-84d5-4ab86b2a6727   100Mi      RWO            standard       <unset>                 5m13s

$ kubectl exec -n devops-lab12 deploy/devops-app-devops-info-service -- cat /config/config.json
{
  "application": {
    "name": "devops-info-service",
    "environment": "dev",
    "description": "Configuration mounted from a Helm-managed ConfigMap"
  },
  "features": {
    "visitsEndpoint": true,
    "persistentCounter": true,
    "metrics": true
  },
  "settings": {
    "logLevel": "INFO",
    "configSource": "configmap-file"
  }
}

$ kubectl exec -n devops-lab12 deploy/devops-app-devops-info-service -- printenv | grep -E 'APP_|LOG_LEVEL|CONFIG_FILE_PATH'
LOG_LEVEL=DEBUG
APP_MESSAGE=Lab 12 Helm development deployment
APP_ENV=dev
CONFIG_FILE_PATH=/config/config.json
APP_VARIANT=app1
APP_USERNAME=change-me-username
APP_PASSWORD=change-me-password
```

### 2.7 Expected verification evidence
Required evidence for the report:
1. `kubectl get configmap,pvc`
2. `cat /config/config.json` from inside the pod
3. environment variables printed from inside the pod

---

## 3. Persistent Volume Implementation

### 3.1 PersistentVolumeClaim template
A new template was added:

```text
k8s/devops-info-service/templates/pvc.yaml
```

Implemented PVC characteristics:
- `ReadWriteOnce` access mode
- configurable storage request
- configurable storage class
- default requested size: `100Mi`

### 3.2 Values added for persistence
The chart now includes this values block:

```yaml
persistence:
  enabled: true
  mountPath: "/data"
  size: 100Mi
  storageClass: ""
```

An empty storage class means the cluster default storage class is used.

### 3.3 Deployment changes for persistent storage
The application pod now mounts persistent storage under `/data`.

```yaml
volumeMounts:
  - name: data-volume
    mountPath: /data
```

The volume references the PVC when persistence is enabled.

```yaml
volumes:
  - name: data-volume
    persistentVolumeClaim:
      claimName: {{ include "devops-info-service.fullname" . }}-data
```

### 3.4 Security context adjustment
Because the container runs as a non-root user, the pod security context was extended with:

```yaml
securityContext:
  seccompProfile:
    type: RuntimeDefault
  fsGroup: 10001
```

This helps ensure that the mounted volume is writable by the application process.

### 3.5 Persistence verification procedure
```bash
kubectl get pvc -n devops-lab12
kubectl get pods -n devops-lab12
curl http://127.0.0.1:8080/
curl http://127.0.0.1:8080/
curl http://127.0.0.1:8080/visits
kubectl exec -n devops-lab12 <pod-name> -- cat /data/visits
kubectl delete pod -n devops-lab12 <pod-name>
kubectl get pods -n devops-lab12 -w
curl http://127.0.0.1:8080/visits
kubectl exec -n devops-lab12 <new-pod-name> -- cat /data/visits
```

```text
$ kubectl port-forward -n devops-lab12 service/devops-app-devops-info-service 8080:80
Forwarding from 127.0.0.1:8080 -> 5000
Forwarding from [::1]:8080 -> 5000
Handling connection for 8080
Handling connection for 8080
Handling connection for 8080

$ curl http://127.0.0.1:8080/
{"endpoints":[{"description":"Service information","method":"GET","path":"/"},{"description":"Liveness health check","method":"GET","path":"/health"},{"description":"Readiness health check","method":"GET","path":"/ready"},{"description":"Prometheus metrics","method":"GET","path":"/metrics"}],"request":{"client_ip":"127.0.0.1","method":"GET","path":"/","user_agent":"curl/8.5.0"},"runtime":{"current_time":"2026-04-16T13:17:24.097Z","timezone":"UTC","uptime_human":"0 hours, 5 minutes","uptime_seconds":315},"service":{"description":"DevOps course info service","framework":"Flask","message":"Lab 12 Helm development deployment","name":"devops-info-service","variant":"app1","version":"lab12-dev"},"system":{"architecture":"x86_64","cpu_count":20,"hostname":"devops-app-devops-info-service-6d7c866977-dg42z","platform":"Linux","platform_version":"Linux-5.15.153.1-microsoft-standard-WSL2-x86_64-with-glibc2.36","python_version":"3.13.1"}}

$ curl http://127.0.0.1:8080/visits
{"error":"Not Found","message":"Endpoint does not exist","timestamp":"2026-04-16T13:17:24.210Z"}

$ kubectl exec -n devops-lab12 deploy/devops-app-devops-info-service -- cat /data/visits
cat: /data/visits: No such file or directory
command terminated with exit code 1

The first deployment was using an older image, so the /visits endpoint and persisted counter were not available yet.

$ minikube image build -t devops-info-service:lab12 ./app_python
#0 building with "default" instance using docker driver
#11 naming to docker.io/library/devops-info-service:lab12 done
#11 DONE 0.1s

$ helm upgrade --install devops-app ./k8s/devops-info-service -n devops-lab12 --create-namespace -f ./k8s/devops-info-service/values-dev.yaml --set service.type=ClusterIP --set image.repository=devops-info-service --set image.tag=lab12 --set image.pullPolicy=IfNotPresent
Release "devops-app" has been upgraded. Happy Helming!
NAME: devops-app
LAST DEPLOYED: Thu Apr 16 16:23:14 2026
NAMESPACE: devops-lab12
STATUS: deployed
REVISION: 4
DESCRIPTION: Upgrade complete

$ kubectl rollout status deployment/devops-app-devops-info-service -n devops-lab12
Waiting for deployment "devops-app-devops-info-service" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "devops-app-devops-info-service" rollout to finish: 1 old replicas are pending termination...
deployment "devops-app-devops-info-service" successfully rolled out

$ kubectl get pod -n devops-lab12 -o jsonpath='{.items[0].spec.containers[0].image}'; echo
devops-info-service:lab12

$ kubectl port-forward -n devops-lab12 service/devops-app-devops-info-service 8080:80
Forwarding from 127.0.0.1:8080 -> 5000
Forwarding from [::1]:8080 -> 5000
Handling connection for 8080
Handling connection for 8080

$ curl http://127.0.0.1:8080/
{"configuration":{"app_env":"dev","config_file":{"application":{"description":"Configuration mounted from a Helm-managed ConfigMap","environment":"dev","name":"devops-info-service"},"features":{"metrics":true,"persistentCounter":true,"visitsEndpoint":true},"settings":{"configSource":"configmap-file","logLevel":"INFO"}},"config_file_loaded":true,"config_file_path":"/config/config.json","feature_visits_endpoint":"true","log_level":"DEBUG"},"endpoints":[{"description":"Service information and visit counter increment","method":"GET","path":"/"},{"description":"Current persisted visit count","method":"GET","path":"/visits"},{"description":"Liveness health check","method":"GET","path":"/health"},{"description":"Readiness health check","method":"GET","path":"/ready"},{"description":"Prometheus metrics","method":"GET","path":"/metrics"}],"request":{"client_ip":"127.0.0.1","method":"GET","path":"/","user_agent":"curl/8.5.0"},"runtime":{"current_time":"2026-04-16T13:24:11.246Z","timezone":"UTC","uptime_human":"0 hours, 0 minutes","uptime_seconds":43},"service":{"description":"DevOps course info service","framework":"Flask","message":"Lab 12 Helm development deployment","name":"devops-info-service","variant":"app1","version":"lab12-dev"},"system":{"architecture":"x86_64","cpu_count":20,"hostname":"devops-app-devops-info-service-5cb8488cbb-cfm8v","platform":"Linux","platform_version":"Linux-5.15.153.1-microsoft-standard-WSL2-x86_64-with-glibc2.36","python_version":"3.13.1"},"visits":{"count":1,"file":"/data/visits"}}

$ curl http://127.0.0.1:8080/
{"configuration":{"app_env":"dev","config_file":{"application":{"description":"Configuration mounted from a Helm-managed ConfigMap","environment":"dev","name":"devops-info-service"},"features":{"metrics":true,"persistentCounter":true,"visitsEndpoint":true},"settings":{"configSource":"configmap-file","logLevel":"INFO"}},"config_file_loaded":true,"config_file_path":"/config/config.json","feature_visits_endpoint":"true","log_level":"DEBUG"},"endpoints":[{"description":"Service information and visit counter increment","method":"GET","path":"/"},{"description":"Current persisted visit count","method":"GET","path":"/visits"},{"description":"Liveness health check","method":"GET","path":"/health"},{"description":"Readiness health check","method":"GET","path":"/ready"},{"description":"Prometheus metrics","method":"GET","path":"/metrics"}],"request":{"client_ip":"127.0.0.1","method":"GET","path":"/","user_agent":"curl/8.5.0"},"runtime":{"current_time":"2026-04-16T13:24:11.354Z","timezone":"UTC","uptime_human":"0 hours, 0 minutes","uptime_seconds":43},"service":{"description":"DevOps course info service","framework":"Flask","message":"Lab 12 Helm development deployment","name":"devops-info-service","variant":"app1","version":"lab12-dev"},"system":{"architecture":"x86_64","cpu_count":20,"hostname":"devops-app-devops-info-service-5cb8488cbb-cfm8v","platform":"Linux","platform_version":"Linux-5.15.153.1-microsoft-standard-WSL2-x86_64-with-glibc2.36","python_version":"3.13.1"},"visits":{"count":2,"file":"/data/visits"}}

$ curl http://127.0.0.1:8080/visits
{"file":"/data/visits","timestamp":"2026-04-16T13:24:11.370Z","visits":2}

$ kubectl exec -n devops-lab12 deploy/devops-app-devops-info-service -- cat /data/visits
2

$ kubectl delete pod -n devops-lab12 $(kubectl get pod -n devops-lab12 -o name | head -n 1 | cut -d/ -f2)
pod "devops-app-devops-info-service-5cb8488cbb-cfm8v" deleted from devops-lab12 namespace

$ kubectl rollout status deployment/devops-app-devops-info-service -n devops-lab12
deployment "devops-app-devops-info-service" successfully rolled out

$ kubectl get pods -n devops-lab12 -w
NAME                                              READY   STATUS    RESTARTS   AGE
devops-app-devops-info-service-5cb8488cbb-bf5cn   1/1     Running   0          4m19s

$ kubectl port-forward -n devops-lab12 service/devops-app-devops-info-service 8081:80
Forwarding from 127.0.0.1:8081 -> 5000
Forwarding from [::1]:8081 -> 5000
Handling connection for 8081
Handling connection for 8081

$ curl http://127.0.0.1:8081/visits
{"file":"/data/visits","timestamp":"2026-04-16T13:29:26.440Z","visits":2}

$ kubectl exec -n devops-lab12 deploy/devops-app-devops-info-service -- cat /data/visits
2
```

### 3.6 Persistence result interpretation
The expected correct result is:
1. the visits counter increases after requests to `/`;
2. the value stored in `/data/visits` matches the `/visits` endpoint;
3. after deleting the pod, the Deployment creates a replacement pod;
4. the replacement pod reads the same persisted value from the PVC.

---

## 4. ConfigMap vs Secret

### 4.1 When to use ConfigMap
Use a ConfigMap for non-sensitive configuration such as:
- application environment names;
- feature flags;
- log levels;
- JSON or text configuration files;
- non-secret runtime parameters.

### 4.2 When to use Secret
Use a Secret for sensitive data such as:
- passwords;
- API tokens;
- private keys;
- database credentials;
- any confidential application value.

### 4.3 Key differences
| Aspect | ConfigMap | Secret |
|---|---|---|
| Intended data type | Non-sensitive configuration | Sensitive values |
| Typical examples | Log level, app mode, feature flags | Passwords, tokens, credentials |
| Encoding | Plain manifest data | Base64-encoded object data |
| Security expectation | Convenience and separation of config | Restricted access and stronger protection |
| Typical consumption | Mounted files or environment variables | Mounted files or environment variables |

### 4.4 Practical rule used in this lab
In this repository:
- ConfigMaps are used for `config.json` and general runtime variables.
- Kubernetes Secrets remain responsible for credentials such as `APP_USERNAME` and `APP_PASSWORD`.

---

## 5. Final File Summary

### 5.1 Application files changed
```text
app_python/app.py
app_python/Dockerfile
app_python/docker-compose.yml
app_python/README.md
app_python/.gitignore
```

### 5.2 Helm files changed or added
```text
k8s/devops-info-service/Chart.yaml
k8s/devops-info-service/values.yaml
k8s/devops-info-service/values-dev.yaml
k8s/devops-info-service/values-prod.yaml
k8s/devops-info-service/files/config.json
k8s/devops-info-service/templates/configmap.yaml
k8s/devops-info-service/templates/deployment.yaml
k8s/devops-info-service/templates/pvc.yaml
k8s/CONFIGMAPS.md
```

---

## 6. Submission Checklist Mapping

### Task 1 — Application Persistence Upgrade
- [x] Visits counter implemented
- [x] `/visits` endpoint created
- [x] Counter persists in file
- [x] Docker Compose volume configured
- [x] Application README updated

### Task 2 — ConfigMaps
- [x] `files/config.json` created
- [x] ConfigMap template for file mounting created
- [x] ConfigMap template for environment variables created
- [x] Deployment mounts ConfigMap as file
- [x] Deployment injects environment variables with `envFrom`

### Task 3 — Persistent Volumes
- [x] PVC template created
- [x] PVC mounted to Deployment
- [x] Visits file stored under `/data/visits`
- [x] Persistence verification procedure documented

### Task 4 — Documentation
- [x] `k8s/CONFIGMAPS.md` created
- [x] Application changes documented
- [x] ConfigMap implementation documented
- [x] Persistent volume implementation documented
- [x] Verification sections completed with recorded terminal outputs
