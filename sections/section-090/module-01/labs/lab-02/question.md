# Question

Solve this question on: `terminal`

Crossplane, its Kubernetes provider and composition function are installed. Flux has credentials in Secret `platform-infra-auth` in `flux-system`. There is no Argo CD controller in this lab, so no ownership handover is needed.

The private repository `http://gitea-http.gitea.svc:3000/starfleet/platform-infra.git` contains `platform` (the composite resource definition and Composition) and `environments` (staging and production ScoutEnvironment resources). Production requests an unavailable image version.

## Tasks

1. Create GitRepository `platform-infra` in `flux-system`, reading branch `main` with the existing Secret. Create Kustomization `platform` from `./platform` with `prune: true` and `wait: true`.
2. Create Kustomization `environments` from `./environments` using the same source. Enable prune and health waiting, set timeout `2m`, and depend on `platform`. Keep both Kustomizations active.
3. Inspect the unhealthy production ScoutEnvironment and its composed resources. Clone the repository from `http://127.0.0.1:3000/starfleet/platform-infra.git` as `platform` with password `starfleet-gitops`. Change only the production `spec.version` from `6.99.0` to `6.15.0`, commit and push to `main`.
4. Confirm both Kustomizations apply the source's current revision and become Ready. Both ScoutEnvironment resources must be Ready, and requests from `shuttle` to `http://scout.starfleet-staging/` and `http://scout.starfleet-production/` must return version `6.15.0` and their respective environment messages.

Do not apply platform definitions, composite resources or workloads manually. Keep the existing provider configuration, Composition and health checks.

Learner work: about 15 minutes. Cluster startup, controller reconciliation and rollouts take additional time.
