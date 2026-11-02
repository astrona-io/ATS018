# Deliver The Platform With Argo CD

The platform API and the first environment exist because a person ran `kubectl apply`. With GitOps, a controller reads Git and applies the objects, and nobody applies by hand. This part gives Argo CD the whole `platform-infra` repository. Crossplane objects have two details that an application does not: they must apply in a fixed order, and Argo CD does not know when one of them is Ready.

## One Application for the whole repository

An Argo CD `Application` names a Git path and a destination cluster. The repository has the platform API in `platform/` and one XR in each folder under `environments/`. One `Application` with the path `.` and `directory.recurse: true` reads all of them. Argo CD renders only YAML files, so the `README.md` is ignored.

Log in to Argo CD first. The initial administrator password is in the Secret `argocd-initial-admin-secret`:

<!-- astrona:playground:renew -->

```sh
argocd login 127.0.0.1:8080 --username admin --insecure \
  --password "$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
```

Save this as `application-scout-platform.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: scout-platform
  namespace: argocd
spec:
  project: default
  source:
    repoURL: http://gitea-http.gitea.svc:3000/starfleet/platform-infra.git
    targetRevision: main
    path: .
    directory:
      recurse: true
  destination:
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - SkipDryRunOnMissingResource=true
```

Apply it:

```sh
kubectl apply -f application-scout-platform.yaml
```

Then check the result after about a minute:

```sh
argocd app get scout-platform --refresh
```

```text
Name:               argocd/scout-platform
Project:            default
Server:             https://kubernetes.default.svc
Namespace:          
URL:                https://127.0.0.1:8080/applications/scout-platform
Source:
- Repo:             http://gitea-http.gitea.svc:3000/starfleet/platform-infra.git
  Target:           main
  Path:             .
SyncWindow:         Sync Allowed
Sync Policy:        Automated (Prune)
Sync Status:        Synced to main (389e613)
Health Status:      Healthy

GROUP                        KIND                         NAMESPACE             NAME                                      STATUS  HEALTH   HOOK  MESSAGE
platform.starfleet.dev       ScoutEnvironment             starfleet-production  scout                                     Synced                 scoutenvironment.platform.starfleet.dev/scout unchanged
platform.starfleet.dev       ScoutEnvironment             starfleet-staging     scout                                     Synced                 scoutenvironment.platform.starfleet.dev/scout unchanged
apiextensions.crossplane.io  CompositeResourceDefinition                        scoutenvironments.platform.starfleet.dev  Synced  Healthy        
apiextensions.crossplane.io  Composition                                        scoutenvironment                          Synced  Healthy
```

Your commit ID differs, and the `MESSAGE` column can differ too. The Argo CD application controller found the XRD, the `Composition` and both XRs in Git. The first three already existed from the last part, so it adopted them. The production XR was new, so it applied that one.

## Why the order matters

On an empty cluster, the XRs cannot apply before the XRD exists, because their kind is not known. Two Argo CD features solve this. A sync wave is a number in the annotation `argocd.argoproj.io/sync-wave`. Argo CD applies the lowest wave first and waits until its objects are healthy before it starts the next wave. The files in the repository use `-2` for the XRD, `-1` for the `Composition` and `0` for both XRs.

The second feature is the sync option `SkipDryRunOnMissingResource=true` in the `Application` above. Before a sync, Argo CD checks every object with a dry run. An XR fails that dry run while its kind is missing. The option skips the dry run for kinds that do not exist yet, so the XR applies after the XRD of the earlier wave.

## The health gap

The table above has a blank `HEALTH` column for both XRs. Argo CD has built-in health checks for common kinds, and it has one for the XRD and the `Composition`. It has none for `ScoutEnvironment`, so it cannot judge a kind it has never seen. The application is `Healthy` even though the production XR is not:

```sh
kubectl get scoutenvironments.platform.starfleet.dev -A
```

```text
NAMESPACE              NAME    SYNCED   READY   COMPOSITION        AGE
starfleet-production   scout   True     False   scoutenvironment   55s
starfleet-staging      scout   True     True    scoutenvironment   55s
```

Argo CD lets you add a health check for any kind with a Lua script in the ConfigMap `argocd-cm`. The key has the form `resource.customizations.health.<group>_<Kind>`. The script receives the object as `obj` and returns a status and a message. This script reads the `Ready` condition of the XR.

Save this as `argocd-cm-health-scoutenvironment.yaml`:

```yaml
data:
  resource.customizations.health.platform.starfleet.dev_ScoutEnvironment: |
    hs = {}
    hs.status = "Progressing"
    hs.message = "Waiting for the Ready condition"
    if obj.status ~= nil and obj.status.conditions ~= nil then
      for _, condition in ipairs(obj.status.conditions) do
        if condition.type == "Ready" then
          if condition.status == "True" then
            hs.status = "Healthy"
            hs.message = "Ready"
          else
            hs.status = "Degraded"
            hs.message = condition.reason .. ": " .. (condition.message or "")
          end
        end
      end
    end
    return hs
```

Patch the ConfigMap with it:

```sh
kubectl -n argocd patch configmap argocd-cm --patch-file argocd-cm-health-scoutenvironment.yaml
argocd app get scout-platform --refresh
```

```text
Health Status:      Degraded
GROUP                        KIND                         NAMESPACE             NAME                                      STATUS  HEALTH    HOOK  MESSAGE
platform.starfleet.dev       ScoutEnvironment             starfleet-production  scout                                     Synced  Degraded        scoutenvironment.platform.starfleet.dev/scout unchanged
platform.starfleet.dev       ScoutEnvironment             starfleet-staging     scout                                     Synced  Healthy         scoutenvironment.platform.starfleet.dev/scout unchanged
apiextensions.crossplane.io  CompositeResourceDefinition                        scoutenvironments.platform.starfleet.dev  Synced  Healthy         
apiextensions.crossplane.io  Composition                                        scoutenvironment                          Synced  Healthy         
```

The output is shortened to the header line for health and the resource table. Argo CD picked up the change without a restart. The production XR is `Degraded` and the whole application is `Degraded`. Staging is `Healthy`.

Argo CD now tells the truth about the environments. It delivered everything in Git in the right order and reports what Crossplane reports. The production XR is Ready `False`. The open question is why, and where the fix belongs.

## Common pitfalls

> [!WARNING]
> - Do not trust a `Healthy` application for a kind that Argo CD has no health check for. The blank `HEALTH` column means "unknown", and the application stayed `Healthy` while production was not Ready.
> - The key in `argocd-cm` must use the group and the kind exactly: `platform.starfleet.dev_ScoutEnvironment`. A wrong key is silently ignored.
> - Without `SkipDryRunOnMissingResource=true`, a first sync on an empty cluster can fail on the XRs. Keep the option on any `Application` that delivers a definition together with its instances.
> - Do not let two controllers apply the same object. Deliver each object with one tool only.
