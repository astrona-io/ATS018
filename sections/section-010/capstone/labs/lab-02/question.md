# Question

Solve this question on: `terminal`

## Scenario

This is the Section 010 capstone: one integrated Helm and Kustomize task, without step-by-step guidance in the task. The `starfleet` team needs production and staging deployments of `scout` with different messages. A Helm chart packages templates and values; a Kustomize overlay changes shared Kubernetes manifests for one environment. Use the chart in `~/resources/scout` for production and the base and unfinished overlay in `~/resources/scout-overlay` for staging. Both environments start empty.

## Tasks

1. **Deliver production with Helm.** Complete the chart's Deployment template so `PODINFO_UI_MESSAGE` reads `.Values.message`. Set chart `version: 0.2.0` and `appVersion: "6.15.0"`. Save `~/resources/production-values.yaml` with `replicaCount: 2`, `image.tag: "6.15.0"` and `message: chart-production`. Keep the starter `values.yaml` and Service template unchanged. Keep the existing repository, names, selectors and probes. Lint and render the chart. Install or upgrade release `scout` in `starfleet-production` from these files. Leave chart `scout-0.2.0` deployed, with two ready replicas of `ghcr.io/stefanprodan/podinfo:6.15.0`. The saved files must match the installed release.
2. **Deliver staging with Kustomize.** Complete `~/resources/scout-overlay/overlays/staging` so it targets `starfleet-staging`, uses the existing `../../base`, sets image tag `6.15.0` and one replica for Deployment `scout`, and generates a ConfigMap named `scout-settings-<hash>` with `PODINFO_UI_MESSAGE=overlay-staging`. Keep the hash suffix enabled. Add an `envFrom` reference to `scout-settings` with a patch. Keep the base unchanged. Render and apply the overlay. Leave one ready replica of `ghcr.io/stefanprodan/podinfo:6.15.0`. The saved overlay must match the live resources.
3. **Prove both configurations.** Requests from `shuttle` in `starfleet` to `http://scout.starfleet-production/` and `http://scout.starfleet-staging/` must both return version `6.15.0`. Production must return message `chart-production`; staging must return message `overlay-staging`. Use Helm for production and Kustomize for staging. Do not change the live Deployments directly.
