#!/usr/bin/env bash
# Grades behaviour: calls from web to catalog never hang, almost all succeed, and the
# successes come from retries (Envoy's retry counter goes up), not from fixing catalog.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/bin/lib.sh"
NS=meshmart
REQUESTS=40
MAX_SECONDS=3.6   # 3 attempts x 1s, plus a little overhead

apps_ready() { kubectl -n "$NS" wait --for=condition=Available deploy --all --timeout=5s; }
catalog_still_slow() {   # the fix must be in the mesh, not in catalog's settings
  local d out
  for d in catalog-v1 catalog-v2; do
    out="$(kubectl -n "$NS" get deploy "$d" -o jsonpath='{.spec.template.spec.containers[0].env}' 2>/dev/null)" || return 1
    grep -q '"name":"DELAY","value":"10s"' <<<"$out" || return 1
  done
}
# Sum of upstream_rq_retry over every outbound catalog cluster in web's Envoy.
retries() {
  kubectl -n "$NS" exec deploy/web -c istio-proxy -- pilot-agent request GET stats 2>/dev/null |
    awk -F': ' '/^cluster\.outbound\|80\|[^|]*\|catalog\.meshmart\.svc\.cluster\.local\.upstream_rq_retry: / { s += $2 } END { print s + 0 }'
}

section "Environment"
check "all MeshMart Deployments are available"          apps_ready
check "catalog still has its 10s hangs (fix it in the mesh)" catalog_still_slow

section "Calls from web to catalog ($REQUESTS requests)"
before="$(retries)"
out="$(kubectl -n "$NS" exec deploy/web -c web -- sh -c \
  "i=0; while [ \$i -lt $REQUESTS ]; do curl -s -o /dev/null -m 15 -w '%{http_code} %{time_total}\n' http://catalog/; i=\$((i+1)); done" 2>/dev/null || true)"
after="$(retries)"
total="$(grep -c . <<<"$out" || true)"
okc="$(grep -c '^200 ' <<<"$out" || true)"
slow="$(awk -v m="$MAX_SECONDS" '$2 > m' <<<"$out" | grep -c . || true)"
max="$(awk 'BEGIN{m=0} $2 > m {m=$2} END{printf "%.1f", m}' <<<"$out")"

if [ "$total" -eq "$REQUESTS" ] && [ "$slow" -eq 0 ]; then
  ok "no call took longer than ${MAX_SECONDS}s (slowest: ${max}s)"
else
  bad "$slow of $total calls took longer than ${MAX_SECONDS}s (slowest: ${max}s): web is still waiting on hung requests"
fi
if [ "$okc" -ge $((REQUESTS * 90 / 100)) ]; then
  ok "$okc of $REQUESTS calls succeeded"
else
  bad "only $okc of $REQUESTS calls succeeded (need 90%): give up on slow attempts, then retry them"
fi
if [ "$((after - before))" -gt 0 ]; then
  ok "web's proxy retried $((after - before)) slow attempts"
else
  bad "web's proxy made no retries"
fi

summary
