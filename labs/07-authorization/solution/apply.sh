#!/usr/bin/env bash
set -euo pipefail
kubectl -n meshmart apply -f "$LAB_DIR/solution/solution.yaml"
sleep 5   # let istiod push the policy to catalog's proxies
