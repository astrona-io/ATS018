# Analysis And A Promoted Canary

The `Canary` exists, but nothing is released yet. Flagger starts a release when the pod template of the target Deployment changes. This part changes the image, follows the canary through its weight steps and reads the events that explain each decision.

## The analysis block

The `analysis` block in `canary-scout.yaml` is the release policy. It has five fields you must know:

- `interval`: how long Flagger waits between two steps. Here it is `15s`.
- `stepWeight`: how many percent of the traffic moves to the canary at each step. Here it is `10`.
- `maxWeight`: the highest canary weight before promotion. Here it is `50`.
- `threshold`: how many failed checks Flagger accepts before it rolls back. Here it is `3`.
- `metrics`: the checks. `request-success-rate` is a built-in metric that Flagger computes from Istio's request counter. `thresholdRange.min: 99` means at least 99 percent of the requests must succeed.

The `webhooks` entry of type `rollout` runs at every step. It calls the load tester, which sends `hey` requests to `scout-canary` so the metric has data. Without requests, the success rate has no values and Flagger cannot decide.

## Trigger a canary

Change the image of the `scout` Deployment. Flagger sees a new pod template and starts a release.

<!-- astrona:playground:renew -->

```sh
kubectl -n starfleet set image deploy/scout scout=ghcr.io/stefanprodan/podinfo:6.15.0
```

Flagger scales up the canary pods, then raises the weight by 10 percent every 15 seconds. Watch the status:

```sh
kubectl -n starfleet get canary scout --watch
```

The `WEIGHT` column rises from 10 to 50 in steps of 10. The `STATUS` column shows `Progressing` during the steps. Press `Ctrl+C` when it reads `Succeeded`. Then read the events:

```sh
kubectl -n starfleet describe canary scout | sed -n '/Events:/,$p'
```

```text
Events:
  Type     Reason  Age                   From     Message
  ----     ------  ----                  ----     -------
  Warning  Synced  4m20s                 flagger  scout-primary.starfleet not ready: waiting for rollout to finish: observed deployment generation less than desired generation
  Normal   Synced  4m5s (x2 over 4m20s)  flagger  all the metrics providers are available!
  Normal   Synced  4m4s                  flagger  Initialization done! scout.starfleet
  Normal   Synced  3m35s                 flagger  New revision detected! Scaling up scout.starfleet
  Normal   Synced  3m20s                 flagger  Starting canary analysis for scout.starfleet
  Normal   Synced  3m20s                 flagger  Advance scout.starfleet canary weight 10
  Warning  Synced  2m50s (x2 over 3m4s)  flagger  Halt advancement no values found for istio metric request-success-rate probably scout.starfleet is not receiving traffic: running query failed: no values found
  Normal   Synced  2m34s                 flagger  Advance scout.starfleet canary weight 20
  Normal   Synced  2m19s                 flagger  Advance scout.starfleet canary weight 30
  Normal   Synced  2m5s                  flagger  Advance scout.starfleet canary weight 40
  Normal   Synced  110s                  flagger  Advance scout.starfleet canary weight 50
  Normal   Synced  65s (x3 over 95s)     flagger  (combined from similar events): Promotion completed! Scaling down scout.starfleet
```

This is the real event list of the release, copied from the playground. Each `Advance` line is one step. The `Halt advancement` warning shows the safe default: when the metric returns no values, Flagger waits and does not promote. Here the first requests had not yet reached the Istio metrics. Flagger tried again and continued.

## What the promotion did

After `maxWeight`, Flagger copies the canary pod template into `scout-primary`, waits for the primary pods to be ready and scales the canary down. Then it sets the weights back to 100 and 0. Check which version the `scout` Service returns:

```sh
kubectl -n starfleet get deploy scout-primary -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
kubectl -n starfleet exec deploy/shuttle -c shuttle -- curl -s http://scout.starfleet/ | grep '"version"'
```

```text
ghcr.io/stefanprodan/podinfo:6.15.0
  "version": "6.15.0",
```

The primary Deployment now runs the new image, and the request from `shuttle` returns version 6.15.0. The Flagger controller did the promotion, and the Istio sidecar proxies applied each weight.

You now know how a good release ends. The open question is what Flagger does when the new version returns errors.

## Common pitfalls

> [!WARNING]
> - A change that does not touch the pod template (for example the Deployment replicas) does not start a release. Change the image, an environment variable or another template field.
> - Without test traffic the success rate has no values, and Flagger halts at every step. Keep the load test webhook or another client sending requests to the canary.
> - Do not read `Succeeded` as a running release. It means the last release finished and promoted.
