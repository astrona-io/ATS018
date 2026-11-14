# Overview: Roll Out A Canary With Argo Rollouts (Playground)

This playground starts a cluster with a running application and the Argo Rollouts controller. A controller is a program that watches Kubernetes objects and changes the cluster to match their desired state. There is no grading or submission. Change the workload, inspect a release, or destroy the environment and start again.

## What's in the box

- A single-node kind cluster running Kubernetes 1.35.8.
- The Argo Rollouts 1.10.0 controller in `argo-rollouts`, with its custom resource definitions. A custom resource definition adds a new object kind to the Kubernetes application programming interface (API).
- The `starfleet` namespace with `scout`, a Deployment running five podinfo 6.14.0 replicas, and its Service on port 80. A Deployment manages pods through ReplicaSets; a Service selects ready pods and provides a stable address.
- The `shuttle` client, which sends requests with `curl`.
- Preloaded podinfo images 6.14.0 and 6.15.0. podinfo is a web application whose response includes its version.
- No Rollout, traffic router or metrics provider. A Rollout is the Argo Rollouts resource that defines a release strategy. A traffic router controls the share of requests sent to each version.

Use `kubectl` 1.35.8 and the `kubectl-argo-rollouts` plugin 1.10.0 on your machine. The plugin executable must be on your shell's `PATH`. The controller runs in the cluster; the plugin sends commands to it through Kubernetes. Point `kubectl` at this playground before running the helpers.

## Helpers

Paste these functions once in each new terminal. `ask_scout` prints the version returned through the Service. `show_scout_replicas` shows which ReplicaSets have ready pods. `watch_scout_release` watches a Rollout after you create one.

```sh
ask_scout() {
  kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout | grep '"version"'
}
show_scout_replicas() {
  kubectl -n starfleet get rs -l app=scout \
    -o custom-columns='NAME:.metadata.name,DESIRED:.spec.replicas,READY:.status.readyReplicas,IMAGE:.spec.template.spec.containers[0].image'
}
watch_scout_release() {
  kubectl argo rollouts get rollout scout -n starfleet --watch --timeout-seconds 5 --no-color
}
```

Use them as `ask_scout`, `show_scout_replicas` and, once a Rollout exists, `watch_scout_release`. The watch stops after five seconds without changing the release.

## Practice tasks

- Convert `scout` to a Rollout and keep the Service selector matching its pod labels. Expect a brief interruption if you delete the Deployment before creating the replacement.
- Release 6.15.0 with five replicas and a 20% pause. Compare the ready replica counts with the versions returned by ten requests.
- Promote to a 60% pause. Name the stable and canary ReplicaSets before promoting again.
- Add an explicit pause and read `spec.paused`. Check whether one promotion clears both that field and a canary step pause.
- Try a nonexistent image, abort it and prove the stable version still answers. Read the desired image to check whether abort changed it.
- Correct the image, abort the valid canary and retry it. Compare this with changing the template of an already aborted Rollout.
