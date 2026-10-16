#!/usr/bin/env bash
# Grades behaviour: who can talk to whom, with and without mTLS.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/bin/lib.sh"

NS=meshmart

apps_ready()  { kubectl -n "$NS" wait --for=condition=Available deploy --all --timeout=5s; }
# NOTE: capture output first, then grep. `cmd | grep -q` under pipefail can fail with SIGPIPE.
has_sidecar() {
  local out
  out="$(kubectl -n "$NS" get pod -l "app=$1" \
         -o jsonpath='{.items[0].spec.containers[*].name} {.items[0].spec.initContainers[*].name}' 2>/dev/null)" || return 1
  grep -q istio-proxy <<<"$out"
}
no_sidecar()  { ! has_sidecar "$1"; }
no_authz_policies()   { [ -z "$(kubectl -n "$NS" get authorizationpolicy -o name 2>/dev/null)" ]; }
mesh_wide_untouched() { [ -z "$(kubectl -n istio-system get peerauthentication -o name 2>/dev/null)" ]; }
ns_wide_strict() {
  local out
  out="$(kubectl -n "$NS" get peerauthentication \
         -o jsonpath='{range .items[*]}{.spec.selector}{"|"}{.spec.mtls.mode}{"\n"}{end}' 2>/dev/null)" || return 1
  grep -qx '|STRICT' <<<"$out"
}
analyzer_clean() {
  local out
  out="$(istioctl analyze -n "$NS" 2>&1 || true)"
  ! grep -q 'Error \[' <<<"$out"
}

# req <client-deployment> <service>  -> HTTP status; 000 means no HTTP response (connection rejected)
req() {
  kubectl -n "$NS" exec "deploy/$1" -c "$1" -- \
    curl -s -o /dev/null -w '%{http_code}' --max-time 3 "http://$2/" 2>/dev/null || true
}

section "Environment is intact"
check "all workloads are running"                       apps_ready
check "catalog has a sidecar"                           has_sidecar catalog
check "orders has a sidecar"                            has_sidecar orders
check "web has a sidecar"                               has_sidecar web
check "reports is still OUTSIDE the mesh (no sidecar)"   no_sidecar reports

section "Rules respected"
check "nothing mesh-wide: no PeerAuthentication in istio-system" mesh_wide_untouched
check "no AuthorizationPolicy used as a shortcut"       no_authz_policies
check "a namespace-wide STRICT policy exists (secure default)"   ns_wide_strict
check "istioctl analyze reports no errors"              analyzer_clean

section "Traffic behaviour"
attempt=1
while :; do
  m_cat="$(req web catalog)";        m_ord="$(req web orders)"
  p_ord="$(req reports orders)";    p_cat="$(req reports catalog)"
  if [ "$m_cat" = 200 ] && [ "$m_ord" = 200 ] && [ "$p_ord" = 200 ] && [ "$p_cat" = 000 ]; then break; fi
  [ "$attempt" -ge 3 ] && break
  attempt=$((attempt + 1)); sleep 4     # policy may still be propagating to the sidecars
done

[ "$m_cat" = 200 ] && ok "web -> catalog works over mTLS (HTTP 200)"            || bad "web -> catalog failed (got '${m_cat:-no result}', expected 200)"
[ "$m_ord" = 200 ] && ok "web -> orders works (HTTP 200)"                       || bad "web -> orders failed (got '${m_ord:-no result}', expected 200)"
[ "$p_ord" = 200 ] && ok "reports (outside the mesh) -> orders still allowed"   || bad "reports -> orders should still be allowed in plain text (got '${p_ord:-no result}')"
if [ "$p_cat" = 000 ]; then
  ok "reports (outside the mesh) -> catalog is rejected (no HTTP response)"
elif [ "$p_cat" = 403 ]; then
  bad "reports -> catalog got HTTP 403: that is an authorization decision, not mTLS enforcement"
else
  bad "reports -> catalog was NOT rejected (got HTTP ${p_cat:-none}); catalog still accepts plain text"
fi

summary
