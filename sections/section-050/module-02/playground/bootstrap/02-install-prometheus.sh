#!/usr/bin/env bash
# Plumbing: put Helm 4.3.0 on the PATH if it is missing, install a trimmed
# kube-prometheus-stack 92.3.0 (Prometheus Operator and one Prometheus) in
# `monitoring`, and wait until Prometheus is ready.
set -euo pipefail
HELM_VERSION="v4.3.0"
CHART_VERSION="92.3.0"
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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
helm upgrade --install kps kube-prometheus-stack \
  --repo https://prometheus-community.github.io/helm-charts \
  --version "$CHART_VERSION" \
  --namespace monitoring --create-namespace \
  -f "$SCRIPT_DIR/kps-values.yaml" --wait --timeout 10m
kubectl -n monitoring rollout status statefulset/prometheus-kps-prometheus --timeout=300s
