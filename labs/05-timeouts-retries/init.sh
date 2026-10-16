#!/usr/bin/env bash
# Starting state: MeshMart in the mesh; 1 in 5 catalog requests hangs for 10 seconds.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
bash "$ROOT/setup/meshmart.sh" --mesh
kubectl -n meshmart set env deploy/catalog-v1 deploy/catalog-v2 DELAY=10s DELAY_PERCENT=20
kubectl -n meshmart rollout status deploy/catalog-v1 --timeout=180s
kubectl -n meshmart rollout status deploy/catalog-v2 --timeout=180s
