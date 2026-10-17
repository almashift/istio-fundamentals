#!/usr/bin/env bash
# Grades the outcome: every MeshMart pod has a proxy that istiod has configured, new pods
# will join automatically, and the store still serves loadgen's traffic.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/bin/lib.sh"
NS=meshmart
EXPECTED_PODS=6   # web, catalog-v1, catalog-v2, cart, orders, loadgen

apps_ready() { kubectl -n "$NS" wait --for=condition=Available deploy --all --timeout=5s; }

# Pods that are not being deleted, one per line: "<name> <containers and init containers>"
live_pods() {
  kubectl -n "$NS" get pods -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.metadata.deletionTimestamp}{"|"}{.spec.containers[*].name} {.spec.initContainers[*].name}{"\n"}{end}' 2>/dev/null |
    awk -F'|' '$1 !~ / [0-9]/ { print }'
}
namespace_labelled() {
  local labels
  labels="$(kubectl get ns "$NS" -o jsonpath='{.metadata.labels}' 2>/dev/null)" || return 1
  grep -q '"istio-injection":"enabled"' <<<"$labels" || grep -q '"istio.io/rev"' <<<"$labels"
}
all_pods_have_sidecar() {
  local pods missing
  pods="$(live_pods)"
  [ "$(grep -c . <<<"$pods")" -ge "$EXPECTED_PODS" ] || return 1
  missing="$(grep -vc istio-proxy <<<"$pods" || true)"
  [ "$missing" -eq 0 ]
}
proxies_synced() {
  local out count
  out="$(istioctl proxy-status 2>/dev/null)" || return 1
  count="$(grep -c "\.${NS} " <<<"$out" || true)"
  [ "$count" -ge "$EXPECTED_PODS" ] && ! grep "\.${NS} " <<<"$out" | grep -q 'STALE'
}
loadgen() { kubectl -n "$NS" exec deploy/loadgen -c loadgen -- curl -s --max-time 5 "http://localhost:8080/stats$1" 2>/dev/null; }

section "Environment"
check "all MeshMart Deployments are available" apps_ready

section "In the mesh"
check "namespace '$NS' is labelled so new pods join the mesh automatically" namespace_labelled
check "every MeshMart pod runs an istio-proxy sidecar"                      all_pods_have_sidecar
check "istiod has sent configuration to every MeshMart proxy"              proxies_synced

section "Store still working"
# Measure the settled store: wait (up to 60s) for pods from a restart to finish terminating.
for _ in $(seq 1 30); do
  terminating="$(kubectl -n "$NS" get pods -o jsonpath='{range .items[*]}{.metadata.deletionTimestamp}{"\n"}{end}' 2>/dev/null | grep -c . || true)"
  [ "${terminating:-0}" -eq 0 ] && break
  [ "$terminating" != "${shown:-}" ] && note "waiting for $terminating old pod(s) to finish shutting down"
  shown="$terminating"
  sleep 2
done
loadgen "?reset=1" >/dev/null
note "watching loadgen's requests for 15 seconds"
sleep 15
stats="$(loadgen "")"
sent="$(grep -o '"sent": [0-9]*' <<<"$stats" | grep -o '[0-9]*$' || echo 0)"
rate="$(grep -o '"success_rate": [0-9.]*' <<<"$stats" | grep -o '[0-9.]*$' || echo 0)"
if [ "${sent:-0}" -ge 20 ] && awk -v r="${rate:-0}" 'BEGIN { exit !(r >= 99) }'; then
  ok "loadgen: ${rate}% of ${sent} requests succeeded"
else
  bad "loadgen: ${rate:-?}% of ${sent:-0} requests succeeded (need 99% of at least 20)"
fi

summary
