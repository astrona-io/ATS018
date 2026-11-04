#!/usr/bin/env bash
# Install the exact teaching version in the terminal's standard Astrona bin directory.
set -euo pipefail
HELM_VERSION="v4.3.0"
BIN_DIR="$HOME/.astrona/bin"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"
if ! command -v helm >/dev/null 2>&1 || [[ "$(helm version --short)" != "$HELM_VERSION"+* ]]; then
  WORK_DIR="$(mktemp -d)"
  trap 'rm -rf "$WORK_DIR"' EXIT
  OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
  ARCH="$(uname -m)"
  case "$ARCH" in x86_64) ARCH=amd64 ;; aarch64|arm64) ARCH=arm64 ;; *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;; esac
  ARCHIVE="helm-${HELM_VERSION}-${OS}-${ARCH}.tar.gz"
  curl -fsSL "https://get.helm.sh/$ARCHIVE" -o "$WORK_DIR/$ARCHIVE"
  curl -fsSL "https://get.helm.sh/$ARCHIVE.sha256sum" -o "$WORK_DIR/checksum"
  EXPECTED="$(awk '{print $1}' "$WORK_DIR/checksum")"
  if command -v sha256sum >/dev/null 2>&1; then
    ACTUAL="$(sha256sum "$WORK_DIR/$ARCHIVE" | awk '{print $1}')"
  else
    ACTUAL="$(shasum -a 256 "$WORK_DIR/$ARCHIVE" | awk '{print $1}')"
  fi
  [[ "$ACTUAL" == "$EXPECTED" ]] || { echo "Helm checksum mismatch" >&2; exit 1; }
  tar -xzf "$WORK_DIR/$ARCHIVE" -C "$WORK_DIR"
  install -m 0755 "$WORK_DIR/${OS}-${ARCH}/helm" "$BIN_DIR/helm"
fi
helm version --short
