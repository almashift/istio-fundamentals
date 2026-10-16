#!/usr/bin/env bash
# Starting state: MeshMart in the mesh with no authorization policies: anyone may call anything.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
bash "$ROOT/setup/meshmart.sh" --mesh
