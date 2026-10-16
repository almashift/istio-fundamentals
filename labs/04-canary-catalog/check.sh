#!/usr/bin/env bash
# Grades behaviour on the wire, not just "did a YAML object get created".
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/bin/lib.sh"

NS=meshmart
REQUESTS=200
MIN_V2=$((REQUESTS * 4 / 100))    # v2 share must land between 4% ...
MAX_V2=$((REQUESTS * 18 / 100))   # ... and 18% (wide enough to avoid false failures)

apps_ready() { kubectl -n "$NS" wait --for=condition=Available deploy --all --timeout=5s; }
# NOTE: capture output first, then grep. `cmd | grep -q` under pipefail can fail with SIGPIPE.
web_in_mesh() {
  local out
  out="$(kubectl -n "$NS" get pod -l app=web \
         -o jsonpath='{.items[0].spec.containers[*].name} {.items[0].spec.initContainers[*].name}' 2>/dev/null)" || return 1
  grep -q istio-proxy <<<"$out"
}
replicas_unchanged() {
  [ "$(kubectl -n "$NS" get deploy catalog-v1 -o jsonpath='{.spec.replicas}')" = "1" ] &&
  [ "$(kubectl -n "$NS" get deploy catalog-v2 -o jsonpath='{.spec.replicas}')" = "1" ]
}
service_unchanged() { [ "$(kubectl -n "$NS" get svc catalog -o jsonpath='{.spec.selector}')" = '{"app":"catalog"}' ]; }
analyzer_clean() {
  local out
  out="$(istioctl analyze -n "$NS" 2>&1 || true)"
  ! grep -q 'Error \[' <<<"$out"
}

# Ask catalog for its version, as web would. MeshMart answers /version with "v1" or "v2".
measure() {
  kubectl -n "$NS" exec deploy/web -c web -- sh -c \
    "i=0; while [ \$i -lt $REQUESTS ]; do curl -s --max-time 2 http://catalog/version || echo FAIL; i=\$((i+1)); done" 2>/dev/null || true
}

section "Environment"
check "catalog v1, catalog v2 and web are running" apps_ready
check "web pod has the Istio sidecar"              web_in_mesh

section "Rules respected"
check "catalog Deployments still have 1 replica each (no scaling tricks)" replicas_unchanged
check "Service 'catalog' selector unchanged"                              service_unchanged
check "istioctl analyze reports no errors"                                analyzer_clean

section "Traffic behaviour ($REQUESTS requests from web to catalog)"
attempt=1; v1=0; v2=0; fails=0
while [ "$attempt" -le 3 ]; do
  out="$(measure)"
  v1=$(grep -cx 'v1' <<<"$out" || true)
  v2=$(grep -cx 'v2' <<<"$out" || true)
  fails=$(grep -cx 'FAIL' <<<"$out" || true)
  if [ "$fails" -eq 0 ] && [ "$v2" -ge "$MIN_V2" ] && [ "$v2" -le "$MAX_V2" ]; then break; fi
  attempt=$((attempt + 1)); [ "$attempt" -le 3 ] && sleep 4   # config may still be propagating
done

if [ "$fails" -eq 0 ] && [ $((v1 + v2)) -eq "$REQUESTS" ]; then
  ok "all $REQUESTS requests succeeded"
else
  bad "some requests failed ($fails errors, $((v1 + v2)) of $REQUESTS answered)"
fi
if [ "$v2" -ge "$MIN_V2" ] && [ "$v2" -le "$MAX_V2" ]; then
  ok "split looks like 90/10 (v1=$v1, v2=$v2)"
else
  bad "split is not ~90/10 (v1=$v1, v2=$v2; expected v2 between $MIN_V2 and $MAX_V2)"
fi

summary
