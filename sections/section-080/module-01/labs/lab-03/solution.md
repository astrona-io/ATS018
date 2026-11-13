# Solution Walkthrough

You will add approval to the existing `scout` Canary, save its waiting events,
and release podinfo 6.15.0. A `Canary` is the Flagger resource that names a
workload and defines its release policy. Work in the lab's Kubernetes context.

| Goal | Object or endpoint | Result |
| --- | --- | --- |
| Require approval | Canary webhook `confirm-rollout` | Wait before candidate scale-up |
| Start a release | Target Deployment `scout` | New pod template |
| Preserve evidence | `/tmp/scout-waiting-events.txt` | Waiting event identities and messages |
| Give approval | Load tester `/gate/open` | Flagger resumes on its next check |

## The feedback loop

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-080/module-01/labs/lab-03
```

The checks are `approval-definition`, `waiting-events` and `approved-release`.
None passes in the untouched environment. Use `--watch` until the end, because
 a plain `astrona submit` can finish the attempt and delete the lab. Run the
plain command once, in the last step.

## Step 1: Add the confirmation webhook

The existing Canary uses Kubernetes blue/green analysis. This strategy runs
iterations without a service mesh. Save this as `canary-scout.yaml`:

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
    threshold: 3
    iterations: 3
    metrics: []
    webhooks:
      - name: scout-approval
        type: confirm-rollout
        url: http://flagger-loadtester.starfleet/gate/check
        timeout: 5s
```

`provider` keeps Kubernetes blue/green. `targetRef` identifies the Deployment
whose template Flagger watches. `progressDeadlineSeconds` bounds workload
readiness checks. `service` preserves port 80 and the named target port.
The analysis retains its 15-second interval, three-failure threshold, three
iterations and empty metrics list. The webhook's `name` appears in events;
`type: confirm-rollout` makes it an approval check before scale-up. `url`
uses the load tester's stateful gate and `timeout` limits each request.

Apply it:

```sh
kubectl apply -f canary-scout.yaml
```

Then check the result:

```sh
kubectl -n starfleet get canary scout -o yaml
kubectl -n starfleet get deploy scout-primary -o jsonpath='{.spec.template.spec.containers[?(@.name=="scout")].image}{"\n"}'
```

Look for the confirmation webhook and primary image `6.14.0`. Changing the
Canary policy alone does not start a new release. The watch terminal should
show `approval-definition` passing; the other two checks still fail.

## Step 2: Close the gate and trigger a release

The load tester stores gate state by workload name and namespace. Send the
same identity in each request. The `-d` flag sends an HTTP (Hypertext Transfer
Protocol) POST request with that body:

```sh
kubectl -n starfleet exec deploy/shuttle -c shuttle -- curl -fsS -d '{"name":"scout","namespace":"starfleet"}' http://flagger-loadtester.starfleet/gate/close
kubectl -n starfleet set image deploy/scout scout=ghcr.io/stefanprodan/podinfo:6.15.0
kubectl -n starfleet wait canary/scout --for=jsonpath='{.status.phase}'=Waiting --timeout=180s
kubectl -n starfleet describe canary scout
kubectl -n starfleet get deploy scout,scout-primary
```

Look for phase `Waiting` and the event message
`Halt scout.starfleet advancement waiting for approval scout-approval`.
The target stays at zero replicas and the primary still serves 6.14.0.
If the event has not arrived yet, repeat the describe command before saving.
You changed `scout`, the watched Deployment. Flagger owns `scout-primary`.
The watch terminal still shows only `approval-definition` passing.

## Step 3: Save evidence before approval

Save the events now, while the gate is closed. A unique identifier (UID)
identifies each Kubernetes object. This Go template writes the event UID,
Canary UID and quoted message as tab-separated fields. `printf "%q"`
escapes any newline inside a message:

```sh
kubectl -n starfleet get events --field-selector involvedObject.kind=Canary,involvedObject.name=scout -o go-template='{{range .items}}{{.metadata.uid}}{{"\t"}}{{.involvedObject.uid}}{{"\t"}}{{printf "%q" .message}}{{"\n"}}{{end}}' > /tmp/scout-waiting-events.txt
cat /tmp/scout-waiting-events.txt
```

Look for the waiting-for-approval message. The watch terminal should now show
`waiting-events` passing too. If it does not, save again while still waiting.
Keep this snapshot: later events will record approval and promotion, and the
grader compares the saved rows with live events for this same Canary.

## Step 4: Open the gate and wait for promotion

Open the gate, then check it. Curl's `-i` flag includes the response status:

```sh
kubectl -n starfleet exec deploy/shuttle -c shuttle -- curl -fsS -d '{"name":"scout","namespace":"starfleet"}' http://flagger-loadtester.starfleet/gate/open
kubectl -n starfleet exec deploy/shuttle -c shuttle -- curl -i -d '{"name":"scout","namespace":"starfleet"}' http://flagger-loadtester.starfleet/gate/check
kubectl -n starfleet wait canary/scout --for=jsonpath='{.status.phase}'=Succeeded --timeout=360s
kubectl -n starfleet rollout status deploy/scout-primary --timeout=120s
kubectl -n starfleet describe canary scout
kubectl -n starfleet get deploy scout-primary -o jsonpath='{.spec.template.spec.containers[?(@.name=="scout")].image}{"\n"}'
kubectl -n starfleet exec deploy/shuttle -c shuttle -- curl -fsS http://scout.starfleet/
```

The gate check should return status 200. Look for the passing confirmation
and completed promotion events, primary image `6.15.0` and response version
`6.15.0`. Flagger checks the open gate on its next analysis interval, runs
three iterations, and copies the target template into the primary. Wait for
the promotion event if it is not visible yet. The watch terminal should show
all three checks passing. Keep the saved file from the waiting phase.

## Step 5: Submit

Stop the watch with Ctrl-C and submit once. A pass or a fail finishes the
attempt and deletes the lab:

```sh
astrona submit --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-080/module-01/labs/lab-03
```

## If a check stays red

- **`approval-definition`:** Keep the webhook at `/gate/check` with type
  `confirm-rollout`. Keep the original analysis settings and leave analysis enabled.
- **`waiting-events`:** Save before approval and include all three fields in
  each row. Do not overwrite the file after promotion. Events expire; finish
  while the saved events still exist in Kubernetes.
- **`approved-release`:** Open the gate for `scout` in `starfleet`, then wait
  for `Succeeded`, primary readiness and the promotion event. Change the
  target Deployment image, never the primary Deployment.
