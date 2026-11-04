#!/usr/bin/env bash
# Apply the documented answer and retain the real plan for grading.
set -euo pipefail
export PATH="$HOME/.astrona/bin:$PATH"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HOME/resources/tofu/scale"
cp "$SCRIPT_DIR/scale/deployment.tf" deployment.tf
cp "$SCRIPT_DIR/scale/service.tf" service.tf
tofu init -input=false
tofu plan -no-color -input=false -out=change.plan
tofu show -no-color change.plan > plan.txt
tofu apply -input=false change.plan
cd "$HOME/resources/tofu/expose"
cp "$SCRIPT_DIR/expose/deployment.tf" deployment.tf
cp "$SCRIPT_DIR/expose/service.tf" service.tf
tofu init -input=false
tofu plan -no-color -input=false -out=change.plan
tofu show -no-color change.plan > plan.txt
tofu apply -input=false change.plan
cd "$HOME/resources/tofu/drift"
cp "$SCRIPT_DIR/drift/deployment.tf" deployment.tf
cp "$SCRIPT_DIR/drift/service.tf" service.tf
tofu init -input=false
tofu plan -no-color -input=false -out=change.plan
tofu show -no-color change.plan > plan.txt
tofu apply -input=false change.plan
