# deny-metrics

Which metrics can we use to monitor denied requests from downstream proxies to upstreams?

For deny intentions and/or a cluster's [`acl.default_policy`](https://developer.hashicorp.com/consul/docs/agent/config/config-files#acl_default_policy).

## Background

- https://github.com/hashicorp-education/learn-consul-hashiconf-2023/tree/main
- https://developer.hashicorp.com/consul/docs/agent/config/config-files#acl_default_policy
- https://www.envoyproxy.io/docs/envoy/latest/configuration/upstream/cluster_manager/cluster_stats

## Set up

```bash
NAMESPACE=dmetrics

kubectl create namespace $NAMESPACE

# install prometheus and grafana
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/prometheus -f ./helm/prometheus.yaml -n "$NAMESPACE"
helm install grafana grafana/grafana -f ./helm/grafana.yaml -n "$NAMESPACE"

# install consul
consul-k8s install -auto-approve -verbose -f ./helm/consul.yaml --namespace "$NAMESPACE" -wait

# install demo app
kubectl apply -f ./resources/ -n "$NAMESPACE"
```

```bash
# open prometheus
export POD_NAME=$(kubectl get pods --namespace $NAMESPACE -l "app.kubernetes.io/name=prometheus,app.kubernetes.io/instance=prometheus" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace $NAMESPACE port-forward $POD_NAME 9090

open localhost:9090

# open grafana
export POD_NAME=$(kubectl get pods --namespace $NAMESPACE -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=grafana" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace $NAMESPACE port-forward $POD_NAME 3000

open localhost:3000
```

## Results

### deny-all

Metrics where calls were never allowed in the first place.

#### 403 status codes

```
kubectl logs a-b8c4bd8c4-7v587 -n dmetrics -c consul-dataplane

2023-11-02T03:12:59.204Z+00:00 [debug] envoy.http(31) [C2721][S16888789398560503235] encoding headers via codec (end_stream=false):
':status', '403'
'content-length', '19'
'content-type', 'text/plain'
'date', 'Thu, 02 Nov 2023 03:12:58 GMT'
'server', 'envoy'
'x-envoy-upstream-service-time', '1'
```

#### envoy_cluster_upstream_rq_xx{envoy_response_code_class="4"}

```
rate(envoy_cluster_upstream_rq_xx{consul_destination_service!=""}[5m:])
```

> {app="a", consul_destination_datacenter="dc1", consul_destination_full_target="b.default.dc1.internal.507b776e-1a6e-f754-c542-488c03a3b35f", consul_destination_namespace="default", consul_destination_routing_type="internal", consul_destination_service="b", consul_destination_target="b.default.dc1", consul_destination_trust_domain="507b776e-1a6e-f754-c542-488c03a3b35f", consul_hashicorp_com_connect_inject_managed_by="consul-k8s-endpoints-controller", consul_hashicorp_com_connect_inject_status="injected", consul_source_datacenter="dc1", consul_source_namespace="default", consul_source_partition="default", consul_source_service="a", envoy_cluster_name="b", envoy_response_code_class="4", instance="10.244.0.24:20200", job="kubernetes-pods", local_cluster="a", namespace="dmetrics", node="kind-control-plane", pod="a-b8c4bd8c4-7v587", pod_template_hash="b8c4bd8c4"}

#### envoy_http_rbac_denied

RBAC denied metrics are incremented, but they're from the upstream listener and are not annotated with the downstream service.

```
rate(envoy_http_rbac_denied[5m:])
```

> {app="b", consul_hashicorp_com_connect_inject_managed_by="consul-k8s-endpoints-controller", consul_hashicorp_com_connect_inject_status="injected", consul_source_datacenter="dc1", consul_source_namespace="default", consul_source_partition="default", consul_source_service="b", envoy_http_conn_manager_prefix="public_listener", instance="10.244.0.25:20200", job="kubernetes-pods", local_cluster="b", namespace="dmetrics", node="kind-control-plane", pod="b-66cbd46467-6z2dg", pod_template_hash="66cbd46467"}

### allow-all > deny-all

## Learnings

Consul has an internal cluster ID (UUID) that's mapped to consul_destination_trust_domain: https://github.com/hashicorp/consul/issues/6142
