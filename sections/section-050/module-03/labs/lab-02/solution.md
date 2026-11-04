# Solution Walkthrough

You will use a failed HTTP (Hypertext Transfer Protocol) check to stop one release, then promote a new environment value. A `Canary` is the Flagger resource that targets a workload and defines its release checks.

| Goal | Object or file | Field |
| --- | --- | --- |
| Select blue/green | Canary | `provider: kubernetes`, `analysis.iterations` |
| Test before promotion | Canary webhook | `type: pre-rollout`, metadata `type: bash` |
| Start a release | Deployment | `PODINFO_UI_MESSAGE` in the pod template |
| Preserve decisions | `/tmp/scout-canary-events.txt` | Event identities and messages |

## The feedback loop

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-050/module-03/labs/lab-02
```

The three checks are `blue-green-definition`, `gated-release` and `saved-events`. None passes in the untouched environment. Use `--watch` until the end, because a plain `astrona submit` can finish the attempt and delete the lab. Run the plain command once, in the last step.

## Define the analysis

Save this as `canary-scout.yaml`:

```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: scout
  namespace: starfleet
spec:
  provider: kubernetes
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: scout
  progressDeadlineSeconds: 120
  service:
    port: 80
    targetPort: http
  analysis:
    interval: 15s
    threshold: 2
    iterations: 3
    metrics: []
    webhooks:
      - name: scout-http-check
        type: pre-rollout
        url: http://flagger-loadtester.starfleet/
        timeout: 5s
        metadata:
          type: bash
          cmd: "curl -fsS --max-time 3 http://scout-canary.starfleet/status/500"
```

`provider` selects Kubernetes blue/green. `targetRef` identifies the Deployment. `service` exposes its named container port through port 80. `progressDeadlineSeconds` bounds the wait for workload readiness. The analysis waits 15 seconds between checks, allows two failures, and uses three iterations instead of traffic weights. The empty `metrics` list means no metrics backend is needed.

The webhook's `type: pre-rollout` controls when Flagger calls it. The nested `metadata.type: bash` tells load tester 0.39.0 to wait for the command to finish. `cmd` makes curl fail on an HTTP error and limits the request to three seconds. The outer five-second timeout gives the load tester time to return the command result.

Apply it:

```sh
kubectl apply -f canary-scout.yaml
```

Then check the result:

```sh
kubectl -n starfleet wait canary/scout --for=jsonpath='{.status.phase}'=Initialized --timeout=240s
kubectl -n starfleet get deploy,svc
```

Look for `scout-primary` and `scout-canary` Services and the primary Deployment. Flagger scales the target `scout` to zero between releases. Initialization establishes the baseline; it does not test the new release yet. The `blue-green-definition` check stays red because it needs the final, repaired webhook command.

## Let the gate fail

Change only the environment value in the Deployment template:

```sh
kubectl -n starfleet set env deploy/scout PODINFO_UI_MESSAGE=blocked
kubectl -n starfleet wait canary/scout --for=jsonpath='{.status.phase}'=Failed --timeout=300s
kubectl -n starfleet describe canary scout
kubectl -n starfleet logs deploy/flagger-loadtester | grep 'command failed'
kubectl -n starfleet exec deploy/shuttle -c shuttle -- curl -fsS http://scout.starfleet/
```

Look for a failed `scout-http-check` event and the threshold rollback. podinfo's `/status/500` deliberately returns an error. Curl exits with status 22, the load tester returns HTTP 500 to Flagger, and Flagger counts a failed check. At the threshold it marks the release `Failed` and scales the target down.

The Canary event does not show the curl error, because the Flagger webhook client discards the response body of an HTTP 5xx response. The load tester log has the command and its exit status. The client response should still contain `baseline` because the primary template was not updated. The `gated-release` check stays red because it still needs a successful release.

## Repair the gate and release again

In `canary-scout.yaml`, replace the `cmd` value with `"curl -fsS --max-time 3 http://scout-canary.starfleet/"`. Save the file, then apply it:

```sh
kubectl apply -f canary-scout.yaml
kubectl -n starfleet set env deploy/scout PODINFO_UI_MESSAGE=green
kubectl -n starfleet wait canary/scout --for=jsonpath='{.status.phase}'=Succeeded --timeout=360s
kubectl -n starfleet exec deploy/shuttle -c shuttle -- curl -fsS http://scout.starfleet/
```

Look for message `green`. Flagger runs the pre-rollout gate before advancing the iterations. After three iterations it copies the target template into `scout-primary` and waits for that Deployment to roll out. The public Service continues to select primary pods. The `blue-green-definition` and `gated-release` checks should now pass.

## Save the live events

Save the event identity, the Canary identity and the message on each line. The Go template uses `printf "%q"` to quote the message and escape embedded newlines:

```sh
kubectl -n starfleet get events --field-selector involvedObject.kind=Canary,involvedObject.name=scout -o go-template='{{range .items}}{{.metadata.uid}}{{"\t"}}{{.involvedObject.uid}}{{"\t"}}{{printf "%q" .message}}{{"\n"}}{{end}}' > /tmp/scout-canary-events.txt
cat /tmp/scout-canary-events.txt
```

Look for failed and passed pre-rollout checks, completed iterations and the promotion. A unique identifier (UID) ties each saved event to its live Kubernetes object. The `saved-events` check should now pass too. Stop the watch with Ctrl-C and submit once:

```sh
astrona submit --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-050/module-03/labs/lab-02
```

## If a check stays red

- **`blue-green-definition`:** Keep `metrics: []` and metadata `type: bash`. The default asynchronous command task cannot act as this gate.
- **`gated-release`:** Use the exact `/status/500` command and set `PODINFO_UI_MESSAGE=blocked` so the load tester log and the `scout` ReplicaSets record the failed release. Wait for `Failed` before repairing the gate. Wait for `Succeeded` before checking the client response. Changing the Canary alone does not replace the required Deployment environment change.
- **`saved-events`:** Save again after promotion. Use the exact path and tab-separated fields. Kubernetes events expire, so finish and submit while both releases remain in live events.
