# Telemetry Collector

## Set up

deploy server partition

```bash
export CONSUL_LICENSE=$(op read "")
kind create cluster --name server
kubectl config set-context kind-server --namespace consul
kubectl config use-context kind-server
kubectl create namespace consul

# install metal lb
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml
kubectl apply -f ./resources/metal-lb.yaml

# create secrets
kubectl create secret generic consul-license --from-literal="license=${CONSUL_LICENSE}"
kubectl create secret generic consul-hcp-client-id --from-literal=client-id='brDBXplHdiLIapwYRjaVKsUWZz1170Zw'
kubectl create secret generic consul-hcp-client-secret --from-literal=client-secret='LjWim_Q5r9IU959mBOT7TXzwntHE-0X4mP26NxAVphnk1ZsLb9qYuOVDIak8JwVn'
kubectl create secret generic consul-hcp-observability-client-id --from-literal=client-id='fKj59paYy4BgQ7gsrefFfXuMG01KIulG'
kubectl create secret generic consul-hcp-observability-client-secret --from-literal=client-secret='G4hIdJN8ExJE4bN5-DAGptDgoFFXQQ0wtu7wyrBQ68Wv7uUr94U0IlgFelVAj1iv'
kubectl create secret generic consul-hcp-resource-id --from-literal=resource-id='organization/f785e2d8-b8f5-4676-8675-1e33ad6eb6fe/project/e4065767-bd61-4f00-8b2b-81f631f7d4d1/hashicorp.consul.global-network-manager.cluster/josh-fix-helm-2'

# install server
helm install server hashicorp/consul --namespace consul --values ./helm/partition-server.yaml
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

helm install client hashicorp/consul --values ./helm/partition-client.yaml

# making changes
helm upgrade client hashicorp/consul -f ./helm/partition-client.yaml
```

deploy consul telemetry collector to client partition:

```bash
kubectl apply -f ./resources/consul-telemetry-collector-test.yaml --namespace consul --context kind-client
```
