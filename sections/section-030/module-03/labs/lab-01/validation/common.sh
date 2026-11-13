#!/usr/bin/env bash
# Shared checks for the three Application graders. Sourced, not run on its own.
fail() { echo "FAIL: $*"; exit 1; }

# check_application <app> <path> <namespace>
check_application() {
  local app="$1" path="$2" ns="$3"
  kubectl -n argocd get application "$app" >/dev/null 2>&1 || fail "Application $app is missing - fix it, do not delete it"
  get() { kubectl -n argocd get application "$app" -o jsonpath="$1"; }
  [[ "$(get '{.spec.source.repoURL}')" == "http://gitea-http.gitea.svc:3000/starfleet/scout-faults.git" ]] || fail "$app: repoURL was changed"
  [[ "$(get '{.spec.source.path}')" == "$path" ]] || fail "$app: path is '$(get '{.spec.source.path}')', expected $path"
  [[ "$(get '{.spec.destination.namespace}')" == "$ns" ]] || fail "$app: destination namespace was changed from $ns"
  [[ "$(get '{.spec.syncPolicy.automated.selfHeal}')" == "true" ]] || fail "$app: automated sync with selfHeal was turned off"
  [[ "$(get '{.spec.syncPolicy.automated.prune}')" == "true" ]] || fail "$app: automated sync with prune was turned off"
  local sync health
  sync=$(get '{.status.sync.status}'); health=$(get '{.status.health.status}')
  [[ "$sync" == "Synced" ]] || fail "$app: sync status is '$sync', expected Synced"
  [[ "$health" == "Healthy" ]] || fail "$app: health status is '$health', expected Healthy"
  local tracking
  tracking=$(kubectl -n "$ns" get deploy scout -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/tracking-id}' 2>/dev/null)
  [[ "$tracking" == $app:* ]] || fail "$app: Deployment scout is not tracked by the Application"
  local body=""
  for i in $(seq 1 10); do
    body=$(kubectl -n starfleet exec deploy/shuttle -- curl -s --max-time 5 "http://scout.$ns/" 2>/dev/null)
    grep -q '"version": *"6.15.0"' <<<"$body" && return 0
    sleep 3
  done
  fail "$app: request from shuttle to scout.$ns did not return version 6.15.0 (got: ${body:-nothing})"
}

# git_file <path in the repository>: prints the file from the main branch in Git.
git_file() {
  kubectl -n starfleet exec deploy/shuttle -- curl -s --max-time 10 -u platform:starfleet-gitops \
    "http://gitea-http.gitea.svc:3000/api/v1/repos/starfleet/scout-faults/raw/$1?ref=main"
}
