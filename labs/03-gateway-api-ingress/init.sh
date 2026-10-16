#!/usr/bin/env bash
# Starting state: MeshMart in the mesh, no ingress; a `visitor` pod outside the mesh.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/versions.env"
# Older clusters were built without the Gateway API CRDs; install them (and restart istiod) if missing.
bash "$ROOT/setup/gateway-api-crds.sh"
bash "$ROOT/setup/meshmart.sh" --mesh
sed "s|MESHMART_IMAGE|${MESHMART_IMAGE}|g" "$(dirname "${BASH_SOURCE[0]}")/visitor.yaml" | kubectl -n meshmart apply -f -
kubectl -n meshmart wait --for=condition=Available deploy/visitor --timeout=300s
