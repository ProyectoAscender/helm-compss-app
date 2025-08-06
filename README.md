# Execute a COMPSs application in Kubernetes

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

## Smart-city | Ascender

If you have already recieved k8s .conf file, install [k8s](https://v1-32.docs.kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-kubectl-on-linux) and [helm](https://helm.sh/es/docs/intro/install/#desde-apt-debianubuntu) client in your local machine. Place config file at `~/.kube/config`.

These are a few useful commands for k8s and helm. 

List nodes of the cluster.

`kubectl get nodes`


Create your own execution "context":

`kubectl create namespace ${USER}-smartcity`

If you've done a docker login,you can give same credential access to k8s:

`kubectl -n ${USER}-smartcity create secret generic regcred --from-file=.dockerconfigjson=/home/vmasip/.docker/config.json --type=kubernetes.io/dockerconfigjson`

Deploy the pods with helm:

`helm install -n ${USER}-smartcity smartcity-compss . --set username=$(whoami)`

where `.` is pointing to the path of the helm project you want to deploy. 

List the pods:

`kubectl get pods -n ${USER}-smartcity --watch`

Check deploying:

`kubectl describe pod -n ${USER}-smartcity smartcity-compss-master-<<XXXXXXXX>>`

Once the pod is initiated, it's container logs can be accessed:

`kubectl logs -n ${USER}-smartcity smartcity-compss-master-<<XXXXXXXX>> -c master -f`

One useful addition to kubectl logs to get latest minute of logs and not all of it:
`--since=1m`

If you want to stop the process, execute:

`helm uninstall smartcity-compss -n ${USER}-smartcity`

and list/watch pods untils it's completely uninstalled.


This project and it's templates can deploy smart-city. At `values.yaml`smart-city-compss arguments can be easily modified:
```
app:
  context:
    folderPath: /root/smart-city-compss
    file: src/main.py
  params:
    mode: "udp"
    edge_ips : "192.168.89.254:8883"
    exp_dir : "/root/smart-city-compss/runs/exp"
    save_results: "True"
    only_results: "True"
```

So, if you deploy the emulation of video-camera at nx12, and camera-edge at agx12, edge_ips shall contain agx12 ip. `8883` is portCommunicator camera-edge project. 


Normally, k8s is prepared to deploy a docker image with app/software contained in it. To avoid the pipeline:
`code modification -> modify image -> docker push -> k8s docker pull`
for every minor modification, this helm project doesn't use smart-city image internal `/root/smart-city-compss`, instead, it is overwritten with a volume mount:


```
  - name: aplicacion
        hostPath:
          path: /home/{{ .Values.username }}/smart-city-compss
          type: Directory
```

Because at `values.yaml`the master node is stablished as `àgx2`, `/home/$USER/smart-city-compss` of agx2 will be mounted into master and worker pods. 

Summary: can connect vscode to agx2:/home/$USER/smart-city-compss, and deploy every modification done there into k8s with the helm install command previously comemented. 

BSC b2drop is also mounted, so if machine has suffered a restart, check `/mnt/b2drop/smartCity`. Normally if it's empty, it's easily to configure with:
`sudo mount --all`.

smart-city-compss saves results into same project folder, and because it's mounted, can be extracted also in `/home/$USER/smart-city-compss`, more specifically at `/home/$USER/smart-city-compss/runs/exp/` . 










