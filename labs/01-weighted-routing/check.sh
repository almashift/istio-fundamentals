#!/usr/bin/env bash
# Grades behaviour on the wire, not just "did a YAML object get created".
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/bin/lib.sh"

NS=lab01
REQUESTS=200
MIN_V2=$((REQUESTS * 10 / 100))   # v2 share must land between 10% ...
MAX_V2=$((REQUESTS * 30 / 100))   # ... and 30% (wide enough to avoid false failures)

apps_ready()        { kubectl -n "$NS" wait --for=condition=Available deploy --all --timeout=5s; }
sidecar_injected()  { kubectl -n "$NS" get pod -l app=client \
                        -o jsonpath='{.items[0].spec.containers[*].name} {.items[0].spec.initContainers[*].name}' \
                        | grep -q istio-proxy; }
replicas_unchanged() {
  [ "$(kubectl -n "$NS" get deploy echo-v1 -o jsonpath='{.spec.replicas}')" = "1" ] &&
  [ "$(kubectl -n "$NS" get deploy echo-v2 -o jsonpath='{.spec.replicas}')" = "1" ]
}
service_unchanged() { [ "$(kubectl -n "$NS" get svc echo -o jsonpath='{.spec.selector}')" = '{"app":"echo"}' ]; }
analyzer_clean()    { ! istioctl analyze -n "$NS" 2>&1 | grep -q 'Error \['; }

measure() {
  kubectl -n "$NS" exec deploy/client -c client -- sh -c \
    "i=0; while [ \$i -lt $REQUESTS ]; do curl -s --max-time 2 http://echo/ || echo FAIL; i=\$((i+1)); done" 2>/dev/null || true
}

section "Environment"
check "echo-v1, echo-v2 and client are running"  apps_ready
check "client pod has the Istio sidecar"          sidecar_injected

section "Rules respected"
check "Deployments still have 1 replica each (no scaling tricks)" replicas_unchanged
check "Service 'echo' selector unchanged"                         service_unchanged
check "istioctl analyze reports no errors"                        analyzer_clean

section "Traffic behaviour ($REQUESTS requests from the client pod)"
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
  ok "split looks like 80/20 (v1=$v1, v2=$v2)"
else
  bad "split is not ~80/20 (v1=$v1, v2=$v2; expected v2 between $MIN_V2 and $MAX_V2)"
fi

summary
