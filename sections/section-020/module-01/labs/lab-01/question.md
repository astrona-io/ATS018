# Question

Solve this question on: `terminal`

## Scenario

The `outpost` team needs a repeatable Helm release for `scout`. Helm is a tool that renders chart templates and manages installed releases. A chart packages templates and values; a release is one installed copy of a chart. The starter chart is in `~/resources/scout`. No release exists yet.

## Tasks

1. **Install the baseline.** Install the untouched starter chart as release `scout` in `starfleet-production`. Revision 1 must use the starter image `ghcr.io/stefanprodan/podinfo:6.14.0`.
2. **Complete the chart.** In `~/resources/scout`, add an environment variable named `PODINFO_UI_MESSAGE` to the Deployment template. Read its value from `.Values.message`. Set chart `version` to `0.2.0` and `appVersion` to `"6.15.0"`. Save overrides as `~/resources/production-values.yaml`: `replicaCount: 2`, `image.tag: "6.15.0"` and `message: release-ready`. Keep the starter `values.yaml` and Service template unchanged. Keep the existing image repository, resource names, selectors and probes. Lint and render the chart, then upgrade the release so revision 2 uses these settings.
3. **Verify the upgrade.** Wait for two ready replicas. From `shuttle` in `starfleet`, request `http://scout.starfleet-production/` and check version `6.15.0` and message `release-ready`. Keep the saved chart and values equal to the installed configuration.

Do not patch the live Deployment or recreate the release. Learner work: about 15 minutes; allow extra time for cluster startup and rollouts. Rollback recovery has its own independent lab.
