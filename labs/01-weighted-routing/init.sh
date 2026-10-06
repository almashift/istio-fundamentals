#!/usr/bin/env bash
set -euo pipefail
NS=lab01
kubectl delete ns "$NS" --ignore-not-found --wait=true
kubectl create ns "$NS"
kubectl label ns "$NS" istio-injection=enabled
kubectl -n "$NS" apply -f "$LAB_DIR/manifests/app.yaml"
kubectl -n "$NS" wait --for=condition=Available deploy --all --timeout=300s
