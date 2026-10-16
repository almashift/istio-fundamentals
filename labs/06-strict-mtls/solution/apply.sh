#!/usr/bin/env bash
set -euo pipefail
kubectl -n meshmart apply -f "$LAB_DIR/solution/solution.yaml"
