#!/usr/bin/env bash
set -euo pipefail
fail() { echo "FAIL: $*"; exit 1; }
get() { kubectl -n starfleet get canary scout -o jsonpath="$1"; }
[[ "$(get '{.spec.provider}')" == kubernetes ]] || fail 'provider must be kubernetes'
[[ "$(get '{.spec.targetRef.apiVersion}/{.spec.targetRef.kind}/{.spec.targetRef.name}')" == apps/v1/Deployment/scout ]] || fail 'target must be Deployment/scout'
[[ "$(get '{.spec.service.port}/{.spec.service.targetPort}')" == 80/http ]] || fail 'Service must use 80/http'
[[ "$(get '{.spec.analysis.interval}/{.spec.analysis.threshold}/{.spec.analysis.iterations}')" == 15s/2/3 ]] || fail 'analysis must use 15s, threshold 2 and iterations 3'
[[ "$(get '{.spec.analysis.metrics}')" == '[]' ]] || fail 'metrics must be an empty list'
[[ "$(get '{.spec.skipAnalysis}')" != true && "$(get '{.spec.suspend}')" != true ]] || fail 'analysis must remain enabled'
[[ "$(get '{.spec.analysis.webhooks[*].name}')" == scout-http-check ]] || fail 'keep the single scout-http-check webhook'
[[ "$(get '{.spec.analysis.webhooks[0].type}/{.spec.analysis.webhooks[0].metadata.type}')" == pre-rollout/bash ]] || fail 'use pre-rollout with blocking metadata.type bash'
[[ "$(get '{.spec.analysis.webhooks[0].url}')" == http://flagger-loadtester.starfleet/ ]] || fail 'call the installed load tester'
[[ "$(get '{.spec.analysis.webhooks[0].timeout}')" == 5s ]] || fail 'webhook timeout must be 5s'
[[ "$(get '{.spec.analysis.webhooks[0].metadata.cmd}')" == 'curl -fsS --max-time 3 http://scout-canary.starfleet/' ]] || fail 'restore the HTTP check of the canary root path'
echo 'PASS: blue-green-definition'
