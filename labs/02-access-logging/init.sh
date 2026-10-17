#!/usr/bin/env bash
# Starting state: MeshMart in the mesh, with no access logging configured anywhere.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# Remove access-log Telemetry left over from an earlier attempt (it would survive the
# namespace reset when it lives in istio-system).
# (setup/addons.sh's tracing-only "trace-everything" is kept.)
for t in $(kubectl -n istio-system get telemetry -o name 2>/dev/null | grep -v /trace-everything); do
  kubectl -n istio-system delete "$t" >/dev/null
done
bash "$ROOT/setup/meshmart.sh" --mesh
