#!/usr/bin/env bash
# Starting state: MeshMart in the mesh; catalog v1 and v2 both behind the catalog Service.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
bash "$ROOT/setup/meshmart.sh" --mesh
