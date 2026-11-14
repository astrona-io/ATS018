# Question

Solve this question on: `terminal`

## Scenario

The `scout` Rollout in `starfleet` has 5 replicas. Its stable version is podinfo `6.14.0`. A release of `6.15.0` is stopped at the first pause, at 20 percent. The `outpost` team trusts this release, but wants the next release to pass an automatic HTTP (Hypertext Transfer Protocol) check instead of waiting for a person at that pause.

The Argo Rollouts controller is installed. The Rollout already names the Service `scout-canary` as its `canaryService`. The AnalysisTemplate `scout-canary-message` exists but is unfinished.

## Tasks

1. **Finish the paused release in two moves.** Use `kubectl argo rollouts promote` once, so that the release stops at the second pause (step `3/4`). Then finish it with `kubectl argo rollouts promote --full`. Wait until the Rollout is `Healthy` on `6.15.0`.
2. **Complete the AnalysisTemplate.** Change `scout-canary-message` in `starfleet`. Keep its `web` provider, its metric name `message` and its timing. The metric must request `http://scout-canary.starfleet/`, read the `message` field of the JSON (JavaScript Object Notation) response with `jsonPath`, and succeed only when that value equals `canary-ready`.
3. **Replace the first pause.** Change the Rollout so that its steps are, in this order: `setWeight: 20`, an inline `analysis` step that uses the template `scout-canary-message`, `setWeight: 60`, and `pause: {}`. Do this after the `6.15.0` release is `Healthy`.
4. **Trigger a release with an environment variable.** Set `PODINFO_UI_MESSAGE=canary-ready` on the `scout` container in the Rollout. Keep the image `ghcr.io/stefanprodan/podinfo:6.15.0`. Wait until the analysis step passes and the Rollout stops at the last pause. Do not promote during the analysis step.
5. **Read the AnalysisRun.** Find the `Successful` AnalysisRun that the analysis step created for this release. Save its name, its phase and the `value` of its first measurement to `/tmp/scout-analysisrun.txt`. Put them on one line, separated by single spaces, with the value exactly as the AnalysisRun shows it.
6. **Finish the release.** Use a normal `promote`, not `--full`. The Rollout must be `Healthy` with 5 available replicas and the new pod template as its stable version. A request from the `shuttle` pod to `http://scout.starfleet/` must return version `6.15.0` and message `canary-ready`.
