#!/usr/bin/env bash
# Idempotent: creates the kind cluster if missing, restarts it if stopped, installs Istio if absent.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/versions.env"
CTX="kind-${CLUSTER_NAME}"

cpus="$(nproc)"
mem_mb="$(awk '/MemTotal/{printf "%d", $2/1024}' /proc/meminfo)"
echo ">> Host resources: ${cpus} vCPU, ${mem_mb} MiB RAM"
if [ "$cpus" -lt 2 ] || [ "$mem_mb" -lt 6500 ]; then
  echo "WARNING: this machine is below the 2 vCPU / 8 GB minimum; the cluster may be unstable." >&2
fi

if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  echo ">> Creating kind cluster '${CLUSTER_NAME}' (Kubernetes ${K8S_VERSION}); a 2-core machine needs a few minutes"
  kind create cluster --name "$CLUSTER_NAME" \
    --image "kindest/node:${K8S_VERSION}" \
    --config "$ROOT/setup/kind-config.yaml" --wait 300s
else
  echo ">> Cluster '${CLUSTER_NAME}' exists; making sure it is running"
  docker start "${CLUSTER_NAME}-control-plane" >/dev/null 2>&1 || true
  kind export kubeconfig --name "$CLUSTER_NAME" >/dev/null
fi

kubectl config use-context "$CTX" >/dev/null
kubectl wait --for=condition=Ready node --all --timeout=300s

if ! kubectl -n istio-system get deploy istiod >/dev/null 2>&1; then
  bash "$ROOT/setup/istio-install.sh"
else
  kubectl -n istio-system rollout status deploy/istiod --timeout=300s
fi
echo ">> Environment ready. Try:  lab list"
