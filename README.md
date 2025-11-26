# Execute a COMPSs application in Kubernetes

Prerequisite: You need to have Helm installed in your system to deploy this chart.
Helm is a package manager for Kubernetes that allows you to define, install, and upgrade complex Kubernetes applications.

Note: In order to launch the actual execution, a decryption password is required.
This password is used to decrypt the Kubernetes and Lithops configuration files, which are encrypted for security reasons.
Make sure to provide the decryptionPassword field in the values.yaml file before deploying the application.

---

## How to securely provide credentials without additional files
You can securely inject sensitive values, such as Docker registry credentials and Ceph access keys, at deploy time by setting them in a secrets.yaml file. This file is committed only once as a template and then excluded from future commits using Git's assume-unchanged flag. This approach helps prevent accidental commits of sensitive information.

By externalizing secrets in this way, you avoid storing them in Git or hardcoding them into configuration files. Instead, Helm securely injects them at deployment time and can automatically generate the corresponding Kubernetes Secrets.

Example (default namespace):
```
helm install <deploy_name> . -f secrets.yaml
```

Example (specific namespace):
```
helm install <deploy_name> . -n <namespace> -f secrets.yaml
```

URL to download the Chart locally
```
git clone git@github.com:VERGE-PROJECT/Helm-compss-app.git
```

Installation
```
cd helm-compss-app
helm install compss-app .
```

## Values file
Make sure the values file adapts to your Kubernetes cluster. By default:
- Image pull policy is set to `Always`
- The master is deployed **without** a volume
- 2 workers with 4 CPU and 4 RAM

You need to specify the `image.repository`, with COMPSs and the application, and also the `app` values. 

## Namespace
If you want to deploy the application in a custom namespace, you have to specify it when executing the `helm install`, such that:
```
helm install compss-<app-name> --namespace <your-namespace> .
```
If no namespace is specified, the application will run in the `default` namespace.

## COMPSs 
### Master command
The COMPSs master needs two files in order to be able to function correctly:
1. `resources.xml`. Provides information about all the available resources that can be used for an execution. That is, specifies the architecture, cpu, memory, network adaptor, etc for each worker. 
2. `project.xml`. Provides information about the resources used in a specific execution. That is, lists the workers. 

These two files are generated in the master command, before executing `runcompss`, which will use them. This means the CPU and memory of the workers is specified statically in the resources file, and it is not taken from the workers Kubernetes YAML definition file. So, even though the worker YAML definition is changed, the worker's information kept by the COMPSs master will not be updated automatically. 

### Master volume
You can deploy the COMPSs master with a local volume attached to it, so its results can be retreived later. The Persistent Volume deployed uses the Storage Class `local-storage`, which does not allow for dynamic provisioning, so the PV and the PVC are created in the deployment. The Storage Class needs to be created before installing the Chart. 
```
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
```

As for the `compss.master.volume` of the master, you have to check:
1. The `compss.master.volume.localPath` exists locally on the `compss.master.volume.node`.
2. The `compss.master.volume.node` is a the name of one of the nodes of your cluster (you can check with `kubectl get nodes`). Kubernetes will deploy the master pod in the node specified. 

