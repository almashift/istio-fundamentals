#!/usr/bin/env bash
# Installs Istio into the current cluster. ISTIO_MODE=sidecar (default) | ambient
# Resource requests are deliberately small so the whole stack fits on the smallest
# GitHub Codespaces machine (2 vCPU / 8 GB). Istio's defaults (istiod 500m CPU / 2Gi,
# each sidecar 100m CPU) would eat most of a 2-core node.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/versions.env"
MODE="${ISTIO_MODE:-sidecar}"

case "$MODE" in
  sidecar)
    # "minimal" = istiod only. Labs add gateways themselves when a task needs them.
    echo ">> Installing Istio ${ISTIO_VERSION} (sidecar mode, profile=minimal, small-machine resources)"
    istioctl install -y --set profile=minimal \
      --set components.pilot.k8s.resources.requests.cpu=100m \
      --set components.pilot.k8s.resources.requests.memory=256Mi \
      --set values.global.proxy.resources.requests.cpu=10m \
      --set values.global.proxy.resources.requests.memory=48Mi \
      --set values.global.proxy.resources.limits.cpu=200m \
      --set values.global.proxy.resources.limits.memory=256Mi
    ;;
  ambient)
    # NOTE: not yet slimmed or tested on a 2-core machine. ztunnel (per node) and istio-cni
    # request more by default, so expect this mode to be tighter than sidecar mode.
    echo ">> Installing Istio ${ISTIO_VERSION} (ambient mode, default resources)"
    if ! kubectl get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1; then
      kubectl apply -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/standard-install.yaml"
    fi
    istioctl install --set profile=ambient -y
    ;;
  *) echo "Unknown ISTIO_MODE '$MODE' (use sidecar or ambient)" >&2; exit 1 ;;
esac

kubectl -n istio-system rollout status deploy/istiod --timeout=300s
echo ">> Istio is ready."
