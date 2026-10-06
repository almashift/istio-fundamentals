#!/usr/bin/env bash
# Write this BEFORE the lesson. Test behaviour (traffic, denied requests), not just object existence.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/bin/lib.sh"

section "Example"
check "something that must be true" true

summary
