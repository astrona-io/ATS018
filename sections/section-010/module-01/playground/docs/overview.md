# Overview: Build Environment Overlays With Kustomize (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with a few empty namespaces and a client pod, and then waits. There is no task, no `astrona submit` and no pass or fail. Write Kustomize files, apply them, break them, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` cluster running Kubernetes 1.35. `kubectl` is already pointed at it, and `kubectl` has Kustomize built in.
- The node already holds the `podinfo` images `ghcr.io/stefanprodan/podinfo:6.14.0` and `6.15.0`. `podinfo` is a small web application on port `9898` that answers each request with a JSON document showing its `version` and a `message`. It reads the message from the environment variable `PODINFO_UI_MESSAGE`.

  | Namespace | What is in it |
  | --- | --- |
  | `starfleet` | `shuttle`, a client pod with `curl`; send test requests from here |
  | `starfleet-staging` | Nothing; a place to deploy a staging overlay |
  | `starfleet-production` | Nothing; a place to deploy a production overlay |

- There is no `scout` workload, no GitOps controller and no Helm release. You write every manifest yourself, in a folder on your own machine.

## Helpers

Paste these once in each new terminal. `ask_scout` sends one request from the `shuttle` pod to the `scout` Service in the namespace you name and prints the `version` and `message` lines. `show_scout` lists the `scout` objects and the ConfigMaps in that namespace.

```sh
ask_scout() {
  kubectl -n starfleet exec deploy/shuttle -- curl -s "http://scout.$1" | grep -E '"(version|message)"'
}
show_scout() {
  kubectl -n "$1" get deployment,service,configmap
}
```

Use them like this: `ask_scout starfleet-staging`, `show_scout starfleet-production`.

## Practice tasks

- Add a third overlay for a namespace you create yourself, with two replicas and the image `6.15.0`. Render it before you create the namespace, and predict what `kubectl diff -k` prints before you run it.
- Move the production memory change from a JSON 6902 patch to a strategic merge patch file. Render both versions and compare the output line by line.
- Change a generator literal three times and apply each change. Count the ConfigMaps in the namespace, then delete the ones the Deployment no longer uses.
- Add `options: {disableNameSuffixHash: true}` to the generator, change the literal, apply it, and check whether the `scout` pods restart and which `message` they return.
- Give a patch `target` a name that does not exist. Check the exit code of `kubectl kustomize`, then find the problem with `kubectl diff -k`.
