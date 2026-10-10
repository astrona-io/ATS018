# Helm Charts As A Source

Not every application ships as a Kustomize folder. Many are published as Helm charts: packages of templates plus default values, stored in a chart repository or an OCI registry. Argo CD renders a chart in the same loop it renders an overlay, so the same `Application` object can deliver it. This part delivers `scout` a third time, from the public `podinfo` chart, and sets its values in the `Application`.

## A chart source

When `source` has a `chart` field instead of a `path`, the repo server treats `repoURL` as a Helm chart repository and renders that chart. `targetRevision` is then the chart version, not a Git branch. Values go under `source.helm`.

<!-- astrona:playground:renew -->

Save this as `application-scout-preview.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: scout-preview
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ghcr.io/stefanprodan/charts
    chart: podinfo
    targetRevision: 6.15.0
    helm:
      releaseName: scout
      valuesObject:
        fullnameOverride: scout
        replicaCount: 2
        ui:
          message: preview
  destination:
    server: https://kubernetes.default.svc
    namespace: starfleet-preview
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

The `podinfo` chart is published in the OCI registry `ghcr.io`, under `stefanprodan/charts`. The `helm` block has the fields you will use most:

- `releaseName` is the name the chart's templates see as the release name. Without it, Argo CD uses the `Application` name.
- `valuesObject` holds values as YAML, merged over the chart's own defaults. Here it names the objects `scout`, runs two replicas and sets the message.
- `parameters` (not used above) sets single values, like `--set name=value` on the Helm command line.
- `valueFiles` (not used above) lists values files that live next to the chart.

Apply it:

```sh
kubectl apply -f application-scout-preview.yaml
```

Then check the result after a few seconds:

```sh
argocd app get scout-preview
```

The end of the output is:

```text
Source:
- Repo:             ghcr.io/stefanprodan/charts
  Target:           6.15.0
SyncWindow:         Sync Allowed
Sync Policy:        Automated (Prune)
Sync Status:        Synced to 6.15.0
Health Status:      Healthy

GROUP  KIND        NAMESPACE          NAME               STATUS   HEALTH   HOOK  MESSAGE
       Namespace                      starfleet-preview  Running  Synced         namespace/starfleet-preview created
       Service     starfleet-preview  scout              Synced   Healthy        service/scout created
apps   Deployment  starfleet-preview  scout              Synced   Healthy        deployment.apps/scout created
```

The status reads `Synced to 6.15.0`: the version of the chart, where a Git source shows a commit. The chart's Service listens on port `9898`, so send the test request there:

```sh
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet-preview:9898
```

The important lines of the response are:

```text
  "version": "6.15.0",
  "message": "preview",
```

The message comes from `valuesObject`, rendered by the chart's templates.

## Argo CD renders, it does not install

The repo server runs the chart's templates and returns plain manifests. The application controller then applies them like any other manifests. No Helm release is installed, so nothing in the cluster records a Helm release history. List the Secrets in the namespace, where a Helm installation would keep one Secret per release version:

```sh
kubectl -n starfleet-preview get secrets
```

You should see:

```text
No resources found in starfleet-preview namespace.
```

This has two effects. Rollback is a Git or `Application` change, not a Helm rollback: to go back, set `targetRevision` or the values back and let Argo CD sync. And Argo CD knows which objects belong to the application by an annotation it adds to each one:

```sh
kubectl -n starfleet-preview get deploy scout -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/tracking-id}'
```

You should see:

```text
scout-preview:apps/Deployment:starfleet-preview/scout
```

The value is `<application>:<group>/<kind>:<namespace>/<name>`. Since Argo CD 3.0 this annotation is the default way to track objects. Older versions used the label `app.kubernetes.io/instance`, which charts often set themselves and which therefore caused conflicts.

## Where to change values

The `argocd` tool can change values on a running application:

```sh
argocd app set scout-preview --helm-set replicaCount=3
kubectl -n starfleet-preview get deploy scout
```

You should see:

```text
NAME    READY   UP-TO-DATE   AVAILABLE   AGE
scout   3/3     3            3           30s
```

The command wrote a `parameters` entry into the `Application` object in the cluster, and self-heal applied it. That is fine in a playground, but it is a change outside Git. If the `Application` object itself is delivered from Git, as it usually is on a platform, the next sync of that parent removes your parameter again. Make lasting changes in `application-scout-preview.yaml` and keep that file in Git.

## Kustomize or Helm source

Both sources end the same way: plain manifests that the application controller compares and applies. Choose by what you receive. Your own services are usually easiest as Kustomize overlays, because every file is a plain manifest you can read. Software published by someone else, such as an ingress controller or a database, usually comes as a chart, and you only set values. Argo CD detects the type from the source: a `chart` field means Helm, a folder with `kustomization.yaml` means Kustomize, and a folder with a `Chart.yaml` file is also rendered as a Helm chart.

You can now deliver the same service from a Git folder and from a Helm chart, set chart values in the `Application`, and explain why no Helm release exists in the cluster. Together with sync policies and health, that covers what one `Application` can do. The open question is how to manage dozens of them without writing each one by hand.

## Common pitfalls

> [!WARNING]
> - **Giving a Git branch as `targetRevision` for a chart.** With `chart`, `targetRevision` is the chart version.
> - **Forgetting `releaseName`.** Templates that use the release name then use the `Application` name, and object names change.
> - **Rolling back with Helm.** There is no Helm release; change the version or values in the `Application` and let Argo CD sync.
> - **Changing values with `argocd app set` on an `Application` that comes from Git.** The parent sync removes the change. Edit the file in Git.
