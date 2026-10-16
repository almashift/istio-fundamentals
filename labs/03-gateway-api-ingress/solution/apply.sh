#!/usr/bin/env bash
set -euo pipefail
kubectl -n meshmart apply -f "$LAB_DIR/solution/solution.yaml"
# Istio creates the meshmart-gateway-istio Deployment asynchronously; wait for it to exist, then to be ready.
for _ in $(seq 1 60); do
  kubectl -n meshmart get deploy meshmart-gateway-istio >/dev/null 2>&1 && break
  sleep 2
done
kubectl -n meshmart rollout status deploy/meshmart-gateway-istio --timeout=180s
