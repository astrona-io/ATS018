# Overview: Deliver Helm Releases With Flux (Playground)

Flux installs a chart through a HelmRelease, an object that defines an
installed package and its values. This playground starts with a failed
upgrade so you can read its status and configure recovery.

## What's in the box

- Kubernetes 1.35, Flux 2.9.6 and the source, kustomize, helm and notification controllers.
- The `podinfo` OCIRepository in `starfleet`, which fetches a chart from an Open Container Initiative (OCI) registry.
- The HelmRelease `scout`, with a successful revision followed by a failed upgrade.
- The `shuttle` client in `starfleet` and podinfo images preloaded.

The failed upgrade sets `faults.unready: true`, so podinfo rejects readiness
checks. No install or upgrade remediation is configured.

## Helpers

Paste these functions in a terminal. `show_release` reads release status and
history. `ask_scout` checks the Service from the client pod.

```sh
show_release() {
  flux get helmreleases -n starfleet
  kubectl -n starfleet get helmrelease scout -o jsonpath='{.status.history}'
}
ask_scout() {
  kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout-podinfo:9898
}
```

## Practice tasks

- Read the failed upgrade message and compare it with the Deployment's container arguments.
- Enable upgrade remediation with rollback, retry the upgrade, and check the successful revision still answers.
- Put application values in a ConfigMap and reference it with valuesFrom.
- Compare the Ready condition with the deployed revision in history after rollback.
