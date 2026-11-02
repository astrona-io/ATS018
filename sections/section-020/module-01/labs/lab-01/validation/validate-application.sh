#!/usr/bin/env bash
# Grades the definition: the repository Secret and the Application, read from the live cluster.
set -u

REPO_URL="http://gitea-http.gitea.svc:3000/starfleet/scout-deploy.git"
fail() { echo "FAIL: $*"; exit 1; }

secret_url=""
for name in $(kubectl -n argocd get secret -l argocd.argoproj.io/secret-type=repository -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
  url=$(kubectl -n argocd get secret "$name" -o jsonpath='{.data.url}' | base64 -d)
  [[ "$url" == "$REPO_URL" ]] && secret_url="$url"
done
[[ -n "$secret_url" ]] || fail "no repository Secret in argocd with the label argocd.argoproj.io/secret-type=repository and url $REPO_URL"

kubectl -n argocd get application scout-staging >/dev/null 2>&1 || fail "no Application scout-staging in the namespace argocd"

get() { kubectl -n argocd get application scout-staging -o jsonpath="$1"; }
[[ "$(get '{.spec.source.repoURL}')" == "$REPO_URL" ]] || fail "repoURL is '$(get '{.spec.source.repoURL}')', expected $REPO_URL"
[[ "$(get '{.spec.source.path}')" == "overlays/staging" ]] || fail "path is '$(get '{.spec.source.path}')', expected overlays/staging"
[[ "$(get '{.spec.source.targetRevision}')" == "main" ]] || fail "targetRevision is '$(get '{.spec.source.targetRevision}')', expected main"
[[ "$(get '{.spec.destination.namespace}')" == "starfleet-staging" ]] || fail "destination namespace is '$(get '{.spec.destination.namespace}')', expected starfleet-staging"
[[ "$(get '{.spec.syncPolicy.automated.prune}')" == "true" ]] || fail "syncPolicy.automated.prune is not true"
[[ "$(get '{.spec.syncPolicy.automated.selfHeal}')" == "true" ]] || fail "syncPolicy.automated.selfHeal is not true"

echo "PASS: repository Secret and Application scout-staging are defined with automated sync, prune and self-heal"
