# Overview: Gate A Blue/Green Release With Analysis (Playground)

This playground starts a fresh Kubernetes cluster for testing releases. There is no grading or submission. A blue/green release runs a stable configuration and a new configuration separately, then switches the active Service to the new pods in one step. A Service is a Kubernetes resource that selects ready pods by labels and gives them a stable address.

## What's in the box

The single-node cluster runs Kubernetes 1.35.8. The Argo Rollouts 1.10.0 controller manages releases; its command-line plugin must be on your machine's `PATH`. Prometheus collects application metrics every 15 seconds, and the Prometheus Operator configures that collection from Kubernetes resources.

| Namespace | What is in it |
| --- | --- |
| `argo-rollouts` | Argo Rollouts controller and custom resource definitions |
| `monitoring` | Prometheus Operator and one small Prometheus instance |
| `starfleet` | A two-replica `scout` Rollout, active Service `scout`, preview Service `scout-preview`, a PodMonitor and the `shuttle` client |

A Rollout is the Argo Rollouts resource that manages ReplicaSets for a release. A ReplicaSet keeps pods from one template running. Both Services initially select the same stable podinfo 6.15.0 configuration, which returns the message `stable`. Automatic promotion is disabled, and no AnalysisTemplate exists yet. An AnalysisTemplate defines metric queries and the conditions used to judge a release.

A PodMonitor tells the Prometheus Operator which pods to scrape. It copies the pod template hash to a Prometheus label named `rollouts_pod_template_hash`, so a query can select only the candidate configuration. Prometheus scrapes the dedicated metrics port 9797, where podinfo does not inject random errors. The readiness probe checks whether application port 9898 accepts a connection. The `shuttle` client sends one request per second to each Service. Keep preview traffic running: the active Service cannot generate measurements for a candidate it does not select.

Prometheus is available at `http://127.0.0.1:9090` while the playground runs. Inside the cluster its address is `http://kps-prometheus.monitoring.svc:9090`. The bootstrap installs its chart as hidden plumbing; the exercises use Prometheus and Argo Rollouts directly.

## Helpers

Paste these functions into each new terminal. `ask_scout` prints a Service response's version and message. `show_release` shows release progress, Service selectors and analysis phases. Service selector hashes identify the selected ReplicaSets.

```sh
ask_scout() {
  kubectl -n starfleet exec deploy/shuttle -- curl -s "http://$1" | grep -E '"(version|message)"'
}
show_release() {
  kubectl argo rollouts get rollout scout -n starfleet --no-color
  kubectl -n starfleet get service scout scout-preview -o custom-columns='NAME:.metadata.name,HASH:.spec.selector.rollouts-pod-template-hash'
  kubectl -n starfleet get analysisrun
}
```

Use `ask_scout scout` to test active traffic and `ask_scout scout-preview` to test the candidate. Use `show_release` to compare routing with the controller's decision. A failed release can leave a working stable application serving active requests.

## Practice tasks

- Change the podinfo message in a saved Rollout manifest. Apply it, compare the two Service responses and selectors, then promote the candidate.
- Create an AnalysisTemplate that accepts at least 99% non-error responses. Pass the candidate's template hash as an argument and attach it as pre-promotion analysis.
- Enable podinfo's `--random-error` flag in a candidate. Read the failed AnalysisRun and prove that the active Service still selects the stable ReplicaSet.
- Remove preview test traffic and inspect what the query returns. Explain why no measurements must not count as a passing release.
- Compare a check before promotion with a check after promotion. Decide which one can prevent a faulty candidate from serving active users at all.
