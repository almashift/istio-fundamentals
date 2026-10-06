#!/usr/bin/env bash
# Installs Istio into the current cluster. ISTIO_MODE=sidecar (default) | ambient
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/versions.env"
MODE="${ISTIO_MODE:-sidecar}"

case "$MODE" in
  sidecar)
    # "minimal" = istiod only. Labs add gateways themselves when a task needs them.
    echo ">> Installing Istio ${ISTIO_VERSION} (sidecar mode, profile=minimal)"
    istioctl install --set profile=minimal -y
    ;;
  ambient)
    echo ">> Installing Istio ${ISTIO_VERSION} (ambient mode)"
    if ! kubectl get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1; then
      kubectl apply -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/standard-install.yaml"
    fi
    istioctl install --set profile=ambient -y
    ;;
  *) echo "Unknown ISTIO_MODE '$MODE' (use sidecar or ambient)" >&2; exit 1 ;;
esac

kubectl -n istio-system rollout status deploy/istiod --timeout=180s
echo ">> Istio is ready."
