#!/usr/bin/env bash
set -euo pipefail
NS=meshmart
# Fault 1: point the route at the real host.
kubectl -n "$NS" apply -f "$LAB_DIR/solution/solution.yaml"
# Fault 2: remove the opt-out label; the rollout recreates cart's pod with a sidecar.
kubectl -n "$NS" patch deploy cart --type=json \
  -p '[{"op":"remove","path":"/spec/template/metadata/labels/sidecar.istio.io~1inject"}]'
kubectl -n "$NS" rollout status deploy/cart --timeout=180s
sleep 5
