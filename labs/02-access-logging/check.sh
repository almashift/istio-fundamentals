#!/usr/bin/env bash
# Grades the outcome: a tagged request through the store shows up in the access logs of
# both proxies it passes through, and the workloads were left alone.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/bin/lib.sh"
NS=meshmart

apps_ready() { kubectl -n "$NS" wait --for=condition=Available deploy --all --timeout=5s; }
# Access logs must come from Istio config, not from editing pods (e.g. proxy annotations).
workloads_untouched() {
  local out
  out="$(kubectl -n "$NS" get deploy -o jsonpath='{range .items[*]}{.spec.template.metadata.annotations}{"\n"}{end}' 2>/dev/null)" || return 1
  ! grep -q 'proxy.istio.io/config\|sidecar.istio.io' <<<"$out"
}
# logged <app> <id>: the request id appears in that workload's istio-proxy log
logged() {
  local out
  out="$(kubectl -n "$NS" logs deploy/"$1" -c istio-proxy --since=2m 2>/dev/null)" || return 1
  grep -q "$2" <<<"$out"
}

section "Environment"
check "all MeshMart Deployments are available"          apps_ready
check "Deployments not edited (no proxy annotations)"   workloads_untouched

section "Access logs (one tagged request: loadgen -> web -> catalog)"
id="lab02-$RANDOM$RANDOM"
web_ok=0; cat_ok=0
for attempt in 1 2 3 4 5; do
  kubectl -n "$NS" exec deploy/loadgen -c loadgen -- curl -s -o /dev/null -H "x-request-id: $id" http://web/ >/dev/null 2>&1
  sleep 2
  logged web "$id" && web_ok=1
  logged catalog-v1 "$id" || logged catalog-v2 "$id" && cat_ok=1
  [ "$web_ok" = 1 ] && [ "$cat_ok" = 1 ] && break
  sleep 3   # new Telemetry config may still be reaching the proxies
done
[ "$web_ok" = 1 ] && ok "web's proxy logged request $id" || bad "web's proxy did not log request $id"
[ "$cat_ok" = 1 ] && ok "catalog's proxy logged request $id" || bad "catalog's proxy did not log request $id"

summary
