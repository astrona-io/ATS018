#!/usr/bin/env bash
# Install the pinned executable in the same terminal directory as sibling tools.
set -euo pipefail
TOFU_VERSION="1.13.2"
BIN_DIR="$HOME/.astrona/bin"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
case "$ARCH" in x86_64) ARCH=amd64 ;; aarch64|arm64) ARCH=arm64 ;; *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;; esac
ARCHIVE="tofu_${TOFU_VERSION}_${OS}_${ARCH}.zip"
BASE_URL="https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}"
curl -fsSL "$BASE_URL/$ARCHIVE" -o "$WORK_DIR/$ARCHIVE"
curl -fsSL "$BASE_URL/tofu_${TOFU_VERSION}_SHA256SUMS" -o "$WORK_DIR/SHA256SUMS"
python3 - "$WORK_DIR" "$ARCHIVE" "$BIN_DIR/tofu" <<'PYCODE'
import hashlib, pathlib, sys, zipfile
folder, archive, destination = sys.argv[1:]
folder = pathlib.Path(folder)
expected = next(line.split()[0] for line in (folder/'SHA256SUMS').read_text().splitlines() if line.split()[-1] == archive)
assert hashlib.sha256((folder/archive).read_bytes()).hexdigest() == expected, 'OpenTofu checksum mismatch'
with zipfile.ZipFile(folder/archive) as bundle:
    pathlib.Path(destination).write_bytes(bundle.read('tofu'))
pathlib.Path(destination).chmod(0o755)
PYCODE
tofu version
