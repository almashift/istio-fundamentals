#!/usr/bin/env bash
set -euo pipefail
kubectl -n lab01 apply -f "$LAB_DIR/solution/solution.yaml"
