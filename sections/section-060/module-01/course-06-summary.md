# Summary

Crossplane turns Kubernetes into a control plane for resources beyond pods. Two kinds of package give it that ability. A `Provider` runs a controller and adds the kinds for one system. A `Function` adds the logic that a `Composition` calls. Both must be `INSTALLED` and `HEALTHY` before anything depends on them. A provider that acts as its own service account can only create what its roles allow, and a `ClusterProviderConfig` connects it to the cluster.

A platform team defines its own API with a `CompositeResourceDefinition` (XRD) and maps it to real objects with a `Composition`. In `Pipeline` mode, the `Composition` calls functions, and `function-patch-and-transform` copies fields from the composite resource (XR) into the composed `Object` resources. Another team creates one small XR, and Crossplane creates and maintains the Deployment and the Service behind it. Status has three levels: the XR, the `Object` resources and the real objects. At each level, `Synced` says that the object could be applied, and `Ready` says that it works. By default an `Object` is Ready as soon as it exists, so a readiness rule that reads the observed Deployment is what makes `Ready` mean that the pods run.

A GitOps controller delivers these objects like any others, with two extra concerns. The definition must exist before its instances. Argo CD solves this with sync waves and `SkipDryRunOnMissingResource=true`, and Flux solves it with `dependsOn` between two `Kustomization` objects. The controller must also learn the real health of an XR. Argo CD has no built-in check for a custom kind, so the application stays `Healthy` until a Lua health check reads the `Ready` condition. Flux reads the `Ready` condition itself when `wait: true` is set, and it reports `HealthCheckFailed` with the name of the unready object.

When an XR is not Ready, go down the layers: the `Ready` condition of the XR names the composed resource, the conditions of the `Object` separate an apply error from an unready workload, and the pods and events give the reason. The fix belongs in the XR in Git. A manual edit of a composed object is reverted by Crossplane, and a change to the XR in the cluster is reverted by the GitOps controller.

- A `Provider` and a `Function` are `Healthy` when their pods run.
- An XRD defines a kind, and a `Composition` maps it to objects.
- `Synced` means applied without error, and `Ready` means working.
- Argo CD orders with sync waves, and Flux orders with `dependsOn`.
- Fix a not-Ready XR in Git, one layer at a time from the XR down to the pods.

<!-- astrona:playground:destroy -->
