#!/usr/bin/env bash
# Grades the AppProject outpost from the live object.
set -u

REPO_URL="http://gitea-http.gitea.svc:3000/starfleet/outpost-apps.git"
fail() { echo "FAIL: $*"; exit 1; }

kubectl -n argocd get appproject outpost >/dev/null 2>&1 || fail "no AppProject outpost in the namespace argocd"
get() { kubectl -n argocd get appproject outpost -o jsonpath="$1"; }

repos=$(get '{.spec.sourceRepos[*]}')
[[ "$repos" == "$REPO_URL" ]] || fail "sourceRepos is '$repos', expected only $REPO_URL"

dests=$(get '{range .spec.destinations[*]}{.server}|{.namespace}{"\n"}{end}')
[[ "$dests" == "https://kubernetes.default.svc|outpost" ]] || fail "destinations are '$dests', expected only https://kubernetes.default.svc|outpost"

cluster=$(get '{.spec.clusterResourceWhitelist}')
[[ -z "$cluster" ]] || fail "clusterResourceWhitelist is '$cluster', expected it to be empty so the project allows no cluster-scoped resources"

allowed=$(get '{range .spec.namespaceResourceWhitelist[*]}{.group}/{.kind}{"\n"}{end}')
grep -qx 'apps/Deployment' <<<"$allowed" || fail "namespaceResourceWhitelist does not allow apps/Deployment"
grep -qx '/Service' <<<"$allowed" || fail "namespaceResourceWhitelist does not allow the core Service"
grep -q '\*' <<<"$allowed" && fail "namespaceResourceWhitelist uses a wildcard, expected only Deployment and Service"

echo "PASS: AppProject outpost limits repository, destination and resource kinds"
