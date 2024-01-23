# Agent Envoy

Configuring Envoy via Consul Agents to push metrics to a Consul Telemetry Collector in an adjacent K8s cluster.

```bash
# install dependencies (from https://developer.hashicorp.com/consul/tutorials/developer-mesh/service-mesh-with-envoy-proxy)
wget -O counting-service.zip https://github.com/hashicorp/demo-consul-101/releases/download/0.0.3.1/counting-service_darwin_amd64.zip
unzip counting-service.zip
mv counting-service_darwin_amd64 counting-service
wget -O dashboard-service.zip https://github.com/hashicorp/demo-consul-101/releases/download/0.0.3.1/dashboard-service_darwin_amd64.zip
unzip dashboard-service.zip
mv dashboard-service_darwin_amd64 dashboard-service

# install envoy
curl -L https://func-e.io/install.sh | sudo bash -s -- -b /usr/local/bin
export ENVOY_VERSION_STRING='1.24'
export FUNC_E_PLATFORM=darwin/amd64
func-e use $ENVOY_VERSION_STRING
sudo cp ~/.func-e/versions/$ENVOY_VERSION_STRING/bin/envoy /usr/local/bin/

# create kind cluster
kind create cluster --name server
kubectl config set-context kind-server --namespace consul
kubectl config use-context kind-server
kubectl create namespace consul

# create secrets
CLIENT_ID=''
CLIENT_SECRET=''
RESOURCE=''
TOKEN='6b58b6e5-755d-4d74-aaa1-fb65860c9a0f'
export CONSUL_LICENSE=$(op read "op://Cloud/consul-license/dev/license" --account hashicorp.1password.com)
kubectl create secret generic consul-license --from-literal="license=${CONSUL_LICENSE}"
kubectl create secret generic consul-hcp-client-id --from-literal=client-id="$CLIENT_ID"
kubectl create secret generic consul-hcp-client-secret --from-literal=client-secret="$CLIENT_SECRET"
kubectl create secret generic consul-hcp-observability-client-id --from-literal=client-id="$CLIENT_ID"
kubectl create secret generic consul-hcp-observability-client-secret --from-literal=client-secret="$CLIENT_SECRET"
kubectl create secret generic consul-hcp-resource-id --from-literal=resource-id="$RESOURCE"
kubectl create secret generic consul-bootstrap-token --from-literal=token="$TOKEN" --namespace consul
# kubectl delete secret consul-hcp-client-id consul-hcp-client-secret consul-hcp-observability-client-id consul-hcp-observability-client-secret consul-hcp-resource-id

# start consul and consul-telemetry-collector
helm install server hashicorp/consul --namespace consul --values ./agent-envoy/helm/consul.yaml
# helm upgrade server hashicorp/consul --namespace consul --values ./agent-envoy/helm/consul.yaml

# expose consul
kubectl port-forward service/server-consul-server '8501:8501'
kubectl port-forward service/server-consul-server '8502:8502'

# expose consul-telemetry-collector
kubectl port-forward service/consul-telemetry-collector '9356:9356'

export CONSUL_HTTP_SSL_VERIFY=false
export CONSUL_HTTP_ADDR=https://localhost:8501
export CONSUL_HTTP_TOKEN="$TOKEN"

# create a default envoy metrics config
# https://github.com/hashicorp/consul/blob/995ba32cc0882b407c89a1b9d126532a1097e45d/command/connect/envoy/bootstrap_config.go#L853
cat >/tmp/proxy-defaults.hcl <<EOF
Kind      = "proxy-defaults"
Name      = "global"
Config {
    envoy_stats_flush_interval = "60s"

    envoy_extra_static_clusters_json = <<EOT
        {
            "name": "consul_telemetry_collector",
            "type": "STATIC",
            "typed_extension_protocol_options": {
                "envoy.extensions.upstreams.http.v3.HttpProtocolOptions": {
                    "@type": "type.googleapis.com/envoy.extensions.upstreams.http.v3.HttpProtocolOptions",
                    "explicit_http_config": {
                        "http2_protocol_options": {}
                    }
                }
            },
            "load_assignment": {
                "cluster_name": "consul_telemetry_collector",
                "endpoints": [
                    {
                        "lb_endpoints": [
                            {
                                "endpoint": {
                                    "address": {
                                        "socket_address": {
                                            "address": "127.0.0.1",
                                            "port_value": 9356
                                        }
                                    }
                                }
                            }
                        ]
                    }
                ]
            }
        }
EOT

    envoy_extra_stats_sinks_json = <<EOT
        {
          "name": "envoy.stat_sinks.metrics_service",
          "typed_config": {
            "@type": "type.googleapis.com/envoy.config.metrics.v3.MetricsServiceConfig",
            "grpc_service": {
                "envoy_grpc": {
                    "cluster_name": "consul_telemetry_collector"
                }
            },
            "transport_api_version": "V3",
            "emit_tags_as_labels": true
          }
        }
EOT
}
EOF
consul config write /tmp/proxy-defaults.hcl
# consul config delete -kind proxy-defaults -name global

# create an intention allowing metric pushing to the consul-telemetry-collector
cat <<EOF | kubectl apply --namespace consul --filename -
apiVersion: consul.hashicorp.com/v1alpha1
kind: ServiceIntentions
metadata:
  name: consul-telemetry-collector
spec:
  destination:
    name: consul-telemetry-collector
  sources:
  - action: allow
    name: '*'
EOF

cat >/tmp/intention.hcl <<EOF
Kind = "service-intentions"
Name = "counting"
Sources = [
  {
    Name   = "dashboard"
    Action = "allow"
  }
]
EOF
consul config write /tmp/intention.hcl

# register counting service
cat >/tmp/counting.hcl <<EOF
service {
  name = "counting"
  id = "counting-1"
  port = 9003

  connect {
    sidecar_service {}
  }
}
EOF
consul services register /tmp/counting.hcl
# consul services deregister -id counting-1

# register dashboard service
cat >/tmp/dashboard.hcl <<EOF
service {
  name = "dashboard"
  port = 9002

  connect {
    sidecar_service {
      proxy {
        upstreams = [
          {
            destination_name   = "counting"
            local_bind_port    = 9163
            local_bind_address = "127.0.0.1"
          }
        ]
      }
    }
  }
}
EOF
consul services register /tmp/dashboard.hcl
# consul services deregister -id dashboard

# start dashboard service
PORT=9002 COUNTING_SERVICE_URL="http://localhost:9163" ./dashboard-service

# start counting service
PORT=9003 ./counting-service

# start envoy proxies
consul connect envoy -sidecar-for counting-1 -admin-bind localhost:19001 2> counting-proxy.log
consul connect envoy -sidecar-for dashboard 2> dashboard-proxy.log

```

Useful links:

- where we do this in consul for consul-dataplane: https://github.com/hashicorp/consul/blob/995ba32cc0882b407c89a1b9d126532a1097e45d/command/connect/envoy/bootstrap_config.go#L853
- https://developer.hashicorp.com/consul/docs/connect/proxies/envoy#envoy_extra_static_clusters_json
- https://developer.hashicorp.com/consul/docs/connect/proxies/deploy-sidecar-services
- https://developer.hashicorp.com/consul/tutorials/developer-mesh/service-mesh-with-envoy-proxy
