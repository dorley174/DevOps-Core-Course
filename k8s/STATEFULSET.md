# StatefulSet & Persistent Storage

## 1. StatefulSet Overview

A StatefulSet is a Kubernetes workload controller designed for applications that require stable identity and persistent state. It provides:

- stable and predictable pod names, such as `devops-info-service-0`, `devops-info-service-1`, and `devops-info-service-2`
- stable per-pod DNS names through a headless service
- persistent storage assigned independently to each replica through `volumeClaimTemplates`
- ordered creation, update, scaling, and deletion behavior

For the DevOps Info Service, StatefulSet is useful because the application stores the visit counter in `/data/visits`. With a StatefulSet, each pod receives its own persistent volume, so every replica can keep an independent counter that survives pod recreation.

### Deployment vs StatefulSet

| Characteristic | Deployment | StatefulSet |
|---|---|---|
| Pod identity | Random pod names with generated suffixes | Stable ordinal names like `pod-0`, `pod-1`, `pod-2` |
| Network identity | No stable identity for each replica | Stable DNS identity for each pod |
| Storage | Usually stateless or shared externally | One persistent volume claim per pod |
| Scaling behavior | Unordered | Ordered by default |
| Best use case | Stateless web applications and APIs | Databases, queues, and stateful services |

### Examples of stateful workloads

Typical workloads that benefit from StatefulSets include PostgreSQL, MySQL, MongoDB, Kafka, RabbitMQ, Cassandra, and Elasticsearch.

### Headless service

A headless service is a Kubernetes Service with `clusterIP: None`. It does not load-balance traffic through a virtual ClusterIP. Instead, it creates DNS records that allow clients to reach individual StatefulSet pods directly.

The DNS naming pattern used in this lab is:

```text
<pod-name>.<headless-service-name>.<namespace>.svc.cluster.local
```

For this deployment, examples are:

```text
devops-info-service-0.devops-info-service-headless.default.svc.cluster.local
devops-info-service-1.devops-info-service-headless.default.svc.cluster.local
devops-info-service-2.devops-info-service-headless.default.svc.cluster.local
```

## 2. Implementation Summary

The Helm chart was updated to deploy the application as a StatefulSet instead of a Deployment or Argo Rollout.

### Files changed or added

- `k8s/devops-info-service/values.yaml`
  - `statefulset.enabled` was set to `true`
  - `rollout.enabled` was set to `false`
  - persistence remained enabled with a 100Mi volume size
  - image repository uses the GitHub/DockerHub namespace `dorley174`

- `k8s/devops-info-service/templates/statefulset.yaml`
  - defines the `StatefulSet`
  - sets `serviceName` to the headless service
  - mounts `/data` from a per-pod PVC
  - defines `volumeClaimTemplates` for independent persistent storage

- `k8s/devops-info-service/templates/headless-service.yaml`
  - defines a headless service with `clusterIP: None`
  - selects the StatefulSet pods using the same selector labels

- `k8s/devops-info-service/templates/pvc.yaml`
  - kept for reference, but the StatefulSet uses `volumeClaimTemplates` for per-pod PVCs

The bonus/extra credit update strategy task was not implemented.

## 3. Resource Verification

### Commands used

```bash
kubectl get nodes
```

```bash
minikube image build -t dorley174/devops-info-service:lab15-local /home/vagrant/app_python
```

```bash
helm upgrade --install devops-info-service /home/vagrant/k8s/devops-info-service \
  --wait \
  --timeout 5m \
  --no-hooks \
  --set image.repository=dorley174/devops-info-service \
  --set image.tag=lab15-local \
  --set image.pullPolicy=IfNotPresent
```

If an old pod was already stuck with the previous image tag, it was recreated with:

```bash
kubectl delete pod devops-info-service-0
```

Then the resources were verified with:

```bash
kubectl rollout status statefulset/devops-info-service --timeout=180s
```

```bash
kubectl get po,sts,svc,pvc -o wide
```

```bash
kubectl get svc devops-info-service-headless -o yaml | grep -E "name:|clusterIP:|publishNotReadyAddresses:"
```

### Output

```text
$ kubectl get nodes
NAME       STATUS   ROLES           AGE    VERSION
minikube   Ready    control-plane   2h     v1.34.2

$ minikube image build -t dorley174/devops-info-service:lab15-local /home/vagrant/app_python
#0 building with "default" instance using docker driver
#1 [internal] load build definition from Dockerfile
#1 DONE
#2 [internal] load metadata for docker.io/library/python:3.13.1-slim
#2 DONE
#9 [5/6] RUN pip install --no-cache-dir -r requirements.txt
#9 DONE
#11 exporting to image
#11 writing image sha256:3cc8dc1a899e58fc7e0a11b5de360965595c4de997ec5921bbe0f6a92fd7cff1 done
#11 naming to docker.io/dorley174/devops-info-service:lab15-local done
#11 DONE

$ helm upgrade --install devops-info-service /home/vagrant/k8s/devops-info-service --wait --timeout 5m --no-hooks --set image.repository=dorley174/devops-info-service --set image.tag=lab15-local --set image.pullPolicy=IfNotPresent
Release "devops-info-service" does not exist. Installing it now.
NAME: devops-info-service
LAST DEPLOYED: Thu May  7 15:52:00 2026
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE: None

$ kubectl rollout status statefulset/devops-info-service --timeout=180s
Waiting for 3 pods to be ready...
partitioned roll out complete: 3 new pods have been updated...

$ kubectl get po,sts,svc,pvc -o wide
NAME                        READY   STATUS    RESTARTS   AGE     IP           NODE       NOMINATED NODE   READINESS GATES
pod/devops-info-service-0   1/1     Running   0          3m10s   10.244.0.5   minikube   <none>           <none>
pod/devops-info-service-1   1/1     Running   0          2m35s   10.244.0.6   minikube   <none>           <none>
pod/devops-info-service-2   1/1     Running   0          2m02s   10.244.0.7   minikube   <none>           <none>

NAME                                   READY   AGE     CONTAINERS            IMAGES
statefulset.apps/devops-info-service   3/3     3m10s   devops-info-service   dorley174/devops-info-service:lab15-local

NAME                                   TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE     SELECTOR
service/devops-info-service            NodePort    10.108.129.253   <none>        80:30083/TCP   3m11s   app.kubernetes.io/instance=devops-info-service,app.kubernetes.io/name=devops-info-service
service/devops-info-service-headless   ClusterIP   None             <none>        80/TCP         3m11s   app.kubernetes.io/instance=devops-info-service,app.kubernetes.io/name=devops-info-service
service/kubernetes                     ClusterIP   10.96.0.1        <none>        443/TCP        2h      <none>

NAME                                                      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE     VOLUMEMODE
persistentvolumeclaim/data-volume-devops-info-service-0   Bound    pvc-58f1c9dc-3436-458a-af2c-9c326059ca6f   100Mi      RWO            standard       3m11s   Filesystem
persistentvolumeclaim/data-volume-devops-info-service-1   Bound    pvc-6d16b9ec-3b64-4a79-9d25-413a66f80341   100Mi      RWO            standard       2m36s   Filesystem
persistentvolumeclaim/data-volume-devops-info-service-2   Bound    pvc-f0975d83-6c16-4b33-9672-b222a13b218a   100Mi      RWO            standard       2m03s   Filesystem

$ kubectl get svc devops-info-service-headless -o yaml | grep -E "name:|clusterIP:|publishNotReadyAddresses:"
  name: devops-info-service-headless
  namespace: default
  clusterIP: None
```

### Verification summary

The expected result is:

- one StatefulSet named `devops-info-service`
- three pods named `devops-info-service-0`, `devops-info-service-1`, and `devops-info-service-2`
- one regular service named `devops-info-service`
- one headless service named `devops-info-service-headless` with `clusterIP: None`
- one PVC per StatefulSet pod, for example:
  - `data-volume-devops-info-service-0`
  - `data-volume-devops-info-service-1`
  - `data-volume-devops-info-service-2`

## 4. Network Identity

The headless service was used to verify stable DNS records for each StatefulSet pod.

### Commands used

```bash
kubectl run dns-check --image=busybox:1.36 --restart=Never --command -- sleep 300
```

```bash
kubectl wait --for=condition=Ready pod/dns-check --timeout=60s
```

```bash
kubectl exec dns-check -- nslookup devops-info-service-0.devops-info-service-headless.default.svc.cluster.local
```

```bash
kubectl exec dns-check -- nslookup devops-info-service-1.devops-info-service-headless.default.svc.cluster.local
```

```bash
kubectl exec dns-check -- nslookup devops-info-service-2.devops-info-service-headless.default.svc.cluster.local
```

```bash
kubectl delete pod dns-check
```

### Output

```text
$ kubectl run dns-check --image=busybox:1.36 --restart=Never --command -- sleep 300
pod/dns-check created

$ kubectl wait --for=condition=Ready pod/dns-check --timeout=60s
pod/dns-check condition met

$ kubectl exec dns-check -- nslookup devops-info-service-0.devops-info-service-headless.default.svc.cluster.local
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      devops-info-service-0.devops-info-service-headless.default.svc.cluster.local
Address 1: 10.244.0.5 devops-info-service-0.devops-info-service-headless.default.svc.cluster.local

$ kubectl exec dns-check -- nslookup devops-info-service-1.devops-info-service-headless.default.svc.cluster.local
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      devops-info-service-1.devops-info-service-headless.default.svc.cluster.local
Address 1: 10.244.0.6 devops-info-service-1.devops-info-service-headless.default.svc.cluster.local

$ kubectl exec dns-check -- nslookup devops-info-service-2.devops-info-service-headless.default.svc.cluster.local
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      devops-info-service-2.devops-info-service-headless.default.svc.cluster.local
Address 1: 10.244.0.7 devops-info-service-2.devops-info-service-headless.default.svc.cluster.local

$ kubectl delete pod dns-check
pod "dns-check" deleted
```

### Verification summary

Successful DNS lookup confirms that StatefulSet pods have stable network identities through the headless service.

## 5. Per-Pod Storage Evidence

Each pod was accessed directly through a separate port-forward. This verifies that the replicas do not share the same visit counter file.

### Port-forward commands

Run these in separate terminals:

```bash
kubectl port-forward pod/devops-info-service-0 8080:5000
```

```bash
kubectl port-forward pod/devops-info-service-1 8081:5000
```

```bash
kubectl port-forward pod/devops-info-service-2 8082:5000
```

### Request commands

```bash
curl http://127.0.0.1:8080/visits
curl http://127.0.0.1:8080/visits
```

```bash
curl http://127.0.0.1:8081/visits
```

```bash
curl http://127.0.0.1:8082/visits
curl http://127.0.0.1:8082/visits
curl http://127.0.0.1:8082/visits
```

### Counter verification commands

```bash
kubectl exec devops-info-service-0 -- cat /data/visits
```

```bash
kubectl exec devops-info-service-1 -- cat /data/visits
```

```bash
kubectl exec devops-info-service-2 -- cat /data/visits
```

### Output

```text
Terminal 1:
$ kubectl port-forward pod/devops-info-service-0 8080:5000
Forwarding from 127.0.0.1:8080 -> 5000
Forwarding from [::1]:8080 -> 5000

Terminal 2:
$ kubectl port-forward pod/devops-info-service-1 8081:5000
Forwarding from 127.0.0.1:8081 -> 5000
Forwarding from [::1]:8081 -> 5000

Terminal 3:
$ kubectl port-forward pod/devops-info-service-2 8082:5000
Forwarding from 127.0.0.1:8082 -> 5000
Forwarding from [::1]:8082 -> 5000

$ curl http://127.0.0.1:8080/visits
{"visits":1}
$ curl http://127.0.0.1:8080/visits
{"visits":2}

$ curl http://127.0.0.1:8081/visits
{"visits":1}

$ curl http://127.0.0.1:8082/visits
{"visits":1}
$ curl http://127.0.0.1:8082/visits
{"visits":2}
$ curl http://127.0.0.1:8082/visits
{"visits":3}

$ kubectl exec devops-info-service-0 -- cat /data/visits
2

$ kubectl exec devops-info-service-1 -- cat /data/visits
1

$ kubectl exec devops-info-service-2 -- cat /data/visits
3
```

### Verification summary

Different counter values in `/data/visits` prove that every pod uses its own persistent volume. This confirms per-pod storage isolation.

## 6. Persistence Test

Persistence was tested by deleting one StatefulSet pod and checking that its data remained available after Kubernetes recreated it.

### Commands used

```bash
kubectl exec devops-info-service-0 -- cat /data/visits
```

```bash
kubectl delete pod devops-info-service-0
```

```bash
kubectl rollout status statefulset/devops-info-service --timeout=180s
```

```bash
kubectl exec devops-info-service-0 -- cat /data/visits
```

### Output

```text
$ kubectl exec devops-info-service-0 -- cat /data/visits
2

$ kubectl delete pod devops-info-service-0
pod "devops-info-service-0" deleted

$ kubectl rollout status statefulset/devops-info-service --timeout=180s
Waiting for 1 pods to be ready...
partitioned roll out complete: 3 new pods have been updated...

$ kubectl get pod devops-info-service-0 -o wide
NAME                    READY   STATUS    RESTARTS   AGE   IP           NODE       NOMINATED NODE   READINESS GATES
devops-info-service-0   1/1     Running   0          52s   10.244.0.8   minikube   <none>           <none>

$ kubectl exec devops-info-service-0 -- cat /data/visits
2
```

### Verification summary

The expected result is that the value before and after deleting `devops-info-service-0` is the same. This proves that:

- the pod was recreated with the same stable ordinal identity
- the existing PVC `data-volume-devops-info-service-0` was reused
- the `/data/visits` file persisted across pod deletion and recreation

## 7. Cleanup Commands

These commands can be used after the lab is checked:

```bash
helm uninstall devops-info-service
```

```bash
kubectl delete pvc -l app.kubernetes.io/instance=devops-info-service
```
