kubectl create namespace smartcity
helm install -n smartcity smartcity-compss .
kubectl get pods -n smartcity --watch

helm uninstall smartcity-compss -n smartcity



kubectl -n smartcity create secret generic regcred --from-file=.dockerconfigjson=/home/vmasip/.docker/config.json --type=kubernetes.io/dockerconfigjson
kubectl get svc -A


vmasip@agx12:~/smart-city-compss/runs/exp/main.py_12/monitor$ docker run -v $(pwd):/framework -it registry.gitlab.bsc.es/ppc/benchmarks/smart-city/smart-city-compss:1.0-3.3-final2-arm bash
compss_gengraph complete_graph.dot 