#!/usr/bin/env bash
# Installs Istio's observability add-ons (Prometheus, Kiali, Grafana, Jaeger) from the
# samples of the pinned Istio release, and samples every request for tracing.
#   bash setup/addons.sh            install
#   bash setup/addons.sh --delete   remove them again
# NOT needed for any lab, and NOT sized for the 2-core budget: use it on a bigger machine
# (e.g. a Dev Container on your laptop) to explore what the videos show.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/versions.env"
BASE="https://raw.githubusercontent.com/istio/istio/${ISTIO_VERSION}/samples/addons"
ADDONS=(prometheus kiali grafana jaeger)

if [ "${1:-}" = "--delete" ]; then
  for a in "${ADDONS[@]}"; do kubectl delete -f "$BASE/$a.yaml" --ignore-not-found; done
  kubectl -n istio-system delete telemetry trace-everything --ignore-not-found
  exit 0
fi

for a in "${ADDONS[@]}"; do
  echo ">> Installing $a"
  kubectl apply -f "$BASE/$a.yaml" >/dev/null
done
# Trace every request (the default samples 1%), so a single click shows up in Jaeger.
kubectl apply -f - <<'EOF'
apiVersion: telemetry.istio.io/v1
kind: Telemetry
metadata:
  name: trace-everything
  namespace: istio-system
spec:
  tracing:
    - randomSamplingPercentage: 100
EOF
for d in kiali prometheus grafana jaeger; do
  kubectl -n istio-system rollout status deploy/"$d" --timeout=300s
done
echo ">> Add-ons ready. Open one with: istioctl dashboard kiali   (or prometheus, grafana, jaeger)"
