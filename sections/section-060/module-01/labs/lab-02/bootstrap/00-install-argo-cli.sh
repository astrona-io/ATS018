#!/usr/bin/env bash
# Install the pinned argo command-line tool in the terminal's Astrona bin directory.
# An argo that is already on the PATH stays in place, whatever its version.
set -euo pipefail
ARGO_VERSION="v4.1.6"
BIN_DIR="$HOME/.astrona/bin"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"

if command -v argo >/dev/null 2>&1; then
  FOUND="$(argo version --short 2>/dev/null || true)"
  case "$FOUND" in
    "argo: $ARGO_VERSION"*) ;;
    *) echo "Keeping $(command -v argo) (${FOUND:-unknown version}). The course pins $ARGO_VERSION." >&2 ;;
  esac
  exit 0
fi

OS="$(uname -s)"
case "$OS" in
  Linux) OS=linux ;;
  Darwin) OS=darwin ;;
  *) echo "Unsupported operating system: $OS" >&2; exit 1 ;;
esac
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64) ARCH=amd64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
ASSET="argo-${OS}-${ARCH}.gz"
BASE_URL="https://github.com/argoproj/argo-workflows/releases/download/$ARGO_VERSION"
curl -fsSL "$BASE_URL/$ASSET" -o "$WORK_DIR/$ASSET"
curl -fsSL "$BASE_URL/argo-workflows-cli-checksums.txt" -o "$WORK_DIR/checksums.txt"
EXPECTED="$(awk -v asset="$ASSET" '$2 == asset {print $1}' "$WORK_DIR/checksums.txt")"
if command -v sha256sum >/dev/null 2>&1; then
  ACTUAL="$(sha256sum "$WORK_DIR/$ASSET" | awk '{print $1}')"
else
  ACTUAL="$(shasum -a 256 "$WORK_DIR/$ASSET" | awk '{print $1}')"
fi
[[ -n "$EXPECTED" && "$ACTUAL" == "$EXPECTED" ]] || { echo "argo checksum mismatch for $ASSET" >&2; exit 1; }
gunzip -c "$WORK_DIR/$ASSET" > "$WORK_DIR/argo"
install -m 0755 "$WORK_DIR/argo" "$BIN_DIR/argo"
argo version --short
