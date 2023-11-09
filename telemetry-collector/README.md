# Telemetry Collector

## Set up

```bash
# everything below is copy/pasted from the UI during linking of an existing cluster
kubectl create secret generic consul-hcp-client-id --from-literal=client-id=''
kubectl create secret generic consul-hcp-client-secret --from-literal=client-secret=''
kubectl create secret generic consul-hcp-observability-client-id --from-literal=client-id=''
kubectl create secret generic consul-hcp-observability-client-secret --from-literal=client-secret=''
kubectl create secret generic consul-hcp-resource-id --from-literal=resource-id=''

# https://developer.hashicorp.com/consul/docs/k8s/deployment-configurations/consul-enterprise
CONSUL_LICENSE=
kubectl create secret generic consul-ent-license --from-literal="license=${CONSUL_LICENSE}"
kubectl create secret generic consul-bootstrap-token --from-literal="token=c6443ead-d245-4ffa-96e6-f30c8e911ab8"

# install consul
helm install consul hashicorp/consul -f ./helm/consul.yaml

# install Consul Telemetry Collector
k apply -f ./resources/consul-telemetry-collector.yaml
```

Or to install with consul-k8s:

```bash
consul-k8s install -f ./helm/consul.yaml --namespace default
```

## Modified Template

```bash
helm template -s templates/telemetry-collector-deployment.yaml -f /Users/josh/GitHub/jjti/consul-exp/telemetry-collector/helm/consul.yaml --set 'telemetryCollector.enabled=true' --set 'global.adminPartitions.enabled=true' --set 'global.enableConsulNamespaces=true' --set 'connectInject.consulNamespaces.mirroringK8S=true' --namespace test-namespace . > /tmp/telem.yaml
```
