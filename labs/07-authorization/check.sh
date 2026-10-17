#!/usr/bin/env bash
# Grades behaviour: who may call catalog, and with which method.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/bin/lib.sh"
NS=meshmart

apps_ready() { kubectl -n "$NS" wait --for=condition=Available deploy --all --timeout=5s; }
mesh_wide_untouched() { [ -z "$(kubectl -n istio-system get authorizationpolicy -o name 2>/dev/null)" ]; }
analyzer_clean() {
  local out
  out="$(istioctl analyze -n "$NS" 2>&1 || true)"
  ! grep -q 'Error \[' <<<"$out"
}
# call <from> <method> <service> -> HTTP status (000 = no response)
call() {
  kubectl -n "$NS" exec "deploy/$1" -c "$1" -- \
    curl -s -o /dev/null -w '%{http_code}' --max-time 3 -X "$2" "http://$3/" 2>/dev/null || true
}
loadgen_ok() {   # the store as a whole must keep working
  local stats rate
  kubectl -n "$NS" exec deploy/loadgen -c loadgen -- curl -s "localhost:8080/stats?reset=1" >/dev/null 2>&1
  sleep 8
  stats="$(kubectl -n "$NS" exec deploy/loadgen -c loadgen -- curl -s localhost:8080/stats 2>/dev/null)"
  rate="$(grep -o '"success_rate": [0-9.]*' <<<"$stats" | grep -o '[0-9.]*$')"
  awk -v r="${rate:-0}" 'BEGIN { exit !(r >= 99) }'
}

section "Environment"
check "all MeshMart Deployments are available"            apps_ready
check "nothing mesh-wide: no AuthorizationPolicy in istio-system" mesh_wide_untouched
check "istioctl analyze reports no errors"                analyzer_clean

section "Who may call catalog"
attempt=1
while :; do
  wg="$(call web GET catalog)"; wp="$(call web POST catalog)"
  cg="$(call cart GET catalog)"; og="$(call orders GET catalog)"
  if [ "$wg" = 200 ] && [ "$wp" = 403 ] && [ "$cg" = 403 ] && [ "$og" = 403 ]; then break; fi
  # A new policy reaches the sidecars within seconds, but requests on connections opened
  # before it (e.g. by an earlier `lab check`) can still get through while Envoy drains
  # them. Once a policy is clearly in place (web GET allowed, POST denied), wait up to
  # ~1 minute for that; otherwise give up after 3 tries.
  if [ "$wg" = 200 ] && [ "$wp" = 403 ]; then max=12; else max=3; fi
  [ "$attempt" -ge "$max" ] && break
  attempt=$((attempt + 1)); sleep 5
done
expect() { if [ "$1" = "$2" ]; then ok "$3"; else bad "$3 (got ${1:-no response}, expected $2)"; fi; }
expect "$wg" 200 "web    GET  catalog -> allowed (200)"
expect "$wp" 403 "web    POST catalog -> denied (403)"
expect "$cg" 403 "cart   GET  catalog -> denied (403)"
expect "$og" 403 "orders GET  catalog -> denied (403)"
check "the store still works for shoppers (loadgen 99%+ success)" loadgen_ok

summary
