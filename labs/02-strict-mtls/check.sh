#!/usr/bin/env bash
# Grades behaviour: who can talk to whom, with and without mTLS.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/bin/lib.sh"

NS=lab02

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
  kubectl -n "$NS" exec "deploy/$1" -c client -- \
    curl -s -o /dev/null -w '%{http_code}' --max-time 3 "http://$2/" 2>/dev/null || true
}

section "Environment is intact"
check "all workloads are running"                       apps_ready
check "echo has a sidecar"                              has_sidecar echo
check "legacy has a sidecar"                            has_sidecar legacy
check "client-mesh has a sidecar"                       has_sidecar client-mesh
check "client-plain is still OUTSIDE the mesh (no sidecar)" no_sidecar client-plain

section "Rules respected"
check "nothing mesh-wide: no PeerAuthentication in istio-system" mesh_wide_untouched
check "no AuthorizationPolicy used as a shortcut"       no_authz_policies
check "a namespace-wide STRICT policy exists (secure default)"   ns_wide_strict
check "istioctl analyze reports no errors"              analyzer_clean

section "Traffic behaviour"
attempt=1
while :; do
  m_echo="$(req client-mesh echo)";   m_leg="$(req client-mesh legacy)"
  p_leg="$(req client-plain legacy)"; p_echo="$(req client-plain echo)"
  if [ "$m_echo" = 200 ] && [ "$m_leg" = 200 ] && [ "$p_leg" = 200 ] && [ "$p_echo" = 000 ]; then break; fi
  [ "$attempt" -ge 3 ] && break
  attempt=$((attempt + 1)); sleep 4     # policy may still be propagating to the sidecars
done

[ "$m_echo" = 200 ] && ok "in-mesh client -> echo works over mTLS (HTTP 200)"      || bad "in-mesh client -> echo failed (got '${m_echo:-no result}', expected 200)"
[ "$m_leg"  = 200 ] && ok "in-mesh client -> legacy works (HTTP 200)"              || bad "in-mesh client -> legacy failed (got '${m_leg:-no result}', expected 200)"
[ "$p_leg"  = 200 ] && ok "plain-text client -> legacy still allowed (HTTP 200)"   || bad "plain-text client -> legacy should be allowed (got '${p_leg:-no result}')"
if [ "$p_echo" = 000 ]; then
  ok "plain-text client -> echo is rejected (no HTTP response)"
elif [ "$p_echo" = 403 ]; then
  bad "plain-text client -> echo got HTTP 403: that is an authorization decision, not mTLS enforcement"
else
  bad "plain-text client -> echo was NOT rejected (got HTTP ${p_echo:-none}); echo is still accepting plain text"
fi

summary
