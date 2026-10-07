#!/usr/bin/env bash
set -euo pipefail
kubectl -n lab02 apply -f "$LAB_DIR/solution/solution.yaml"
