# Abort And Retry A Release

The stable `scout` version is now podinfo 6.15.0. A Rollout is the Argo Rollouts resource that manages the stable and canary ReplicaSets, each of which keeps pods from one template running. Try an image tag that does not exist, then stop the failed update and prove which version still serves requests. Run the image change first, wait a few seconds for the node to attempt the pull, then run the two checks.

<!-- astrona:playground:renew -->

```sh
kubectl argo rollouts set image scout scout=ghcr.io/stefanprodan/podinfo:does-not-exist -n starfleet
kubectl argo rollouts get rollout scout -n starfleet --no-color
kubectl -n starfleet get pods -l app=scout
```

The plugin's header is shortened below:

```text
Name:            scout
Namespace:       starfleet
Status:          ◌ Progressing
Message:         more replicas need to be updated
Strategy:        Canary
  Step:          0/4
  SetWeight:     20
  ActualWeight:  0
Images:          ghcr.io/stefanprodan/podinfo:6.15.0 (stable)
                 ghcr.io/stefanprodan/podinfo:does-not-exist (canary)
Replicas:
  Desired:       5
  Current:       6
  Updated:       1
  Ready:         5
  Available:     5
```

The pod list from the same run is:

```text
NAME                     READY   STATUS         RESTARTS   AGE
scout-68df8f6bb8-xvh2x   0/1     ErrImagePull   0          8s
scout-d4f6bf74f-fq66q    1/1     Running        0          27s
scout-d4f6bf74f-ph224    1/1     Running        0          15s
scout-d4f6bf74f-q6lxf    1/1     Running        0          22s
scout-d4f6bf74f-q8smp    1/1     Running        0          21s
scout-d4f6bf74f-x4lz7    1/1     Running        0          14s
```

The node cannot pull the canary image, so its pod is not ready. The Service, a Kubernetes resource that selects ready endpoints, continues to use the stable pods. `maxUnavailable: 0` and `maxSurge: 1` let the controller keep five ready stable pods while it tries one extra canary pod. The controller cannot finish the first weight step yet.

## Abort leaves the stable template serving

Abort the update:

```sh
kubectl argo rollouts abort scout -n starfleet
```

The plugin returns:

```text
rollout 'scout' aborted
```

After the controller settles, check the release, its requested image and the Service response:

```sh
kubectl argo rollouts get rollout scout -n starfleet --no-color
kubectl -n starfleet get rollout scout -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout | grep '"version"'
```

The status header is shortened below:

```text
Name:            scout
Namespace:       starfleet
Status:          ✖ Degraded
Message:         RolloutAborted: Rollout aborted update to revision 3
Strategy:        Canary
  Step:          0/4
  SetWeight:     0
  ActualWeight:  0
Images:          ghcr.io/stefanprodan/podinfo:6.15.0 (stable)
Replicas:
  Desired:       5
  Current:       5
  Updated:       0
  Ready:         5
  Available:     5
```

The final two lines from the same run are:

```text
ghcr.io/stefanprodan/podinfo:does-not-exist
  "version": "6.15.0",
```

`Degraded` describes the release, even though five ready stable pods still serve 6.15.0. Argo Rollouts scales the failed canary down and retains the stable ReplicaSet, `scout-d4f6bf74f`, on 6.15.0. An abort does not rewrite `spec.template`: the invalid image remains the desired image until you correct it. Do not assume the release is fixed just because a request succeeds.

## Correct the template before retrying

Use the valid 6.14.0 image as the replacement so its template differs from the stable 6.15.0 version. This is a controlled return to an older application version. Also update the image in your saved `rollout-scout.yaml`. If Git holds desired state, commit that correction there. Run the image change, wait for the first pause, then run the status check.

```sh
kubectl argo rollouts set image scout scout=ghcr.io/stefanprodan/podinfo:6.14.0 -n starfleet
kubectl argo rollouts get rollout scout -n starfleet --no-color
```

The header is shortened below:

```text
Name:            scout
Namespace:       starfleet
Status:          ॥ Paused
Message:         CanaryPauseStep
Strategy:        Canary
  Step:          1/4
  SetWeight:     20
  ActualWeight:  20
Images:          ghcr.io/stefanprodan/podinfo:6.14.0 (canary)
                 ghcr.io/stefanprodan/podinfo:6.15.0 (stable)
Replicas:
  Desired:       5
  Current:       5
  Updated:       1
  Ready:         5
  Available:     5
```

Changing the pod template starts a new release and clears the previous abort. The controller does not require `retry` for this new template. Changing the image back to the current stable template would instead return to the already stable version.

The `retry rollout` command retries an aborted release of the same template. To see it on a corrected image, abort the valid canary as an operator decision, then retry it:

```sh
kubectl argo rollouts abort scout -n starfleet
kubectl argo rollouts retry rollout scout -n starfleet
```

The recorded output is:

```text
rollout 'scout' aborted
rollout 'scout' retried
```

After the controller reaches the first pause again, inspect it:

```sh
kubectl argo rollouts get rollout scout -n starfleet --no-color
```

The header is shortened below:

```text
Name:            scout
Namespace:       starfleet
Status:          ॥ Paused
Message:         CanaryPauseStep
Strategy:        Canary
  Step:          1/4
  SetWeight:     20
  ActualWeight:  20
Images:          ghcr.io/stefanprodan/podinfo:6.14.0 (canary)
                 ghcr.io/stefanprodan/podinfo:6.15.0 (stable)
Replicas:
  Desired:       5
  Current:       5
  Updated:       1
  Ready:         5
  Available:     5
```

The valid canary is running again. Retry does not fix an image or skip a pause; it allows the controller to attempt the requested template again. Retrying the nonexistent image would reproduce the image pull failure.

## Finish the corrected release

You have inspected both indefinite pauses already. For this recovery example, use `--full` to skip the remaining steps and finish the valid release:

```sh
kubectl argo rollouts promote scout -n starfleet --full
kubectl argo rollouts status scout -n starfleet --timeout 120s
```

The real run returned:

```text
rollout 'scout' fully promoted
Progressing - more replicas need to be updated
Progressing - old replicas are pending termination
Healthy
```

Full promotion bypasses remaining pauses and analysis, if analysis is configured. Use normal promotion when those checks must run. Neither form can make an invalid image start or a failed readiness probe pass.

After old pods terminate and endpoints settle, check status and send a request:

```sh
kubectl argo rollouts get rollout scout -n starfleet --no-color
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout | grep '"version"'
```

The header is shortened below:

```text
Name:            scout
Namespace:       starfleet
Status:          ✔ Healthy
Strategy:        Canary
  Step:          4/4
  SetWeight:     100
  ActualWeight:  100
Images:          ghcr.io/stefanprodan/podinfo:6.14.0 (stable)
Replicas:
  Desired:       5
  Current:       5
  Updated:       5
  Ready:         5
  Available:     5
```

The response line from the same run is:

```text
  "version": "6.14.0",
```

The corrected image is now stable with five ready replicas. You can distinguish an unsuccessful release from a serving stable application, correct the desired template, and choose between retrying that template and starting a new release. Status and a real response together prove the recovery.

## Common pitfalls

> [!WARNING]
> - **Assuming abort edits the desired image.** The template stays unchanged until you correct it.
> - **Retrying before fixing the cause.** Retry repeats the same template and can reproduce the same failure.
> - **Reading Degraded as proof that all requests fail.** The stable ReplicaSet can still serve successfully.
> - **Using `--full` when release checks must run.** It skips the remaining pauses, steps and analysis.

## Your mission: Release A New Version With A Canary Rollout

You can now turn a Deployment into a canary Rollout, move a release one pause at a time, and tell an aborted release from a serving stable version. The mission gives you the `scout` Deployment on podinfo 6.14.0. You replace it with a Rollout that pauses at 20 percent and 60 percent, release 6.15.0 through both pauses, and prove the new version answers from the `shuttle` pod.

Pause the playground, then start the lab and read the task:

```sh
astrona stop ats-018-playground-050-01
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-050/module-01/labs/lab-01
```

When the release is healthy, grade your work:

```sh
astrona submit -c sections/section-050/module-01/labs/lab-01
```

Then remove the lab and start the playground again:

```sh
astrona destroy ats-018-lab-050-01
astrona start ats-018-playground-050-01
```
