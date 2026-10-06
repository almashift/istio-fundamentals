#!/usr/bin/env bash
# Build the STARTING state from scratch. Must be idempotent (safe to run repeatedly).
set -euo pipefail
NS=labNN
kubectl delete ns "$NS" --ignore-not-found --wait=true
kubectl create ns "$NS"
# kubectl label ns "$NS" istio-injection=enabled
# kubectl -n "$NS" apply -f "$LAB_DIR/manifests/app.yaml"
# kubectl -n "$NS" wait --for=condition=Available deploy --all --timeout=300s
