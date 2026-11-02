#!/usr/bin/env bash
# Grades the repaired probe Application: fix in Git, automated sync, behaviour.
set -u
fail() { echo "FAIL: $*"; exit 1; }

kubectl -n argocd get application probe >/dev/null 2>&1 || fail "Application probe is missing - fix it, do not delete it"
get() { kubectl -n argocd get application probe -o jsonpath="$1"; }
[[ "$(get '{.spec.source.repoURL}')" == "http://gitea-http.gitea.svc:3000/starfleet/platform-apps.git" ]] || fail "probe: repoURL was changed"
[[ "$(get '{.spec.source.path}')" == "apps/probe" ]] || fail "probe: path was changed"
[[ "$(get '{.spec.destination.namespace}')" == "starfleet" ]] || fail "probe: destination namespace was changed"
[[ "$(get '{.spec.syncPolicy.automated.selfHeal}')" == "true" ]] || fail "probe: automated sync with selfHeal is not on"
[[ "$(get '{.spec.syncPolicy.automated.prune}')" == "true" ]] || fail "probe: automated sync with prune is not on"

git_image=$(kubectl -n starfleet exec deploy/shuttle -- curl -s --max-time 10 -u platform:starfleet-gitops \
  "http://gitea-http.gitea.svc:3000/api/v1/repos/starfleet/platform-apps/raw/apps/probe/deployment.yaml?ref=main" | grep 'image:' | awk '{print $2}')
[[ "$git_image" == "mccutchen/go-httpbin:2.25.0" ]] || fail "Git main has image '$git_image', expected mccutchen/go-httpbin:2.25.0 (fix it in Git, not on the cluster)"

live_image=$(kubectl -n starfleet get deploy probe -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
[[ "$live_image" == "mccutchen/go-httpbin:2.25.0" ]] || fail "live Deployment probe runs '$live_image'"

sync=$(get '{.status.sync.status}'); health=$(get '{.status.health.status}')
[[ "$sync" == "Synced" ]] || fail "probe: sync status is '$sync', expected Synced"
[[ "$health" == "Healthy" ]] || fail "probe: health status is '$health', expected Healthy"
tracking=$(kubectl -n starfleet get deploy probe -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/tracking-id}' 2>/dev/null)
[[ "$tracking" == probe:* ]] || fail "probe: Deployment is not tracked by the Application"

body=""
for i in $(seq 1 10); do
  body=$(kubectl -n starfleet exec deploy/shuttle -- curl -s --max-time 5 "http://probe.starfleet/get" 2>/dev/null)
  grep -q '"url"' <<<"$body" && break
  sleep 3
done
grep -q '"url"' <<<"$body" || fail "request from shuttle to probe.starfleet/get failed (got: ${body:-nothing})"

# Self-heal must really revert a manual change.
kubectl -n starfleet scale deploy/probe --replicas=3 >/dev/null || fail "could not scale probe"
for i in $(seq 1 30); do
  [[ "$(kubectl -n starfleet get deploy probe -o jsonpath='{.spec.replicas}')" == "1" ]] && { echo "PASS: probe fixed in Git, Synced, Healthy, self-heal reverts drift"; exit 0; }
  sleep 2
done
fail "self-heal did not revert a manual scale of probe to 3"
