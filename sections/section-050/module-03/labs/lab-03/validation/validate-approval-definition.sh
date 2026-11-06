#!/usr/bin/env bash
set -euo pipefail
fail() { echo "FAIL: $*"; exit 1; }
field() { kubectl -n starfleet get canary scout -o "jsonpath=$1"; }
[[ "$(field '{.spec.targetRef.apiVersion}/{.spec.targetRef.kind}/{.spec.targetRef.name}')" == apps/v1/Deployment/scout ]] || fail 'keep the scout Deployment target'
[[ "$(field '{.spec.provider}')" == kubernetes ]] || fail 'keep the Kubernetes provider'
[[ "$(field '{.spec.analysis.interval}/{.spec.analysis.threshold}/{.spec.analysis.iterations}')" == 15s/3/3 ]] || fail 'keep the original analysis settings'
[[ "$(field '{.spec.service.port}/{.spec.service.targetPort}')" == 80/http ]] || fail 'keep Service port 80 and targetPort http'
[[ -z "$(field '{.spec.analysis.metrics[*].name}')" ]] || fail 'keep metrics empty'
[[ "$(field '{.spec.skipAnalysis}')" != true ]] || fail 'do not skip analysis'
[[ "$(field '{.spec.suspend}')" != true ]] || fail 'do not suspend the Canary'
[[ "$(field '{range .spec.analysis.webhooks[*]}{.name}{"|"}{.type}{"|"}{.url}{"|"}{.timeout}{"\n"}{end}')" == 'scout-approval|confirm-rollout|http://flagger-loadtester.starfleet/gate/check|5s' ]] || fail 'configure the scout-approval confirm-rollout webhook at /gate/check with timeout 5s'
echo 'PASS: approval-definition'
