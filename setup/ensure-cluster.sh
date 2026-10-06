#!/usr/bin/env bash
# Idempotent: creates the kind cluster if missing, restarts it if stopped, installs Istio if absent.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/versions.env"
CTX="kind-${CLUSTER_NAME}"

if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  echo ">> Creating kind cluster '${CLUSTER_NAME}' (Kubernetes ${K8S_VERSION})"
  kind create cluster --name "$CLUSTER_NAME" \
    --image "kindest/node:${K8S_VERSION}" \
    --config "$ROOT/setup/kind-config.yaml" --wait 180s
else
  echo ">> Cluster '${CLUSTER_NAME}' exists; making sure it is running"
  docker start "${CLUSTER_NAME}-control-plane" >/dev/null 2>&1 || true
  kind export kubeconfig --name "$CLUSTER_NAME" >/dev/null
fi

kubectl config use-context "$CTX" >/dev/null
kubectl wait --for=condition=Ready node --all --timeout=180s

if ! kubectl -n istio-system get deploy istiod >/dev/null 2>&1; then
  bash "$ROOT/setup/istio-install.sh"
else
  kubectl -n istio-system rollout status deploy/istiod --timeout=180s
fi
echo ">> Environment ready. Try:  lab list"
