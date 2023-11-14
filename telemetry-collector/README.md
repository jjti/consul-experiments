# Telemetry Collector

## Set up

deploy server partition

```bash
export CONSUL_LICENSE=$(op read "")
export HELM_RELEASE_SERVER=server

kubectl config set-context kind-server --namespace consul
kubectl config use-context kind-server
kubectl create namespace consul

# install metal lb
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml
kubectl apply -f ./resources/metal-lb.yaml

# create secrets
kubectl create secret generic consul-license --from-literal="license=${CONSUL_LICENSE}"
kubectl create secret generic consul-hcp-client-id --from-literal=client-id='x'
kubectl create secret generic consul-hcp-client-secret --from-literal=client-secret='y'
kubectl create secret generic consul-hcp-observability-client-id --from-literal=client-id='x'
kubectl create secret generic consul-hcp-observability-client-secret --from-literal=client-secret='y'
kubectl create secret generic consul-hcp-resource-id --from-literal=resource-id='z'

# install server
helm install ${HELM_RELEASE_SERVER} hashicorp/consul --namespace consul --values ./helm/partition-server.yaml
```

deploy client partition

```bash
# print consul server ip
kubectl get services --selector="app=consul,component=server" --namespace consul --output jsonpath="{range .items[*]}{@.status.loadBalancer.ingress[*].ip}{end}" --context kind-server
172.18.255.201

# get k8s auth endpoint in non-default partition/cluster
kubectl config view --output "jsonpath={.clusters[?(@.name=='kind-client')].cluster.server}"
https://127.0.0.1:50937

# set both in partition-server.yaml

# create secrets
kubectl config set-context kind-client --namespace consul
kubectl config use-context kind-client
kubectl create namespace consul

# copy server ca
kubectl get secret server-consul-ca-cert --context kind-server -n consul --output yaml | kubectl apply --namespace consul --context kind-client --filename -
kubectl get secret server-consul-ca-key --context kind-server --namespace consul --output yaml | kubectl apply --namespace consul --context kind-client --filename -
kubectl get secret server-consul-partitions-acl-token --context kind-server --namespace consul --output yaml | kubectl apply --namespace consul --context kind-client --filename -

helm install client hashicorp/consul --namespace consul --values ./helm/partition-client.yaml

# making changes
helm upgrade client hashicorp/consul -f ./helm/partition-client.yaml
```

deploy consul telemetry collector to client partition:

```bash
kubectl apply -f ./resources/consul-telemetry-collector-test.yaml --namespace consul --context kind-client
```
