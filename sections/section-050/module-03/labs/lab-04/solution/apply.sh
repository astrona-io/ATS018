#!/usr/bin/env bash
set -euo pipefail
dir=$(cd "$(dirname "$0")" && pwd)
kubectl apply -f "$dir/canary.yaml"
kubectl -n starfleet exec deploy/shuttle -c shuttle -- curl -fsS --max-time 10 \
  -d '{"name":"scout","namespace":"starfleet"}' http://flagger-loadtester.starfleet/gate/close
kubectl -n starfleet set image deployment/scout scout=ghcr.io/stefanprodan/podinfo:6.15.0
kubectl -n starfleet wait canary/scout --for=jsonpath='{.status.phase}'=WaitingPromotion --timeout=600s
for attempt in $(seq 1 30); do
  CANARY_UID=$(kubectl -n starfleet get canary scout -o jsonpath='{.metadata.uid}')
  kubectl -n starfleet get events --field-selector "involvedObject.uid=$CANARY_UID" \
  -o json > /tmp/scout-promotion-events.json
  if grep -q 'waiting for promotion approval scout-approval' /tmp/scout-promotion-events.json; then break; fi
  sleep 2
done
grep -q 'waiting for promotion approval scout-approval' /tmp/scout-promotion-events.json
python3 "$dir/../testing/check-waiting.py"
kubectl -n starfleet exec deploy/shuttle -c shuttle -- curl -fsS --max-time 10 \
  -d '{"name":"scout","namespace":"starfleet"}' http://flagger-loadtester.starfleet/gate/open
kubectl -n starfleet wait canary/scout --for=jsonpath='{.status.phase}'=Succeeded --timeout=600s
kubectl -n starfleet rollout status deployment/scout-primary --timeout=180s

bash "$dir/../validation/validate.sh" --wait
