#!/usr/bin/env bash
# Starting state: Istio is installed, but MeshMart runs as plain Kubernetes (no sidecars).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
bash "$ROOT/setup/meshmart.sh" --no-mesh
