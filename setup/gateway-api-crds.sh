#!/usr/bin/env bash
# Idempotent: makes sure the Gateway API CRDs (standard channel, GATEWAY_API_VERSION) are installed.
# Keep GATEWAY_API_VERSION in step with ISTIO_VERSION: use the gateway-api version in that
# Istio release's go.mod (1.27.x -> v1.3.0).
# Run it BEFORE installing istiod. If istiod is already running when the CRDs are (re)installed,
# istiod is restarted so its Gateway API controller is guaranteed to see them.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/versions.env"

installed="$(kubectl get crd gateways.gateway.networking.k8s.io \
  -o jsonpath='{.metadata.annotations.gateway\.networking\.k8s\.io/bundle-version}' 2>/dev/null || true)"
if [ "$installed" = "$GATEWAY_API_VERSION" ]; then
  echo ">> Gateway API CRDs ${GATEWAY_API_VERSION} already installed"
  exit 0
fi

echo ">> Installing Gateway API CRDs ${GATEWAY_API_VERSION} (found: ${installed:-none})"
kubectl apply --server-side --force-conflicts \
  -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/standard-install.yaml"
kubectl wait --for=condition=Established --timeout=120s \
  crd/gatewayclasses.gateway.networking.k8s.io \
  crd/gateways.gateway.networking.k8s.io \
  crd/httproutes.gateway.networking.k8s.io

if kubectl -n istio-system get deploy istiod >/dev/null 2>&1; then
  echo ">> Restarting istiod so it picks up the Gateway API CRDs"
  kubectl -n istio-system rollout restart deploy/istiod
  kubectl -n istio-system rollout status deploy/istiod --timeout=300s
fi
