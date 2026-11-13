#!/usr/bin/env bash
# Grades by behaviour: Canary events, Canary status, the primary Deployment and a real request from shuttle.
set -u

NS="starfleet"
fail() { echo "FAIL: $*"; exit 1; }

events=$(kubectl -n "$NS" get events --field-selector involvedObject.kind=Canary,involvedObject.name=scout \
  -o jsonpath='{range .items[*]}{.message}{"\n"}{end}' 2>/dev/null)
grep -q 'Rolling back' <<<"$events" || fail "no 'Rolling back' event - the faulty release must fail its checks and roll back"
grep -q 'Promotion completed' <<<"$events" || fail "no 'Promotion completed' event - promote a good release"

phase=$(kubectl -n "$NS" get canary scout -o jsonpath='{.status.phase}')
[[ "$phase" == "Succeeded" ]] || fail "Canary phase is '$phase', expected Succeeded"

command=$(kubectl -n "$NS" get deploy scout -o jsonpath='{.spec.template.spec.containers[0].command}')
[[ "$command" != *random-error* ]] || fail "the scout Deployment template still has --random-error"

message=$(kubectl -n "$NS" get deploy scout -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="PODINFO_UI_MESSAGE")].value}')
[[ "$message" == "fixed" ]] || fail "PODINFO_UI_MESSAGE is '$message', expected fixed"

image=$(kubectl -n "$NS" get deploy scout-primary -o jsonpath='{.spec.template.spec.containers[0].image}')
[[ "$image" == "ghcr.io/stefanprodan/podinfo:6.15.0" ]] || fail "scout-primary runs $image, expected ghcr.io/stefanprodan/podinfo:6.15.0"

primary_msg=$(kubectl -n "$NS" get deploy scout-primary -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="PODINFO_UI_MESSAGE")].value}')
[[ "$primary_msg" == "fixed" ]] || fail "scout-primary has the message '$primary_msg'; the fixed template was not promoted"

body=$(kubectl -n "$NS" exec deploy/shuttle -c shuttle -- curl -s --max-time 10 http://scout.starfleet/ 2>/dev/null)
grep -q '"version": *"6.15.0"' <<<"$body" || fail "request from shuttle did not return version 6.15.0"
grep -q '"message": *"fixed"' <<<"$body" || fail "request from shuttle did not return the message fixed"

echo "PASS: a faulty release rolled back, the fixed template was promoted and shuttle receives it"
