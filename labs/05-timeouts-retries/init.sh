#!/usr/bin/env bash
# Starting state: MeshMart in the mesh; 1 in 5 catalog requests hangs for 10 seconds.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
bash "$ROOT/setup/meshmart.sh" --mesh
kubectl -n meshmart set env deploy/catalog-v1 deploy/catalog-v2 DELAY=10s DELAY_PERCENT=20
# Istio only exports a short list of Envoy stats by default. Ask web's proxy to also export
# its retry counters, so `lab check` (and you) can see the retries happen.
kubectl -n meshmart patch deploy web --type=merge --patch-file /dev/stdin <<'EOF'
spec:
  template:
    metadata:
      annotations:
        proxy.istio.io/config: |
          proxyStatsMatcher:
            inclusionRegexps:
            - ".*upstream_rq_retry.*"
EOF
for d in web catalog-v1 catalog-v2; do
  kubectl -n meshmart rollout status deploy/"$d" --timeout=180s
done
