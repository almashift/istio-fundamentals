#!/usr/bin/env bash
set -euo pipefail
NS=meshmart
kubectl label ns "$NS" istio-injection=enabled --overwrite
kubectl -n "$NS" rollout restart deploy
for d in $(kubectl -n "$NS" get deploy -o name); do
  kubectl -n "$NS" rollout status "$d" --timeout=300s
done
sleep 5   # let istiod push config to the new proxies
