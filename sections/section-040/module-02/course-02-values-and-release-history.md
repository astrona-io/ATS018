# Values And Release History

The `scout` response currently says `flux-inline` because its HelmRelease includes that value. A HelmRelease is the Flux object that tells the helm controller which chart and values to install. When several releases share settings, you can store them in a ConfigMap and reference it instead of copying them into each release.

## Keep values in a ConfigMap

A ConfigMap is a Kubernetes object that stores non-secret configuration. The data entry below contains a values document for the podinfo chart, a package of Kubernetes templates. `valuesFrom` will tell the controller to read that document.

<!-- astrona:playground:renew -->

Save this as `configmap-scout-values.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: scout-values
  namespace: starfleet
  labels:
    reconcile.fluxcd.io/watch: Enabled
data:
  values.yaml: |
    ui:
      message: flux-configmap
```

Apply it:

```sh
kubectl apply -f configmap-scout-values.yaml
```

```text
configmap/scout-values created
```

The label `reconcile.fluxcd.io/watch: Enabled` asks Flux to react to changes in the referenced configuration object. The interval still provides regular reconciliation. Without the watch label, a change normally waits for a scheduled reconciliation instead of being applied at once.

Save this as `helmrelease-scout-values.yaml`:

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: scout
  namespace: starfleet
spec:
  interval: 1m
  timeout: 30s
  chartRef:
    kind: OCIRepository
    name: podinfo
  values:
    replicaCount: 1
    resources:
      requests:
        cpu: 10m
        memory: 32Mi
      limits:
        memory: 128Mi
    faults:
      unready: false
  valuesFrom:
  - kind: ConfigMap
    name: scout-values
    valuesKey: values.yaml
```

Apply it:

```sh
kubectl apply -f helmrelease-scout-values.yaml
```

The reference names the ConfigMap in the release's namespace. `valuesKey` selects its data entry. Referenced values merge in list order, and inline `values` override them. The inline block here keeps replica and resource settings, but removes the inline `ui.message` so the ConfigMap's message can take effect.

A Secret can supply values in the same way with `kind: Secret`. A Secret stores private values, but it still needs suitable access controls. Do not put a password in a ConfigMap merely because `valuesFrom` can read it. A missing required reference prevents the controller from constructing values and reports a release condition before a chart operation succeeds.

Then check the result:

```sh
flux reconcile helmrelease scout -n starfleet
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout-podinfo:9898
```

The response is shortened to the version and message lines:

```text
  "version": "6.15.0",
  "message": "flux-configmap",
```

The Service, a stable address for ready application pods, now reaches a pod with the referenced message. The helm controller read the ConfigMap, rendered the chart and upgraded the release. The ConfigMap does not directly change the pod; the new rendered Deployment does.

## Read the release history

A release is one installed copy of a chart. Each install, upgrade or rollback creates a numbered revision. Read the controller's history rather than guessing from a pod's creation time:

```sh
kubectl -n starfleet get helmrelease scout -o jsonpath='{range .status.history[*]}{.version}{" "}{.status}{" "}{.chartVersion}{"\n"}{end}'
```

```text
4 deployed 6.15.0+ff3d3e14728f
3 superseded 6.15.0+ff3d3e14728f
```

Read the revision number and status together; do not rely on list position. `deployed` identifies the release revision currently deployed, while `superseded` identifies an older successful revision. `failed` identifies an operation that failed. A chart version can stay the same across revisions because changing values also performs an upgrade.

Compare this with the initial history, captured before the repair:

```text
2 failed 6.15.0+ff3d3e14728f
1 deployed 6.15.0+ff3d3e14728f
```

The failed revision did not erase the previous successful record. History tells you what the release operations did, while the Ready condition describes whether the current desired state succeeded. Keep those two questions separate when diagnosing an upgrade.

You can now supply values from a namespaced configuration object and prove the controller used them. You can also distinguish a chart version from a release revision and identify the previous success before configuring recovery.

## Common pitfalls

> [!WARNING]
> - **Leaving the same setting inline and expecting referenced values to win.** Inline values override the referenced document.
> - **Referencing a ConfigMap in another namespace.** Values references are read from the HelmRelease namespace.
> - **Treating a chart version as a revision number.** Values changes create new revisions without changing the chart version.
> - **Assuming `deployed` means the current desired state succeeded.** A failed upgrade can leave a previous successful revision deployed.
