#!/usr/bin/env bash
# Plumbing: put Helm 4.3.0 on the PATH if it is missing, then install
#   1. Istio 1.31.1 (base and istiod, no gateways) from the Istio Helm charts,
#   2. Istio's Prometheus add-on (the Prometheus Flagger queries),
#   3. Flagger 1.45.0 for the Istio provider in istio-system,
#   4. the Flagger load tester 0.39.0 in starfleet.
set -euo pipefail
HELM_VERSION="v4.3.0"
ISTIO_VERSION="1.31.1"
BIN_DIR="/usr/local/bin"
[ -w "$BIN_DIR" ] || BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"
if ! command -v helm >/dev/null 2>&1; then
  WORK="$(mktemp -d)"
  trap 'rm -rf "$WORK"' EXIT
  OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
  ARCH="$(uname -m)"; case "$ARCH" in x86_64) ARCH=amd64 ;; aarch64|arm64) ARCH=arm64 ;; esac
  curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-${OS}-${ARCH}.tar.gz" | tar -xz -C "$WORK"
  install -m 0755 "$WORK/${OS}-${ARCH}/helm" "$BIN_DIR/helm"
fi
ISTIO_REPO="https://istio-release.storage.googleapis.com/charts"
helm upgrade --install istio-base base --repo "$ISTIO_REPO" --version "$ISTIO_VERSION" \
  --namespace istio-system --create-namespace --wait
helm upgrade --install istiod istiod --repo "$ISTIO_REPO" --version "$ISTIO_VERSION" \
  --namespace istio-system --wait \
  --set pilot.resources.requests.cpu=50m --set pilot.resources.requests.memory=128Mi \
  --set global.proxy.resources.requests.cpu=10m --set global.proxy.resources.requests.memory=32Mi
kubectl apply -f "https://raw.githubusercontent.com/istio/istio/${ISTIO_VERSION}/samples/addons/prometheus.yaml" >/dev/null
kubectl -n istio-system rollout status deploy/prometheus --timeout=300s
helm upgrade --install flagger flagger --repo https://flagger.app --version 1.45.0 \
  --namespace istio-system --wait \
  --set meshProvider=istio --set metricsServer=http://prometheus.istio-system:9090
kubectl label namespace starfleet istio-injection=enabled --overwrite
helm upgrade --install flagger-loadtester loadtester --repo https://flagger.app --version 0.39.0 \
  --namespace starfleet --wait
# Restart the workloads that started before injection was on, so they get a sidecar.
kubectl -n starfleet rollout restart deploy/scout deploy/shuttle
kubectl -n starfleet rollout status deploy/scout --timeout=300s
kubectl -n starfleet rollout status deploy/shuttle --timeout=300s
