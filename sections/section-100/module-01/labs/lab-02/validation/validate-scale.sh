#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]})")" && pwd)"
python3 "$SCRIPT_DIR/check-working-directory.py" scale scout starfleet-staging 2 scale
