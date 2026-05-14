# Lab 16 Init Containers

These manifests work in the Docker/kind Lab 16 cluster.

## Prerequisite

Install monitoring first because the wait-for-service demo waits for the Grafana service in the `monitoring` namespace:

```bash
./k8s/docker/create-kind-cluster.sh
./k8s/monitoring/install-monitoring.sh
```

## Download init container

```bash
kubectl apply -f k8s/init-containers/download-demo.yaml
kubectl get pod init-download-demo
kubectl logs init-download-demo -c init-download
kubectl exec init-download-demo -- cat /data/index.html
```

## Wait-for-service init container

```bash
kubectl apply -f k8s/init-containers/wait-for-service-demo.yaml
kubectl get pod wait-for-service-demo
kubectl logs wait-for-service-demo -c wait-for-grafana
kubectl logs wait-for-service-demo -c main-app
```

## Apply both examples

```bash
kubectl apply -f k8s/init-containers/
kubectl get pods
```
