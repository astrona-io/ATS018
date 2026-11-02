#!/usr/bin/env bash
# Grades how the repository is delivered: the Application and the Argo CD health check.
set -u

fail() { echo "FAIL: $*"; exit 1; }
app() { kubectl -n argocd get application scout-platform -o jsonpath="$1" 2>/dev/null; }

kubectl -n argocd get application scout-platform >/dev/null 2>&1 || fail "no Application scout-platform in the namespace argocd"

[[ "$(app '{.spec.source.repoURL}')" == *starfleet/platform-infra* ]] || fail "the Application does not use the repository platform-infra"
[[ "$(app '{.spec.source.targetRevision}')" == "main" ]] || fail "targetRevision is not main"
[[ "$(app '{.spec.source.path}')" == "." ]] || fail "the Application path is '$(app '{.spec.source.path}')', expected ."
[[ "$(app '{.spec.source.directory.recurse}')" == "true" ]] || fail "directory.recurse is not true; the environments are in sub-folders"
[[ "$(app '{.spec.syncPolicy.automated.prune}')" == "true" ]] || fail "automated sync with prune is not on"
[[ "$(app '{.spec.syncPolicy.automated.selfHeal}')" == "true" ]] || fail "self-heal is not on"
[[ "$(app '{.spec.syncPolicy.syncOptions[*]}')" == *SkipDryRunOnMissingResource=true* ]] || fail "the sync option SkipDryRunOnMissingResource=true is missing"

script=$(kubectl -n argocd get configmap argocd-cm -o jsonpath='{.data.resource\.customizations\.health\.platform\.starfleet\.dev_ScoutEnvironment}' 2>/dev/null)
[[ -n "$script" ]] || fail "argocd-cm has no key resource.customizations.health.platform.starfleet.dev_ScoutEnvironment"
[[ "$script" == *Ready* && "$script" == *Healthy* && "$script" == *Degraded* ]] || fail "the health check must read the Ready condition and return Healthy or Degraded"

echo "PASS: the Application delivers platform-infra and Argo CD has a ScoutEnvironment health check"
