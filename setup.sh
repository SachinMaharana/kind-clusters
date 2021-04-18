#!/bin/bash

k() {
    kubectl --context kind-opa "$@"
}

kind create cluster --name opa --config kind-config.yaml

k apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/kind/deploy.yaml

sleep "10"

k wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector="app.kubernetes.io/component=controller" \
  --timeout=180s
