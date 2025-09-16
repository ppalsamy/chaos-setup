#!/bin/bash
# Demo: Clean Slate for Chaos Mesh + Podinfo + Grafana

set -e
# 1️⃣ Delete all existing podinfo deployments
echo "Deleting existing Podinfo deployments..."
helm uninstall backend -n test || true
helm uninstall frontend -n test || true
kubectl delete job k6-load-job -n test || true
kubectl delete hpa backend-podinfo-hpa -n test || true


# 2️⃣ Delete all existing chaos experiments
echo "Deleting existing Chaos Mesh experiments..."
helm uninstall chaos-mesh -n chaos-mesh || true
# kubectl delete ns chaos-mesh || true &  # run in background

# 3️⃣ Restart Prometheus pod to recreate empty TSDB
echo "Restarting Prometheus pod..."
kubectl delete pod prometheus-kube-prometheus-kube-prome-prometheus-0 -n monitoring

# 4️⃣ Wait for a few seconds to ensure all resources are deleted
echo "Waiting for Prometheus to be ready..."
kubectl wait --for=condition=Ready pod -l statefulset.kubernetes.io/pod-name=prometheus-kube-prometheus-kube-prome-prometheus-0 -n monitoring --timeout=300s

# 5️⃣ Reinstall Podinfo application
echo "Reinstalling Podinfo application..."
helm upgrade --install --wait frontend \
  --namespace test \
  --set backend=http://backend-podinfo:9898/echo \
  --set replicaCount=2 \
--set resources.requests.cpu=100m \
  --set resources.requests.memory=128Mi \
  --set resources.limits.cpu=500m \
  --set resources.limits.memory=256Mi \
  podinfo/podinfo 


helm upgrade --install --wait backend \
  --namespace test \
  --set redis.enabled=true \
  --set replicaCount=2 \
  --set resources.requests.cpu=100m \
  --set resources.requests.memory=128Mi \
  --set resources.limits.cpu=500m \
  --set resources.limits.memory=256Mi \
  podinfo/podinfo  

# 6️⃣ verify all pods are running
echo "Verifying all pods are running..."
kubectl get pods -n test

# 7️⃣ Reinstall Chaos Mesh
# echo "Reinstalling Chaos Mesh..."
# kubectl create ns chaos-mesh || true

helm install chaos-mesh chaos-mesh/chaos-mesh \
  -n chaos-mesh \
  --set dashboard.create=true \
  --set dashboard.securityMode=false \
  --set chaosDaemon.runtime=containerd \
  --set chaosDaemon.socketPath=/run/containerd/containerd.sock

exit 0