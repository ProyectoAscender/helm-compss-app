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

# Runtime Scaling Control

The deployment includes a **runtime scaling controller** that allows dynamically adjusting the number of workers or the CPU resources assigned to them.

Scaling decisions are provided through the **Monitoring API**, which is periodically polled by the COMPSs scheduler component (`ExternalScalingService`).

The scheduler polls the following endpoint every few seconds:

```
GET /trigger
```

This endpoint returns the current scaling decision.

Example response:

```json
{
  "decision_id": 42,
  "action": "scale_out",
  "target": "agx13",
  "amount": 1,
  "cpus": 4
}
```

After applying the scaling action, the scheduler acknowledges it through:

```
POST /ack
```

This prevents the same decision from being executed multiple times.

---

# Scaling Actions

The system supports **four scaling operations**:

| Action       | Description                              |
| ------------ | ---------------------------------------- |
| `scale_up`   | Increase CPU units of an existing worker |
| `scale_down` | Decrease CPU units of an existing worker |
| `scale_out`  | Add new worker pods                      |
| `scale_in`   | Remove worker pods                       |

Scaling commands are sent through:

```
POST /set_action
```

---

# Horizontal Scaling

Horizontal scaling changes the number of worker pods.

## Scale Out (Add Workers)

Adds new worker pods.

Example Scaling Out: Adding 2 non-critical COMPSs pod worker (amount) with 4 CPUs per each (cpus) in a specific node/machine (target):

```bash
curl -X POST http://<master-ip>:15000/set_action \
  -H "Content-Type: application/json" \
  -d '{
    "action": "scale_out",
    "target": "agx13",
    "amount": 2,
    "cpus": 4
  }'
```

Example Scaling Out: Adding 2 non-critical COMPSs pod worker (amount) with 4 CPUs per each (cpus) in any available node/machine:

```bash
curl -X POST http://<master-ip>:15000/set_action \
  -H "Content-Type: application/json" \
  -d '{
    "action": "scale_out",
    "target": "all",
    "amount": 2,
    "cpus": 4
  }'
```

Parameters:

| Field    | Description                           |
| -------- | ------------------------------------- |
| `amount` | number of new worker pods             |
| `cpus`   | CPU units assigned to each COMPSs worker |

---

## Scale In (Remove Workers)

Removes worker pods from the cluster.

Example Scaling In: Removing a specific non-critical COMPSs pod worker (target):

```bash
curl -X POST http://<master-ip>:15000/set_action \
  -H "Content-Type: application/json" \
  -d '{
    "action": "scale_in",
    "target": "compss-worker-3",
    "amount": 1
  }'
```

Example Scaling In: Removing 2 non-critical COMPSs worker pods (amount) without a specific target:
```bash
curl -X POST http://<master-ip>:15000/set_action \
  -H "Content-Type: application/json" \
  -d '{
    "action": "scale_in",
    "target": "all",
    "amount": 2
  }'
```

Parameters:

| Field    | Description                 |
| -------- | --------------------------- |
| `amount` | number of workers to remove |

The runtime selects **non-critical dynamic workers** to remove. If there are no non-critical dynamic workers, COMPSs will not execute the pending worker reduction (scale in) for safety reasons.

---

# Vertical Scaling

Vertical scaling modifies the CPU resources of existing workers.

## Scale Up (Increase CPU)

Adds CPU computing units to a worker.

Example Scaling Up: Adding 2 additional CPUs (cpus) to the COMPSs pod worker (target).
```bash
curl -X POST http://<master-ip>:15000/set_action \
  -H "Content-Type: application/json" \
  -d '{
    "action": "scale_up",
    "target": "compss-worker-2",
    "amount": 1,
    "cpus": 2
  }'
```

Parameters:

| Field    | Description      |
| -------- | ---------------- |
| `target` | worker name      |
| `cpus`   | CPU units to add |

---

## Scale Down (Reduce CPU)

Removes CPU computing units from a worker.

Example Scaling Up: Removing 2 CPUs (cpus) from the COMPSs pod worker (target).
```bash
curl -X POST http://<master-ip>:15000/set_action \
  -H "Content-Type: application/json" \
  -d '{
    "action": "scale_down",
    "target": "compss-worker-2",
    "amount": 1,
    "cpus": 2
  }'
```

Parameters:

| Field    | Description         |
| -------- | ------------------- |
| `target` | worker name         |
| `cpus`   | CPU units to remove |

---

# No Scaling Action

If no scaling action is required, the monitoring API returns:

```json
{
  "action": "none"
}
```

In this case the scheduler does nothing.

---

# Scaling Workflow

The runtime scaling workflow is:

```
Monitoring API
      │
      │  POST /set_action
      ▼
Scaling state stored
      │
      │  polled every few seconds
      ▼
ExternalScalingService (COMPSs scheduler)
      │
      │  executes scaling
      ▼
Kubernetes cluster
      │
      │  POST /ack
      ▼
Scaling state reset
```

This mechanism allows scaling decisions to be controlled externally (for example by monitoring metrics or custom controllers).

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
