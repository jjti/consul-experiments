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

helm install consul hashicorp/consul -f ./helm/consul.yaml
```
