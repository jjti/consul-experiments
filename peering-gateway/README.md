# Peering with Mesh Gateway

This is based loosely on https://github.com/t-eckert/consul-lab/tree/73b755565fc4b745b024a8372eaa1610f8d65ddc/cluster-peering-termgw

Docs: https://developer.hashicorp.com/consul/docs/connect/gateways/mesh-gateway/peering-via-mesh-gateways

deploy dc1

```bash
export CONSUL_LICENSE=$(op read "op://Cloud/consul-license/dev/license" --account hashicorp.1password.com)
kind create cluster --name dc1
kubectl config set-context kind-dc1 --namespace consul
kubectl config use-context kind-dc1
kubectl create namespace consul

# install metal lb
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml
kubectl apply -f ./dc1/resources/metal-lb.yaml

# create secrets
kubectl create secret generic consul-license --from-literal="license=${CONSUL_LICENSE}"
kubectl create secret generic consul-hcp-client-id --from-literal=client-id='tWMGJNSv5qlEfLTvTy1T5kpxMpntd76r'
kubectl create secret generic consul-hcp-client-secret --from-literal=client-secret='x'
kubectl create secret generic consul-hcp-observability-client-id --from-literal=client-id='tWMGJNSv5qlEfLTvTy1T5kpxMpntd76r'
kubectl create secret generic consul-hcp-observability-client-secret --from-literal=client-secret='x'
kubectl create secret generic consul-hcp-resource-id --from-literal=resource-id='organization/f785e2d8-b8f5-4676-8675-1e33ad6eb6fe/project/e4065767-bd61-4f00-8b2b-81f631f7d4d1/hashicorp.consul.global-network-manager.cluster/dc1'
kubectl create secret generic consul-bootstrap-token --from-literal=token='6b58b6e5-755d-4d74-aaa1-fb65860c9a0f'

# install dc1
helm install dc1 hashicorp/consul --namespace consul --values ./dc1/helm/values.yaml

kubectl apply -f ./dc1/resources
```

deploy dc2

```bash
export CONSUL_LICENSE=$(op read "op://Cloud/consul-license/dev/license" --account hashicorp.1password.com)
kind create cluster --name dc2
kubectl config set-context kind-dc2 --namespace consul
kubectl config use-context kind-dc2
kubectl create namespace consul

# install metal lb
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml
kubectl apply -f ./dc2/resources/metal-lb.yaml

# create secrets
kubectl create secret generic consul-license --from-literal="license=${CONSUL_LICENSE}"
kubectl create secret generic consul-hcp-client-id --from-literal=client-id='cfeghqkAyJVL4ZHfB7vYDXj2k5pkHFZ2'
kubectl create secret generic consul-hcp-client-secret --from-literal=client-secret='x'
kubectl create secret generic consul-hcp-observability-client-id --from-literal=client-id='cfeghqkAyJVL4ZHfB7vYDXj2k5pkHFZ2'
kubectl create secret generic consul-hcp-observability-client-secret --from-literal=client-secret='x'
kubectl create secret generic consul-hcp-resource-id --from-literal=resource-id='organization/f785e2d8-b8f5-4676-8675-1e33ad6eb6fe/project/e4065767-bd61-4f00-8b2b-81f631f7d4d1/hashicorp.consul.global-network-manager.cluster/dc2'
kubectl create secret generic consul-bootstrap-token --from-literal=token='6b58b6e5-755d-4d74-aaa1-fb65860c9a0f'

# copy peering token from dc1 to dc2
kubectl delete secret peering-token-dc2 --namespace consul --context kind-dc2
kubectl --context kind-dc1 --namespace consul get secret peering-token-dc2 -o yaml | kubectl --context kind-dc2 --namespace consul apply -f -

# install dc2
helm install dc2 hashicorp/consul --namespace consul --values ./dc2/helm/values.yaml --context kind-dc2
kubectl apply --context kind-dc2 -f ./dc2/resources
```

results: this fails with:

```
2023-11-21T20:52:01.073Z+00:00 [debug] envoy.filter(26) [C63212] Cluster not found server.dc1.peering.45f50773-5004-70c2-37cc-34791f116c52.consul and no on demand cluster set.
2023-11-21T20:52:01.073Z+00:00 [debug] envoy.connection(26) [C63212] closing data_to_write=0 type=1
2023-11-21T20:52:01.073Z+00:00 [debug] envoy.connection(26) [C63212] closing socket: 1
```

upgrade with helm:

```bash
kubectl config use-context kind-dc1
helm upgrade dc1 hashicorp/consul -f ./dc1/helm/values.yaml

kubectl config use-context kind-dc2
helm upgrade dc2 hashicorp/consul -f ./dc2/helm/values.yaml
```
