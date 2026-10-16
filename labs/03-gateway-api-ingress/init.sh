#!/usr/bin/env bash
set -euo pipefail
NS=lab03
ROOT="$(cd "$LAB_DIR/../.." && pwd)"
# Older clusters were built without the Gateway API CRDs; install them (and restart istiod) if missing.
bash "$ROOT/setup/gateway-api-crds.sh"
kubectl delete ns "$NS" --ignore-not-found --wait=true
kubectl create ns "$NS"
kubectl label ns "$NS" istio-injection=enabled
kubectl -n "$NS" apply -f "$LAB_DIR/manifests/app.yaml"
kubectl -n "$NS" wait --for=condition=Available deploy --all --timeout=300s
