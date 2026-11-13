#!/usr/bin/env bash
# Reference solution. Keep it in step with solution.md.
set -euo pipefail
NS="starfleet"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$HOME/.astrona/bin:$PATH"
unset ARGO_SERVER ARGO_TOKEN

# Insert the step and its template.
argo template update "$SCRIPT_DIR/shuttle-release.yaml"

# Run the changed template once and wait for it.
NEW_RUN="$(argo submit -n "$NS" --from workflowtemplate/shuttle-release -o name)"
kubectl -n "$NS" wait "workflow/$NEW_RUN" --for=jsonpath='{.status.phase}'=Succeeded --timeout=300s

# Remove every other run of the template, including the seeded one.
for name in $(kubectl -n "$NS" get workflows -o jsonpath='{range .items[?(@.spec.workflowTemplateRef.name=="shuttle-release")]}{.metadata.name}{"\n"}{end}'); do
  [[ "$name" == "$NEW_RUN" ]] || argo delete -n "$NS" "$name"
done
argo list -n "$NS"
