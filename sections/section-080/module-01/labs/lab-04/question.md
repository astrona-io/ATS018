# Question

Solve this question on: `terminal`

Canary `scout` in `starfleet` is initialized with podinfo `6.14.0`. Istio, Prometheus and the Flagger load tester are running. Its metric policy and load hook work, but promotion requires no approval.

## Tasks

1. Add webhook `scout-approval` with type `confirm-promotion`, URL `http://flagger-loadtester.starfleet/gate/check` and timeout `5s`. Preserve the Istio provider, workload, Service, load hook and metric policy: `15s` checks, threshold `3`, weight steps `10`, maximum weight `50`, and request-success-rate minimum `99` over `30s`.
2. Close the stored gate for `scout` in `starfleet`, then change the target Deployment image to `ghcr.io/stefanprodan/podinfo:6.15.0`.
3. Wait for `WaitingPromotion`. Inspect the generated VirtualService's live 50/50 route and confirm the primary still runs `6.14.0`. The displayed canary weight alone is insufficient.
4. While promotion waits, save the Canary's events with the command below. Ensure they include the waiting-for-promotion-approval event before opening the gate.
5. Open the gate, wait for `Succeeded`, and verify that the primary Deployment and the public Service serve `6.15.0`.

```sh
CANARY_UID=$(kubectl -n starfleet get canary scout -o jsonpath='{.metadata.uid}')
kubectl -n starfleet get events --field-selector "involvedObject.uid=$CANARY_UID" \
  -o json > /tmp/scout-promotion-events.json
```

Keep the Canary and event snapshot for grading. Do not remove the metric, use `confirm-rollout`, manually promote, or edit generated primary workloads and routes.

Learner work: about 15 minutes. Allow additional time for cluster startup, metric collection and traffic steps.
