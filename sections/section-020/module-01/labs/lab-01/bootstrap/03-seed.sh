#!/usr/bin/env bash
# Plumbing: push the module's repository content into Gitea.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/seed-repo.sh" scout-deploy "$SCRIPT_DIR/../repos/scout-deploy"
