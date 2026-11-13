# Roll Back A Failing Canary

A canary release is only useful if a bad version never reaches all users. This part deploys a version that answers many requests with errors. You then read the event that stops the release and prove that the primary pods keep serving the old version.

## Deploy a version that returns errors

podinfo has a `--random-error` option that makes it return status 400, 409 or 500 for some requests. The pods still start and pass their readiness probe, so Kubernetes alone sees nothing wrong. Add the option to the Deployment command with a JSON patch:

<!-- astrona:playground:renew -->

```sh
kubectl -n starfleet patch deploy scout --type=json -p='[{"op":"add","path":"/spec/template/spec/containers/0/command","value":["./podinfo","--port=9898","--random-error"]}]'
```

```text
deployment.apps/scout patched
```

The pod template changed, so Flagger starts a release. Watch the status for about two minutes:

```sh
kubectl -n starfleet get canary scout --watch
```

```text
scout   Progressing   0     2026-11-01T20:44:33Z
scout   Progressing   10    2026-11-01T20:44:48Z
scout   Progressing   10    2026-11-01T20:45:03Z
scout   Progressing   10    2026-11-01T20:45:18Z
scout   Progressing   10    2026-11-01T20:45:33Z
scout   Failed   0     2026-11-01T20:45:48Z
```

The output below keeps only the status lines and leaves out the header and repeated lines. The weight stays at 10 while the checks fail. After the third failed check the status becomes `Failed` and the weight returns to 0. Read the events:

```sh
kubectl -n starfleet describe canary scout | sed -n '/Events:/,$p' | tail -4
```

```text
  Warning  Synced  3m13s (x4 over 7m12s)  flagger  Halt advancement no values found for istio metric request-success-rate probably scout.starfleet is not receiving traffic: running query failed: no values found
  Warning  Synced  2m58s                  flagger  Halt scout.starfleet advancement success rate 88.04% < 99%
  Warning  Synced  2m43s                  flagger  Rolling back scout.starfleet failed checks threshold reached 3
  Warning  Synced  2m43s                  flagger  Canary failed! Scaling down scout.starfleet
```

The Flagger controller measured a success rate of 88.04 percent, below the 99 percent minimum. It counted failed checks until it reached the `threshold` of 3, then rolled back by setting the canary weight to 0 and scaling the canary pods down.

## The old version keeps serving

Only 10 percent of the requests ever reached the bad pods. After the rollback, the primary pods serve everything. Check:

```sh
kubectl -n starfleet exec deploy/shuttle -c shuttle -- curl -s http://scout.starfleet/ | grep -E '"(version|message)"'
kubectl -n starfleet get deploy scout scout-primary
```

```text
  "version": "6.15.0",
  "message": "greetings from podinfo v6.15.0",
NAME            READY   UP-TO-DATE   AVAILABLE   AGE
scout           0/0     0            0           9m25s
scout-primary   1/1     1            1           8m40s
```

The primary still runs the last good template. The `scout` Deployment is at zero replicas, but its pod template still holds the faulty command. Flagger does not repair it. A new release starts only when the template changes again.

## Fix the release

Remove the faulty command and set a message so the response shows which template runs:

```sh
kubectl -n starfleet patch deploy scout --type=json -p='[{"op":"remove","path":"/spec/template/spec/containers/0/command"},{"op":"add","path":"/spec/template/spec/containers/0/env","value":[{"name":"PODINFO_UI_MESSAGE","value":"fixed"}]}]'
```

Flagger starts a new release, the checks pass at every step and the canary is promoted. After about three minutes check the result:

```sh
kubectl -n starfleet get canary scout
kubectl -n starfleet exec deploy/shuttle -c shuttle -- curl -s http://scout.starfleet/ | grep -E '"(version|message)"'
```

```text
NAME    STATUS      WEIGHT   LASTTRANSITIONTIME
scout   Succeeded   0        2026-11-01T20:51:18Z
  "version": "6.15.0",
  "message": "fixed",
```

The `Canary` is `Succeeded` and the response shows the fixed template. In a GitOps environment you make this change in Git and let the controller apply it, as the live patch is only for the playground.

You now know both outcomes of a Flagger release: a promotion when the metric passes and a rollback when it fails. The remaining question is how this compares with Argo Rollouts, the tool you used before.

## Common pitfalls

> [!WARNING]
> - `Failed` does not repair the Deployment. The faulty template stays in `scout` until you change it.
> - A fault that the metric does not measure goes through. The built-in success rate counts HTTP status codes, so an application that returns status 200 with a wrong body passes.
> - Do not lower `threshold` or `min` to make a failing release pass. Fix the version.
