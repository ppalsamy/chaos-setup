# 🚀 Chaos-Driven DevOps Onboarding with Chaos Mesh

Train new DevOps engineers by simulating real-world incidents in a safe, local Kubernetes environment using Chaos Mesh.

---

## 🧰 Prerequisites

Ensure the following are installed:

- Docker
  - [Docker Desktop](https://www.docker.com/products/docker-desktop/)
  - or `brew install --cask docker`
- [`kind`](https://kind.sigs.k8s.io/)
  - `brew install kind`
- `kubectl`
  - `brew install kubectl`
- `helm` (v3+)
   - `brew install helm` 
- `k6`
   - `brew install k6` 
---

## ⚙️ Step 1: Create a Local Kubernetes Cluster (Kind)

```bash
kind create cluster --name dev-cluster
kubectl cluster-info --context kind-dev-cluster
```
## ⚙️ Step 2: Install Chaos Mesh with Helm
1. Install Chaos Mesh
```
helm repo add chaos-mesh https://charts.chaos-mesh.org
helm repo update
```
2. Create Namespace
```
kubectl create ns chaos-mesh
```
3. Create Chaos Mesh Dashboard
```
helm install chaos-mesh chaos-mesh/chaos-mesh \
  -n chaos-mesh \
  --set dashboard.create=true \
  --set dashboard.securityMode=false \
  --set chaosDaemon.runtime=containerd \
  --set chaosDaemon.socketPath=/run/containerd/containerd.sock
```

4. Access the Chaos Mesh Dashboard (localhost:2333):
```
kubectl port-forward -n chaos-mesh svc/chaos-dashboard 2333:2333
# Open http://localhost:2333 in your browser
```


## ⚙️ Step 3: Install Prometheus + Grafana (Operator)

  ```
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update

    # Create a namespace for monitoring
    kubectl create ns monitoring

    # Install kube-prometheus-stack
    helm install kube-prometheus prometheus-community/kube-prometheus-stack -n monitoring \
      --set grafana.service.type=NodePort \
      --set grafana.service.nodePort=30001 \
      --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false 

   ```
That serviceMonitorSelectorNilUsesHelmValues=false is important—it lets Prometheus discover ServiceMonitor objects from other namespaces

ServiceMonitor setup (serviceMonitor_all.yaml)
```
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: podinfo
  labels:
    release: kube-prometheus  
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: "backend-podinfo"
  namespaceSelector:
    matchNames:
      - test
  endpoints:
  - port: http
    path: /metrics
    interval: 15s
```
apply it
```
kubectl apply -f servicemonitor_all.yaml

```
   Access Grafana - localhost:3000
   ```
   kubectl port-forward -n monitoring svc/kube-prometheus-grafana 3000:80
   ```
   Get Admin Creds
   ```
   kubectl get secret kube-prometheus-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
   ```
## ⚙️ Step 4: Deploy a Sample App

Below steps to deploy app using [stefanprodan/podinfo](https://github.com/stefanprodan/podinfo/tree/master?tab=readme-ov-file#helm)
```
helm repo add podinfo https://stefanprodan.github.io/podinfo

#Create test namespace
kubectl create ns test

#install frontend podinfo in test namespace
helm upgrade --install --wait frontend \
--namespace test \
--set backend=http://backend-podinfo:9898/echo \
podinfo/podinfo

#install backend podinfo in test namespace
helm upgrade --install --wait backend \
--namespace test \
--set redis.enabled=true \
podinfo/podinfo

```

Access Backend - localhost:8090
```
   kubectl port-forward -n test svc/backend-podinfo 9898:9898
```
## 🔥 Step 5: Run Chaos Experiments
Follow the experiment 
~~~
https://chaos-mesh.org/docs/simulate-network-chaos-on-kubernetes/
~~~
1. Create some load for experiment
   Use k6 to create some load
   - use below k6-load.js
     - ~~~
        import http from 'k6/http';
        import { check, sleep } from 'k6';
        
        export const options = {
          vus: 30, // 30 concurrent users
          duration: '20m',
          thresholds: {
            http_req_duration: ['p(95)<800'],
            http_req_failed: ['rate<0.05'],
          }
        };
        
        export default function () {
          const res = http.get('http://backend-podinfo.test.svc.cluster.local:9898/api/info');
          check(res, {
            'status is 200': (r) => r.status === 200,
            'response time < 800ms': (r) => r.timings.duration < 800,
          });
          sleep(Math.random() * 0.2); // 0–200ms
        }


       ~~~ 
   - create configmap to load the script
     ``` kubectl create configmap k6-load --from-file=k6-load.js -n test ```
   - Create a job  using k6-job.yaml
     ~~~
     apiVersion: batch/v1
     kind: Job
     metadata:
       name: k6-load-job
       namespace: test
     spec:
       template:
        spec:
          restartPolicy: Never
          containers:
          - name: k6
            image: loadimpact/k6:latest
            command: ["k6", "run", "/scripts/k6-load.js"]
            volumeMounts:
              - name: k6-load
                mountPath: /scripts
          volumes:
            - name: k6-load
              configMap:
                name: k6-load
      backoffLimit: 0

     ~~~
     - Run the load
       ` kubectl apply -f k6-job.yaml`
3. sdf

   
🧹 Cleanup
```
kind delete cluster --name dev-cluster
```
