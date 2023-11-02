#!/bin/sh

NAMESPACE=dmetrics

# install prometheus and grafana
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/prometheus -f ./charts/prometheus.yaml -n "$NAMESPACE"
helm install grafana grafana/grafana -f ./charts/grafana.yaml -n "$NAMESPACE"

# install consul
consul-k8s install -auto-approve -verbose -f ./charts/consul.yaml -n "$NAMESPACE" -wait

# install demo app
kubectl apply -f ./resources/ -n "$NAMESPACE"

# open prometheus
export POD_NAME=$(kubectl get pods --namespace $NAMESPACE -l "app.kubernetes.io/name=prometheus,app.kubernetes.io/instance=prometheus" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace $NAMESPACE port-forward $POD_NAME 9090

# open grafana
export POD_NAME=$(kubectl get pods --namespace $NAMESPACE -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=grafana" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace $NAMESPACE port-forward $POD_NAME 3000
