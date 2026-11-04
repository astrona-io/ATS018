#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$SCRIPT_DIR/canary-scout.yaml"
kubectl -n starfleet wait canary/scout --for=jsonpath='{.status.phase}'=Initialized --timeout=240s
kubectl -n starfleet patch canary scout --type=json \
  -p='[{"op":"replace","path":"/spec/analysis/webhooks/0/metadata/cmd","value":"curl -fsS --max-time 3 http://scout-canary.starfleet/status/500"}]'
kubectl -n starfleet set env deploy/scout PODINFO_UI_MESSAGE=blocked
kubectl -n starfleet wait canary/scout --for=jsonpath='{.status.phase}'=Failed --timeout=300s
kubectl apply -f "$SCRIPT_DIR/canary-scout.yaml"
kubectl -n starfleet set env deploy/scout PODINFO_UI_MESSAGE=green
kubectl -n starfleet wait canary/scout --for=jsonpath='{.status.phase}'=Succeeded --timeout=360s
kubectl -n starfleet rollout status deploy/scout-primary --timeout=120s
# Flagger sets Succeeded just before it records the promotion event, so wait for the event.
for _ in $(seq 1 30); do
  kubectl -n starfleet get events --field-selector involvedObject.kind=Canary,involvedObject.name=scout \
    -o jsonpath='{.items[*].message}' | grep -q 'Promotion completed' && break
  sleep 2
done
# Preserve stable event fields, rather than timestamps or occurrence counts.
kubectl -n starfleet get events --field-selector involvedObject.kind=Canary,involvedObject.name=scout \
  -o go-template='{{range .items}}{{.metadata.uid}}{{"\t"}}{{.involvedObject.uid}}{{"\t"}}{{printf "%q" .message}}{{"\n"}}{{end}}' \
  > /tmp/scout-canary-events.txt
