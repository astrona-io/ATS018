# Question

Solve this question on: `terminal`

## Scenario

The `scout` Deployment in `starfleet` runs podinfo 6.14.0. Its initialized
Flagger `Canary` promotes every pod-template change without human approval.
The team needs approval before Flagger starts a new release. Flagger 1.45.0
and load tester 0.39.0 are installed without a service mesh or metrics backend.
A `Canary` is the Flagger resource that defines a workload's release policy.

## Tasks

1. **Require approval.** Add one webhook to Canary `scout`: name
   `scout-approval`, type `confirm-rollout`, URL
   `http://flagger-loadtester.starfleet/gate/check`, timeout `5s`.
   Keep the existing Kubernetes provider, Deployment target, Service and
   analysis settings (`interval: 15s`, `threshold: 3`, `iterations: 3`,
   `metrics: []`). Keep analysis enabled and the Canary unsuspended.
2. **Start a gated release.** Close the load tester gate for name `scout`
   and namespace `starfleet`. Change container `scout` in target Deployment
   `scout` to `ghcr.io/stefanprodan/podinfo:6.15.0`. Never edit
   `scout-primary`. Wait for Canary phase `Waiting`.
3. **Save the waiting events.** Before opening the gate, save the Canary's
   events to `/tmp/scout-waiting-events.txt`. Each line must contain the
   event unique identifier (UID), the involved Canary UID and the Go-quoted
   message, separated by tabs. Use a Kubernetes Go template with
   `printf "%q"` for the message. Include the waiting-for-approval event;
   do not replace this snapshot with events collected after approval.
4. **Approve and finish.** Open the gate for `scout` in `starfleet`. Wait
   for Canary phase `Succeeded` and completed promotion. Keep the gate open
   and the approval webhook configured. Both target and primary Deployments
   must specify podinfo 6.15.0, and `scout-primary` must finish its rollout.
   Keep the public `scout` Service selecting primary pods and confirm a
   request from `shuttle` returns version `6.15.0`.
