#!/usr/bin/env bash
# Apply the documented answer and retain the real plan for grading.
set -euo pipefail
export PATH="$HOME/.astrona/bin:$PATH"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HOME/resources/tofu/scout"
cp "$SCRIPT_DIR/scout/deployment.tf" deployment.tf
cp "$SCRIPT_DIR/scout/service.tf" service.tf
tofu init -input=false
tofu plan -no-color -input=false -out=change.plan
tofu show -no-color change.plan > plan.txt
tofu apply -input=false change.plan
