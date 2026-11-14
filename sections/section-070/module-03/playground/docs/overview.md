# Overview: Shift Canary Traffic With Argo Rollouts And A Traffic Router (Playground)

This playground starts a fresh Kubernetes cluster for testing canary releases that use a traffic router. There is no grading or submission. A traffic router is a component that decides which backend receives each request. Here it is the Kubernetes Gateway API: a `Gateway` opens a listener, and an `HTTPRoute` sends the requests to Services with a weight for each one.

## What's in the box

The single-node cluster runs Kubernetes 1.35.8. The Argo Rollouts 1.10.0 controller manages releases, and its Gateway API plugin (v0.17.0) edits the `HTTPRoute`. Envoy Gateway applies the route to live requests. Prometheus collects application metrics every 15 seconds. The Argo Rollouts `kubectl` plugin must be on your machine's `PATH`.

| Namespace | What is in it |
| --- | --- |
| `argo-rollouts` | Argo Rollouts controller and custom resource definitions |
| `envoy-gateway-system` | Envoy Gateway, which applies the `Gateway` and `HTTPRoute` objects |
| `monitoring` | Prometheus Operator and one small Prometheus instance |
| `starfleet` | A two-replica `scout` Rollout, the Services `scout` and `scout-canary`, the `scout-gateway` Gateway, the `scout-route` HTTPRoute, a PodMonitor and the `shuttle` client |

A Rollout is the Argo Rollouts resource that manages ReplicaSets for a release. A ReplicaSet keeps pods from one template running. The `scout` Rollout starts on podinfo 6.14.0 with the message `stable` and has no canary steps yet, so it is `Healthy`. The `HTTPRoute` sends 100% of requests to `scout` and 0% to `scout-canary`. No AnalysisTemplate exists. An AnalysisTemplate defines metric queries and the conditions used to judge a release.

The `shuttle` pod sends requests to the Gateway about five times a second. These requests give Prometheus data about the canary. The Gateway address is a cluster IP address, so it works only inside the cluster. `shuttle` has it in the environment variable `GATEWAY`. A PodMonitor tells the Prometheus Operator which pods to scrape. It copies the pod template hash to the Prometheus label `rollouts_pod_template_hash`, so a query can select only the canary pods. Prometheus scrapes the metrics port 9797, where podinfo does not inject random errors.

Prometheus is available at `http://127.0.0.1:9090` while the playground runs. Inside the cluster its address is `http://kps-prometheus.monitoring.svc:9090`. The bootstrap installs the Prometheus chart and the Gateway API controller as hidden plumbing; the exercises use Argo Rollouts, the `HTTPRoute` and Prometheus directly.

## Helpers

Paste these functions into each new terminal. `count_versions` sends 100 requests through the Gateway and counts the `version` field in the responses. `ask_scout` sends one request with an optional header and prints the version and message. `show_route` prints each rule of the `HTTPRoute` with its backend weights.

```sh
count_versions() {
  kubectl -n starfleet exec deploy/shuttle -- sh -c 'for i in $(seq 1 100); do curl -s "http://$GATEWAY/" | grep -o "\"version\": \"[^\"]*\""; done | sort | uniq -c'
}
ask_scout() {
  kubectl -n starfleet exec deploy/shuttle -- sh -c "curl -s $1 http://\$GATEWAY/ | grep -E '\"(version|message)\"'"
}
show_route() {
  kubectl -n starfleet get httproute scout-route -o jsonpath='{range .spec.rules[*]}{.name}{" "}{range .backendRefs[*]}{.name}={.weight} {end}{"\n"}{end}'
}
```

Use `ask_scout ""` for a request without a header and `ask_scout "-H 'x-canary: yes'"` for a request with one. Use `show_route` to compare the weights with the `count_versions` result.

## Practice tasks

- Add two canary steps with `setWeight` and `pause: {}` to the Rollout. Change the image to podinfo 6.15.0, promote through each step, and compare the route weights with the version counts.
- Add `managedRoutes`, `setCanaryScale` and `setHeaderRoute` steps. Prove that a request with the header reaches the canary and a request without it does not.
- Create an AnalysisTemplate that accepts at least 99% successful responses for the canary's template hash. Attach it as a background analysis with `startingStep`.
- Enable podinfo's `--random-error` flag in a canary. Read the failed AnalysisRun and prove with `show_route` and 100 requests that the stable version serves all traffic.
- Set `initialDelay` to `0s` in the AnalysisTemplate, start a release and read the first measurement. Explain why a measurement without data must not count as a pass.
