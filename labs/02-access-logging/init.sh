#!/usr/bin/env bash
# Starting state: MeshMart in the mesh, with no access logging configured anywhere.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# Remove access-log Telemetry left over from an earlier attempt (it would survive the
# namespace reset when it lives in istio-system).
kubectl -n istio-system delete telemetry --all --ignore-not-found >/dev/null
bash "$ROOT/setup/meshmart.sh" --mesh
