# Chart Sources And HelmRelease

The `scout` upgrade failed because its new pods never became ready. A HelmRelease is the Flux object that defines an installed chart, its values and its recovery rules. Its conditions tell you whether the controller failed to fetch a chart, install it or upgrade an existing release. Start with those conditions before changing anything.

## Read the failing operation

A chart is a package of Kubernetes templates and default values. A release is one installed copy, and a revision numbers each install, upgrade or rollback. The helm controller runs those operations and records their result in the HelmRelease status.

<!-- astrona:playground:renew -->

Read the starting release and its conditions:

```sh
flux get helmreleases -n starfleet
kubectl -n starfleet get helmrelease scout -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason}: {.message}{"\n"}{end}'
```

The condition output was:

```text
Stalled=True RetriesExceeded: Failed to upgrade after 1 attempt(s)
Ready=False UpgradeFailed: Helm upgrade failed for release starfleet/scout with chart podinfo@6.15.0+ff3d3e14728f: timeout waiting for: [Deployment/starfleet/scout-podinfo status: 'InProgress']
Released=False UpgradeFailed: Helm upgrade failed for release starfleet/scout with chart podinfo@6.15.0+ff3d3e14728f: timeout waiting for: [Deployment/starfleet/scout-podinfo status: 'InProgress']
```

`UpgradeFailed` says an existing release failed to upgrade. The named Deployment, an object that keeps application pods running, stayed `InProgress`. `Stalled=True` with `RetriesExceeded` says the controller has no attempts left under its current settings. It will not fix this by repeating the same failed operation forever.

The playground deliberately sets `faults.unready: true`. Podinfo then fails its readiness check. A readiness probe is a check Kubernetes uses to decide whether a pod can receive Service traffic. This chart fixes the probe command at `/readyz`; it does not expose a readiness-path value.

## Select the chart source

An OCIRepository fetches a package from an Open Container Initiative (OCI) registry and publishes an artifact, a stored copy another controller can read. Here it fetches chart version 6.15.0. It does not install that chart itself.

Save this as `ocirepository-podinfo.yaml`:

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: OCIRepository
metadata:
  name: podinfo
  namespace: starfleet
spec:
  interval: 1m
  url: oci://ghcr.io/stefanprodan/charts/podinfo
  ref:
    tag: 6.15.0
```

Apply it:

```sh
kubectl apply -f ocirepository-podinfo.yaml
```

The source already exists in this playground, so this applies the same desired state. Then check the result:

```sh
flux get sources oci -n starfleet
```

```text
NAME   	REVISION              	SUSPENDED	READY	MESSAGE                                             
podinfo	6.15.0@sha256:ff3d3e14	False    	True 	stored artifact for digest '6.15.0@sha256:ff3d3e14'
```

The source is Ready even though the release is failing. Its digest identifies the downloaded chart artifact. That separates a fetch problem from a release problem.

A HelmRepository is another source kind. For an ordinary chart repository, it fetches the repository index. A HelmRelease then selects a chart and version through `spec.chart.spec`, naming that HelmRepository in `sourceRef`. With the OCIRepository shown here, `chartRef` refers directly to the chart artifact. Use the source form the registry actually provides.

## Repair the release with inline values

The release points to the source by kind and name. Both objects live in `starfleet`. `interval` sets the reconciliation interval, and `timeout` bounds the chart operation. Inline `values` overrides chart defaults.

Save this as `helmrelease-scout.yaml`:

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
    ui:
      message: flux-inline
```

Apply it:

```sh
kubectl apply -f helmrelease-scout.yaml
```

The explicit `unready: false` repairs the deliberate fault. A specification change also gives the controller new desired state to try. Then check the result:

```sh
kubectl -n starfleet wait helmrelease/scout --for=condition=Ready --timeout=90s
flux get helmreleases -n starfleet
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout-podinfo:9898
```

The release status was:

```text
NAME 	REVISION           	SUSPENDED	READY	MESSAGE                                                                                      
scout	6.15.0+ff3d3e14728f	False    	True 	Helm upgrade succeeded for release starfleet/scout.v3 with chart podinfo@6.15.0+ff3d3e14728f
```

The response is shortened to the version and message lines:

```text
  "version": "6.15.0",
  "message": "flux-inline",
```

The helm controller upgraded the release to revision 3, and the client reached the new settings. The Service `scout-podinfo` exposes the chart's pods on port 9898. A Service gives ready pods a stable network address.

You can now separate source readiness from a failed upgrade, select a chart artifact and repair a release through its values. The next decision is where those values should live and how to read the revisions the controller leaves behind.

## Common pitfalls

> [!WARNING]
> - **Treating a Ready source as a Ready release.** Downloading a chart does not prove its workloads run.
> - **Using an unsupported chart value.** This chart does not read `readinessProbe.httpGet.path`; use its actual values schema.
> - **Editing the generated Deployment as the fix.** Change HelmRelease values; the next controller operation reapplies the chart.
> - **Removing the HelmRelease to clear a failure.** Deleting it normally uninstalls the release and its workloads.
