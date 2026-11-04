# Question

Solve this question on: `terminal`

## Scenario

The `outpost` team needs a repeatable Helm release for `scout`. Helm is a tool that renders chart templates and manages installed releases. A chart packages templates and values; a release is one installed copy of a chart. The starter chart is in `~/resources/scout`. No release exists yet.

## Tasks

1. **Install the baseline.** Install the untouched starter chart as release `scout` in `starfleet-production`. Revision 1 must use the starter image `ghcr.io/stefanprodan/podinfo:6.14.0`.
2. **Complete the chart.** In `~/resources/scout`, add an environment variable named `PODINFO_UI_MESSAGE` to the Deployment template. Read its value from `.Values.message`. Set chart `version` to `0.2.0` and `appVersion` to `"6.15.0"`. Save overrides as `~/resources/production-values.yaml`: `replicaCount: 2`, `image.tag: "6.15.0"` and `message: release-ready`. Keep the starter `values.yaml` and Service template unchanged. Keep the existing image repository, resource names, selectors and probes. Lint and render the chart, then upgrade the release so revision 2 uses these settings.
3. **Recover the desired configuration.** Upgrade once more with `message: temporary` as revision 3, then roll back to revision 2. Leave the latest release deployed with chart `scout-0.2.0`, application version `6.15.0`, two ready replicas and image `ghcr.io/stefanprodan/podinfo:6.15.0`. A request from `shuttle` in `starfleet` to `http://scout.starfleet-production/` must return version `6.15.0` and message `release-ready`. Keep the saved chart and production values equal to the final installed configuration. Do not delete and recreate the release or edit the live Deployment directly.
