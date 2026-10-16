#!/usr/bin/env bash
# (Re)deploys MeshMart from scratch into the `meshmart` namespace.
#   bash setup/meshmart.sh --mesh      namespace labelled for sidecar injection (the usual start)
#   bash setup/meshmart.sh --no-mesh   plain Kubernetes, nothing in the mesh yet
# Labs call this from init.sh, then add their own starting-state changes on top.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/versions.env"
NS=meshmart

case "${1:---mesh}" in
  --mesh)    MESH=1 ;;
  --no-mesh) MESH=0 ;;
  *) echo "usage: $0 [--mesh|--no-mesh]" >&2; exit 1 ;;
esac

kubectl delete ns "$NS" --ignore-not-found --wait=true
kubectl create ns "$NS"
if [ "$MESH" = 1 ]; then kubectl label ns "$NS" istio-injection=enabled; fi
sed "s|MESHMART_IMAGE|${MESHMART_IMAGE}|g" "$ROOT/meshmart/manifests/meshmart.yaml" | kubectl -n "$NS" apply -f -
kubectl -n "$NS" wait --for=condition=Available deploy --all --timeout=300s
