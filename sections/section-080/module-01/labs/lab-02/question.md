# Question

Solve this question on: `terminal`

## Scenario

The `scout` application in `starfleet` runs podinfo `6.15.0` with `PODINFO_UI_MESSAGE=baseline`. Flagger and its load tester are installed. There is no service mesh, metrics backend or Canary. The team needs an HTTP (Hypertext Transfer Protocol) check before a new template reaches users.

## Tasks

1. **Define blue/green analysis.** Create a Flagger `Canary` named `scout` in `starfleet`, with `provider: kubernetes`, targeting `apps/v1` Deployment `scout`. Use Service port `80`, `targetPort: http`, analysis interval `15s`, `threshold: 2`, `iterations: 3`, and `metrics: []`. Keep analysis enabled throughout the task.
2. **Block a release with an HTTP gate.** Add one webhook named `scout-http-check`, of type `pre-rollout`, calling `http://flagger-loadtester.starfleet/` with timeout `5s`. Use metadata `type: bash` and `cmd: "curl -fsS --max-time 3 http://scout-canary.starfleet/status/500"`. After initialization, change the Deployment environment variable `PODINFO_UI_MESSAGE` to `blocked`. Let the HTTP 500 check fail until Flagger rolls back at the threshold of two failures.
3. **Repair and release.** Change the webhook command to `curl -fsS --max-time 3 http://scout-canary.starfleet/`. Change `PODINFO_UI_MESSAGE` to `green` on `scout` to trigger another release. Finish with `Succeeded`, all three iterations completed, and `green` in both the target and primary Deployment templates. Keep image `ghcr.io/stefanprodan/podinfo:6.15.0`. The `scout` Service must select `app: scout-primary`, and a request from `shuttle` must return message `green`. Do not edit generated objects.
4. **Save the events.** After promotion, save all `scout` Canary events from `starfleet` to `/tmp/scout-canary-events.txt`. Each line must contain the event's `metadata.uid`, its `involvedObject.uid` and its `message`, separated by tab characters. Quote the message as a Go string so embedded newlines stay on one line. Include both failure and promotion events. The saved identities and messages must match the live Canary events; occurrence counts and timestamps are not required.
