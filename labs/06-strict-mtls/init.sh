#!/usr/bin/env bash
# Starting state: MeshMart in the mesh (default PERMISSIVE mTLS) plus `reports`, outside the mesh.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/versions.env"
bash "$ROOT/setup/meshmart.sh" --mesh
sed "s|MESHMART_IMAGE|${MESHMART_IMAGE}|g" "$(dirname "${BASH_SOURCE[0]}")/reports.yaml" | kubectl -n meshmart apply -f -
kubectl -n meshmart wait --for=condition=Available deploy/reports --timeout=300s
