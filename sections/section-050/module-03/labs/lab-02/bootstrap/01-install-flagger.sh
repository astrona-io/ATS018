#!/usr/bin/env bash
# Install only Flagger and its load tester. No mesh or metrics backend is installed.
set -euo pipefail
BIN_DIR="/usr/local/bin"
[ -w "$BIN_DIR" ] || BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"
if ! command -v helm >/dev/null 2>&1; then
  WORK_DIR="$(mktemp -d)"
  trap 'rm -rf "$WORK_DIR"' EXIT
  OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
  ARCH="$(uname -m)"
  case "$ARCH" in x86_64) ARCH=amd64 ;; aarch64|arm64) ARCH=arm64 ;; esac
  curl -fsSL "https://get.helm.sh/helm-v4.3.0-${OS}-${ARCH}.tar.gz" | tar -xz -C "$WORK_DIR"
  install -m 0755 "$WORK_DIR/$OS-$ARCH/helm" "$BIN_DIR/helm"
fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$SCRIPT_DIR/../manifests/lab-start.yaml"
helm upgrade --install flagger flagger --repo https://flagger.app --version 1.45.0 \
  --namespace flagger-system --create-namespace --wait \
  --set meshProvider=kubernetes --set prometheus.install=false
# Keep the chart's syntactically valid metricsServer default. With metrics: []
# Flagger never queries it; no Prometheus Service or Deployment is installed.
helm upgrade --install flagger-loadtester loadtester --repo https://flagger.app --version 0.39.0 \
  --namespace starfleet --wait
kubectl -n flagger-system rollout status deploy/flagger --timeout=300s
kubectl -n starfleet rollout status deploy/flagger-loadtester --timeout=300s
kubectl -n starfleet rollout status deploy/scout --timeout=300s
kubectl -n starfleet rollout status deploy/shuttle --timeout=300s
