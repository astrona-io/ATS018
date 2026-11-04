# Solution

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch -c sections/section-030/module-02/labs/lab-01
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Step 1: read why the release is not Ready

```sh
flux get helmreleases -n starfleet
kubectl -n starfleet get helmrelease scout -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason}: {.message}{"\n"}{end}'
kubectl -n starfleet get helmrelease scout -o jsonpath='{range .status.history[*]}{.version}{" "}{.status}{"\n"}{end}'
```

The `Ready` condition has the reason `UpgradeFailed`. The history lists a `failed` revision and the earlier `deployed` one. Read the values the release asks for:

```sh
kubectl -n starfleet get helmrelease scout -o jsonpath='{.spec.values}'
```

The values contain `faults.unready: true`. That chart value makes the podinfo readiness check fail, so the Deployment never becomes ready and Helm marks the upgrade as failed.

## Step 2: repair the values and add remediation

Save this as `helmrelease-scout.yaml`:

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: scout
  namespace: starfleet
spec:
  interval: 1m
  timeout: 30s
  chartRef:
    kind: OCIRepository
    name: podinfo
  values:
    replicaCount: 1
    resources:
      requests:
        cpu: 10m
        memory: 32Mi
      limits:
        memory: 128Mi
    faults:
      unready: false
  upgrade:
    remediation:
      retries: 1
      remediateLastFailure: true
      strategy: rollback
```

Apply it:

```sh
kubectl apply -f helmrelease-scout.yaml
```

Then check the result:

```sh
flux reconcile helmrelease scout -n starfleet --reset
flux get helmreleases -n starfleet
```

`--reset` clears the failure counters and asks the helm controller to reconcile now. The release becomes `Ready` with a new `deployed` revision.

## Step 3: prove the application answers

```sh
kubectl -n starfleet get deploy scout-podinfo
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout-podinfo:9898/
```

The Deployment has 1 ready replica and the response shows `"version": "6.15.0"`.

Stop the watch with Ctrl-C, then run the plain command once:

```sh
astrona submit -c sections/section-030/module-02/labs/lab-01
```
