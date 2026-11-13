#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$SCRIPT_DIR/canary-scout.yaml"
kubectl -n starfleet exec deploy/shuttle -c shuttle -- curl -fsS --max-time 5 \
  -d '{"name":"scout","namespace":"starfleet"}' http://flagger-loadtester.starfleet/gate/close
kubectl -n starfleet set image deploy/scout scout=ghcr.io/stefanprodan/podinfo:6.15.0
kubectl -n starfleet wait canary/scout --for=jsonpath='{.status.phase}'=Waiting --timeout=180s
# Wait for the event emitted immediately after the controller sets Waiting.
CANARY_UID="$(kubectl -n starfleet get canary scout -o jsonpath='{.metadata.uid}')"
for ATTEMPT in $(seq 1 30); do
  kubectl -n starfleet get events --field-selector "involvedObject.uid=$CANARY_UID" \
    -o go-template='{{range .items}}{{.metadata.uid}}{{"\t"}}{{.involvedObject.uid}}{{"\t"}}{{printf "%q" .message}}{{"\n"}}{{end}}' > /tmp/scout-waiting-events.txt
  if grep -Fq 'Halt scout.starfleet advancement waiting for approval scout-approval' /tmp/scout-waiting-events.txt; then break; fi
  sleep 2
done
grep -Fq 'Halt scout.starfleet advancement waiting for approval scout-approval' /tmp/scout-waiting-events.txt
kubectl -n starfleet exec deploy/shuttle -c shuttle -- curl -fsS --max-time 5 \
  -d '{"name":"scout","namespace":"starfleet"}' http://flagger-loadtester.starfleet/gate/open
kubectl -n starfleet wait canary/scout --for=jsonpath='{.status.phase}'=Succeeded --timeout=360s
kubectl -n starfleet rollout status deploy/scout-primary --timeout=120s
for ATTEMPT in $(seq 1 30); do
  if kubectl -n starfleet get events --field-selector "involvedObject.uid=$CANARY_UID" \
    -o jsonpath='{.items[*].message}' | grep -Fq 'Promotion completed'; then exit 0; fi
  sleep 2
done
echo 'Promotion event did not arrive' >&2
exit 1
