#!/usr/bin/env bash
# Installs Istio's observability add-ons (Prometheus, Kiali, Grafana, Jaeger) from the
# samples of the pinned Istio release, and sends a trace of every request to Jaeger.
#   bash setup/addons.sh            install
#   bash setup/addons.sh --delete   remove them again
# NOT needed for any lab, and NOT sized for the 2-core budget: use it on a bigger machine
# (e.g. a 4-core Codespace) to explore what the videos show.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/versions.env"
BASE="https://raw.githubusercontent.com/istio/istio/${ISTIO_VERSION}/samples/addons"
ADDONS=(prometheus kiali grafana jaeger)

if [ "${1:-}" = "--delete" ]; then
  for a in "${ADDONS[@]}"; do kubectl delete -f "$BASE/$a.yaml" --ignore-not-found; done
  # Undo the tracing settings below (the lines this script added to the mesh config).
  mesh="$(kubectl -n istio-system get configmap istio -o jsonpath='{.data.mesh}' |
    sed -e '/^extensionProviders:$/,$d' -e '/^  tracing:$/{N;/sampling: 100\|- jaeger/d}')"
  kubectl -n istio-system create configmap istio --from-literal=mesh="$mesh" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  exit 0
fi

for a in "${ADDONS[@]}"; do
  echo ">> Installing $a"
  kubectl apply -f "$BASE/$a.yaml" >/dev/null
done
# Istio sends traces nowhere by default. In the mesh config (the `istio` ConfigMap, which
# istiod reloads by itself): register Jaeger's OpenTelemetry port as a provider, make it the
# default tracing provider, and trace every request (the default samples 1%), so a single
# click on the store page shows up in Jaeger.
# Not a Telemetry resource on purpose: Istio honours only one selector-less Telemetry in
# istio-system, and lesson 2.3 / lab 02 create their own there for access logs.
# (A later `istioctl install` rewrites the ConfigMap; just run this script again.)
mesh="$(kubectl -n istio-system get configmap istio -o jsonpath='{.data.mesh}')"
if ! grep -q 'name: jaeger' <<<"$mesh"; then
  mesh="$(sed -e 's/^defaultConfig:$/defaultConfig:\n  tracing:\n    sampling: 100/' \
              -e 's/^defaultProviders:$/defaultProviders:\n  tracing:\n  - jaeger/' <<<"$mesh")
extensionProviders:
- name: jaeger
  opentelemetry:
    service: jaeger-collector.istio-system.svc.cluster.local
    port: 4317"
  kubectl -n istio-system create configmap istio --from-literal=mesh="$mesh" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  # The sampling rate is read when a proxy starts: restart MeshMart if it's running.
  if kubectl get namespace meshmart >/dev/null 2>&1; then
    sleep 5; kubectl -n meshmart rollout restart deploy >/dev/null
  fi
fi
for d in kiali prometheus grafana jaeger; do
  kubectl -n istio-system rollout status deploy/"$d" --timeout=300s
done
echo ">> Add-ons ready. Open one with: istioctl dashboard kiali   (or prometheus, grafana, jaeger)"
