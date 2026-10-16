#!/usr/bin/env bash
# Starting state: MeshMart in the mesh, then two faults the student has to find:
#   1. a VirtualService for catalog that routes to a host that doesn't exist
#   2. cart opted out of sidecar injection, so it is no longer in the mesh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
bash "$ROOT/setup/meshmart.sh" --mesh
kubectl -n meshmart apply -f "$(dirname "${BASH_SOURCE[0]}")/broken.yaml"
kubectl -n meshmart patch deploy cart --type=merge \
  -p '{"spec":{"template":{"metadata":{"labels":{"sidecar.istio.io/inject":"false"}}}}}'
kubectl -n meshmart rollout status deploy/cart --timeout=180s
