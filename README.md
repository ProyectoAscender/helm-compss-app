# Run a COMPSs Application on Kubernetes

This Helm chart deploys a **COMPSs application runtime on a Kubernetes cluster**, including:

* COMPSs master
* COMPSs workers
* monitoring API
* optional result storage
* Prometheus monitoring integration

The chart manages the deployment of all components required to execute a COMPSs workflow in Kubernetes.

---

# Prerequisites

You must have the following tools installed:

* Kubernetes cluster
* `kubectl`
* Helm ≥ 3

Helm is used to package and deploy the Kubernetes resources required by the COMPSs runtime.

---

# Getting the Chart

Clone the repository locally:

```
git clone git@github.com:VERGE-PROJECT/Helm-compss-app.git
cd Helm-compss-app
```

---

# Installation

Basic deployment:

```
helm install compss-app .
```

Deployment in a custom namespace:

```
helm install compss-app --namespace <namespace> .
```

If no namespace is specified, the deployment uses the `default` namespace.

---

# Providing Secrets Securely

Sensitive values such as:

* Docker registry credentials
* Ceph access keys
* external service credentials

should **not be stored in the repository**.

Instead, provide them at deployment time through a `secrets.yaml` file.

Example:

```
helm install <deploy_name> . -f secrets.yaml
```

or with namespace:

```
helm install <deploy_name> . -n <namespace> -f secrets.yaml
```

To avoid accidental commits, the template `secrets.yaml` can be marked as ignored using:

```
git update-index --assume-unchanged secrets.yaml
```

---

# Values Configuration

The `values.yaml` file controls the deployment configuration.

Default configuration:

* `imagePullPolicy: Always`
* master deployed without persistent volume
* two workers deployed
* worker resource limits are not enforced by default

You must specify:

```
image.repository
```

which should point to a container image containing:

* COMPSs runtime
* the application to execute

---

# COMPSs Runtime Configuration

## Master Startup

The COMPSs master generates the required runtime configuration files before launching the application.

Two files are generated automatically:

### resources.xml

Describes the **available resources** in the execution.

Includes:

* CPU
* memory
* architecture
* network configuration
* worker capabilities

### project.xml

Describes the **resources used in a specific execution**.

Lists the workers that participate in the execution.

These files are generated before running:

```
runcompss
```

Important implication:

Worker CPU and memory defined in Kubernetes **are not automatically propagated** to the COMPSs runtime.

Instead, resource information used by COMPSs is defined statically in `resources.xml`.

---

# Master Persistent Volume

The master can optionally mount a **local persistent volume** to store runtime results.

The chart creates:

* a PersistentVolume
* a PersistentVolumeClaim

using the storage class:

```
local-storage
```

This storage class must exist before installing the chart.

Example:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
```

Configuration requirements:

1. `compss.master.volume.localPath` must exist on the node
2. `compss.master.volume.node` must correspond to a valid Kubernetes node

Example:

```
kubectl get nodes
```

The results directory is mounted inside the container at:

```
/root/.COMPSs/
```

---

# Heterogeneous Worker Nodes

The chart supports **heterogeneous clusters**, allowing workers to run on different Kubernetes nodes.

This is implemented using `nodeSelector`.

Example:

```
spec:
  nodeSelector:
    kubernetes.io/hostname: agx13
```

Another worker can target a different node:

```
spec:
  nodeSelector:
    kubernetes.io/hostname: radxa
```

This allows the workflow to run across machines with different:

* CPU architectures
* performance characteristics
* hardware capabilities

Example deployment topology:

| Worker   | Kubernetes Node |
| -------- | --------------- |
| worker-0 | agx13           |
| worker-1 | radxa           |

Each worker is deployed as an independent Kubernetes Deployment.

---

# Worker Services

Each worker has its own Kubernetes Service used by the COMPSs master.

Example:

```
release-name-worker-0
release-name-worker-1
```

Workers expose the COMPSs runtime ports:

```
22
43001
43002
49049
```

Workers are discovered through Kubernetes DNS.

---

# Master Startup Synchronization

The master includes an `initContainer` that waits for worker services before starting.

Example:

```yaml
initContainers:
- name: wait-for-workers
  image: busybox
  command:
    - sh
    - -c
    - |
      for i in $(seq 1 2); do
        worker_index=$((i - 1))
        until nslookup release-name-worker-${worker_index}.default.svc.cluster.local; do
          echo "Waiting for release-name-worker-${worker_index}";
          sleep 2;
        done;
      done
```

This prevents the master from starting before workers are available in DNS.

---

# Monitoring Integration

The deployment includes a monitoring container that exposes runtime metrics and scaling endpoints.

Container:

```
oriolmac/compss-monitoring:1.0
```

Port exposed:

```
15000
```

---

# Prometheus Metrics

The chart deploys a `ServiceMonitor` resource for Prometheus Operator integration.

Example configuration:

```
kind: ServiceMonitor
endpoints:
  - port: monitoring
    interval: 5s
    scrapeTimeout: 5s
    path: /metrics
```

Prometheus scrapes runtime metrics exposed by the monitoring container.

---

# Deployment Architecture

The deployed components are:

```
COMPSs Master
 ├─ Monitoring API
 ├─ Redis
 └─ COMPSs runtime
        │
        ├── Worker Deployment 0
        │
        └── Worker Deployment 1
```

Workers execute tasks scheduled by the COMPSs runtime running in the master container.
