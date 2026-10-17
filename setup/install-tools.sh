#!/usr/bin/env bash
# Installs kind, istioctl (pinned) and the `lab` CLI. Used by the devcontainer AND by CI.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/versions.env"

SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"
case "$(uname -m)" in
  x86_64)  ARCH=amd64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

if ! command -v kubectl >/dev/null 2>&1; then
  echo ">> Installing kubectl ${K8S_VERSION}"
  curl -fsSL -o "$TMP/kubectl" "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/${ARCH}/kubectl"
  $SUDO install -m 0755 "$TMP/kubectl" /usr/local/bin/kubectl
fi

# INSTALL_KIND=0 when the machine already has a cluster (e.g. Killercoda): labs then use it.
if [ "${INSTALL_KIND:-1}" = 1 ] && { ! command -v kind >/dev/null 2>&1 || ! kind version | grep -q "${KIND_VERSION}"; }; then
  echo ">> Installing kind ${KIND_VERSION}"
  curl -fsSL -o "$TMP/kind" "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-${ARCH}"
  $SUDO install -m 0755 "$TMP/kind" /usr/local/bin/kind
fi

if ! command -v istioctl >/dev/null 2>&1 || ! istioctl version --remote=false 2>/dev/null | grep -q "${ISTIO_VERSION}"; then
  echo ">> Installing istioctl ${ISTIO_VERSION}"
  curl -fsSL -o "$TMP/istioctl.tgz" \
    "https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/istioctl-${ISTIO_VERSION}-linux-${ARCH}.tar.gz"
  tar -xzf "$TMP/istioctl.tgz" -C "$TMP" istioctl
  $SUDO install -m 0755 "$TMP/istioctl" /usr/local/bin/istioctl
fi

# Git (or unzipping on Windows) can drop the execute bit. Restore it, and ALSO install `lab`
# as a tiny wrapper that runs the script through bash, so it works even if the bit is missing.
chmod +x "$ROOT"/bin/* "$ROOT"/setup/*.sh "$ROOT"/labs/*/*.sh "$ROOT"/labs/*/solution/*.sh 2>/dev/null || true

BIN_DIR="${BIN_DIR:-/usr/local/bin}"
echo ">> Installing the lab CLI wrapper in ${BIN_DIR}"
printf '#!/usr/bin/env bash\nexec bash "%s/bin/lab" "$@"\n' "$ROOT" | $SUDO tee "$BIN_DIR/lab" >/dev/null
$SUDO chmod 0755 "$BIN_DIR/lab"
echo ">> Tools ready."
