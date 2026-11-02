# Deliver The Platform With Flux

The exam lets you choose Argo CD or Flux for a delivery task, so you must be able to do the same job with both. This part hands the objects that Argo CD delivered to Flux. Flux has no sync waves and no Lua health scripts. It orders work with `dependsOn` and it checks health with `wait`, and both work with Crossplane objects as they are.

## Hand the objects over to Flux

Two controllers must not apply the same objects. Remove the Argo CD `Application` first. The `Application` has no finalizer, so deleting it does not delete the objects it created. Check that the XRs are still there:

<!-- astrona:playground:renew -->

```sh
kubectl -n argocd delete application scout-platform
kubectl get scoutenvironments.platform.starfleet.dev -A
```

```text
application.argoproj.io "scout-platform" deleted from argocd namespace
NAMESPACE              NAME    SYNCED   READY   COMPOSITION        AGE
starfleet-production   scout   True     True    scoutenvironment   2m46s
starfleet-staging      scout   True     True    scoutenvironment   2m46s
```

Flux needs two kinds of object. A `GitRepository` is the Flux source object that fetches a Git repository and stores the content as an artifact. A Flux `Kustomization` applies the content of one path of a source and keeps it equal to Git. The names are alike, but a Flux `Kustomization` is not the Kustomize `kustomization.yaml` file.

Save this as `gitrepository-platform-infra.yaml`. The Secret `platform-infra-auth` holds the Gitea user name and password and exists already:

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: platform-infra
  namespace: flux-system
spec:
  interval: 1m
  url: http://gitea-http.gitea.svc:3000/starfleet/platform-infra.git
  ref:
    branch: main
  secretRef:
    name: platform-infra-auth
```

The platform API must exist before the environments, and the environments must be healthy before Flux calls the delivery done. Two `Kustomization` objects with `dependsOn` and `wait` express this. Save this as `kustomization-platform.yaml`:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: platform
  namespace: flux-system
spec:
  interval: 1m
  sourceRef:
    kind: GitRepository
    name: platform-infra
  path: ./platform
  prune: true
  wait: true
  timeout: 2m
```

Save this as `kustomization-environments.yaml`:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: environments
  namespace: flux-system
spec:
  interval: 1m
  dependsOn:
    - name: platform
  sourceRef:
    kind: GitRepository
    name: platform-infra
  path: ./environments
  prune: true
  wait: true
  timeout: 2m
```

The field `dependsOn` makes the kustomize controller wait until `platform` is Ready before it applies `environments`. The field `wait: true` makes it check the health of every object it applied, and `timeout` limits how long it waits. For a custom kind such as `ScoutEnvironment`, the health check reads the `Ready` condition, which Crossplane sets. No script is needed.

Apply the three files:

```sh
kubectl apply -f gitrepository-platform-infra.yaml -f kustomization-platform.yaml -f kustomization-environments.yaml
```

Then check the result after about 40 seconds:

```sh
flux get sources git
flux get kustomizations
```

```text
NAME          	REVISION          	SUSPENDED	READY	MESSAGE                                           
platform-infra	main@sha1:03acf93b	False    	True 	stored artifact for revision 'main@sha1:03acf93b'	
NAME        	REVISION          	SUSPENDED	READY	MESSAGE                              
environments	main@sha1:03acf93b	False    	True 	Applied revision: main@sha1:03acf93b	
platform    	main@sha1:03acf93b	False    	True 	Applied revision: main@sha1:03acf93b	
```

The source controller fetched the commit. The kustomize controller applied `platform` first and then `environments`. The objects were already in the cluster, so Flux took them over without recreating them.

## Break production and watch the health check

The health check is the reason to use `wait`. Push a version that does not exist and see how Flux reports it:

```sh
git clone http://platform:starfleet-gitops@127.0.0.1:3000/starfleet/platform-infra.git platform-infra-flux
cd platform-infra-flux
sed -i.bak 's/version: 6.15.0/version: 6.99.0/' environments/production/scoutenvironment.yaml && rm environments/production/scoutenvironment.yaml.bak
git commit -am "Release podinfo 6.99.0 to production"
git push
flux reconcile source git platform-infra
```

The `environments` Kustomization applies the change and starts its health check. It waits for the XR to become Ready until the timeout of two minutes ends. While it waits, `flux get kustomizations` shows `Reconciliation in progress`. After two minutes, read the conditions:

```sh
kubectl -n flux-system get kustomization environments \
  -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason}: {.message}{"\n"}{end}'
```

```text
Reconciling=True ProgressingWithRetry: Running health checks for revision main@sha1:8accbc3242e4f4dcd9457f3a1095eaff80d0f2b8 with a timeout of 2m0s
Ready=False HealthCheckFailed: health check failed after 2m0.005280308s: timeout waiting for: [ScoutEnvironment/starfleet-production/scout status: 'InProgress']
Healthy=False HealthCheckFailed: timeout waiting for: [ScoutEnvironment/starfleet-production/scout status: 'InProgress']
```

The kustomize controller names the object that is not Ready, `ScoutEnvironment/starfleet-production/scout`. The `Ready=False` condition sends you to the layers of a composite resource: the XR, the `Object`, the pods. The fix is the same as before, a change in Git:

```sh
sed -i.bak 's/version: 6.99.0/version: 6.15.0/' environments/production/scoutenvironment.yaml && rm environments/production/scoutenvironment.yaml.bak
git commit -am "Use the published podinfo tag in production"
git push
flux reconcile kustomization environments --with-source
flux get kustomizations
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet-production/ | grep -E '"(version|message)"'
```

```text
NAME        	REVISION          	SUSPENDED	READY	MESSAGE                              
environments	main@sha1:ce8a2ac4	False    	True 	Applied revision: main@sha1:ce8a2ac4	
platform    	main@sha1:ce8a2ac4	False    	True 	Applied revision: main@sha1:ce8a2ac4	
  "version": "6.15.0",
  "message": "production",
```

Your revision hashes differ. Both Kustomizations are `Ready` again on the new commit, and `shuttle` gets the published version from the production Service.

Both tools deliver the same Crossplane objects. This table maps what you used:

| Job | Argo CD | Flux |
| --- | --- | --- |
| Fetch and apply a Git path | `Application` | `GitRepository` and `Kustomization` |
| Apply the API before the instances | Sync waves and `SkipDryRunOnMissingResource` | `dependsOn` between two `Kustomization` objects |
| Know that an XR is Ready | Custom Lua health check in `argocd-cm` | `wait: true`, which reads the `Ready` condition |
| Remove what left Git | `prune: true` | `prune: true` |

You can now deliver a Crossplane platform from Git with either tool, in the right order, and read the real health of the result.

## Common pitfalls

> [!WARNING]
> - Do not leave the Argo CD `Application` and the Flux `Kustomization` objects running together. Two controllers that apply the same objects compete. Deliver each object with one tool.
> - Right after a push, `environments` can show `dependency 'flux-system/platform' revision is not up to date`. The `platform` Kustomization has not yet applied the new commit. Wait for the next reconciliation or run `flux reconcile kustomization platform`.
> - `wait: true` only checks the objects that one Kustomization applied. Keep the API (XRD and `Composition`) and the instances (XRs) in two Kustomizations with `dependsOn`, so the kind exists before Flux applies the first XR.
> - A short `interval` or `timeout` is not a fix. If the health check times out, read the XR and the layers below it. The timeout only says how long Flux waits.
