#!/usr/bin/env bash
# Install the pinned tkn command-line tool in the terminal's Astrona bin directory.
# A tkn that is already on the PATH stays in place, whatever its version.
set -euo pipefail
TKN_VERSION="0.46.1"
BIN_DIR="$HOME/.astrona/bin"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"

if command -v tkn >/dev/null 2>&1; then
  FOUND="$(tkn version --component client 2>/dev/null || true)"
  if [[ "$FOUND" != "$TKN_VERSION" ]]; then
    echo "Keeping $(command -v tkn) (${FOUND:-unknown version}). The course pins $TKN_VERSION." >&2
  fi
  exit 0
fi

OS="$(uname -s)"
ARCH="$(uname -m)"
case "$OS" in
  Darwin) ASSET="tkn_${TKN_VERSION}_Darwin_all.tar.gz" ;;
  Linux)
    case "$ARCH" in
      x86_64|amd64) ASSET="tkn_${TKN_VERSION}_Linux_x86_64.tar.gz" ;;
      aarch64|arm64) ASSET="tkn_${TKN_VERSION}_Linux_aarch64.tar.gz" ;;
      *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
    esac
    ;;
  *) echo "Unsupported operating system: $OS" >&2; exit 1 ;;
esac

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
BASE_URL="https://github.com/tektoncd/cli/releases/download/v$TKN_VERSION"
curl -fsSL "$BASE_URL/$ASSET" -o "$WORK_DIR/$ASSET"
curl -fsSL "$BASE_URL/checksums.txt" -o "$WORK_DIR/checksums.txt"
EXPECTED="$(awk -v asset="$ASSET" '$2 == asset {print $1}' "$WORK_DIR/checksums.txt")"
if command -v sha256sum >/dev/null 2>&1; then
  ACTUAL="$(sha256sum "$WORK_DIR/$ASSET" | awk '{print $1}')"
else
  ACTUAL="$(shasum -a 256 "$WORK_DIR/$ASSET" | awk '{print $1}')"
fi
[[ -n "$EXPECTED" && "$ACTUAL" == "$EXPECTED" ]] || { echo "tkn checksum mismatch for $ASSET" >&2; exit 1; }
tar -xzf "$WORK_DIR/$ASSET" -C "$WORK_DIR" tkn
install -m 0755 "$WORK_DIR/tkn" "$BIN_DIR/tkn"
tkn version --component client
