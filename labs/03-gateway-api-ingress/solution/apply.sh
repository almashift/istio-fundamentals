#!/usr/bin/env bash
set -euo pipefail
kubectl -n lab03 apply -f "$LAB_DIR/solution/solution.yaml"
# Istio creates the edge-istio Deployment asynchronously; wait for it to exist, then to be ready.
for _ in $(seq 1 60); do
  kubectl -n lab03 get deploy edge-istio >/dev/null 2>&1 && break
  sleep 2
done
kubectl -n lab03 rollout status deploy/edge-istio --timeout=180s
