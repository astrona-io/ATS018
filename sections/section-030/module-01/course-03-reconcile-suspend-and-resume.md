# Reconcile, Suspend And Resume

The staging Deployment has one replica because Git says it should. If someone scales it by hand, the kustomize controller normally restores one replica. That difference between the live cluster and the desired state is called drift. You can suspend reconciliation to inspect a problem without the controller changing the objects during your inspection.

## Suspend the applier

The GitRepository `scout` and Kustomizations `platform` and `scout` must already be Ready. A suspended Kustomization keeps the objects it applied. It stops applying changes and checking for drift; it does not stop the application or the source controller.

<!-- astrona:playground:renew -->

Save this as `kustomization-scout-paused.yaml`:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: scout
  namespace: flux-system
spec:
  suspend: true
  interval: 1m
  path: ./overlays/staging
  prune: true
  targetNamespace: starfleet-staging
  wait: true
  timeout: 1m
  dependsOn:
    - name: platform
  sourceRef:
    kind: GitRepository
    name: scout
```

Apply it:

```sh
kubectl apply -f kustomization-scout-paused.yaml
```

```text
kustomization.kustomize.toolkit.fluxcd.io/scout configured
```

The field `spec.suspend: true` is the declarative way to pause this applier. The command-line equivalent is `flux suspend kustomization scout`. Run it to see the same control through the Flux command-line tool, then scale the delivered Deployment:

```sh
flux suspend kustomization scout
kubectl -n starfleet-staging scale deployment scout --replicas=2
flux get kustomizations
kubectl -n starfleet-staging get deployment scout -o jsonpath='{.spec.replicas}{"\n"}'
```

The status was:

```text
NAME    	REVISION          	SUSPENDED	READY	MESSAGE                              
platform	main@sha1:cda78005	False    	True 	Applied revision: main@sha1:cda78005	
scout   	main@sha1:cda78005	True     	True 	Applied revision: main@sha1:cda78005
```

The replica check printed:

```text
2
```

Notice that `READY` still says `True`. It records the last completed reconciliation, while `SUSPENDED=True` tells you no new reconciliation will run. A previously Ready condition is not proof that a suspended application still matches Git.

## Resume and repair drift

`flux resume` clears the suspension field and waits for reconciliation. `flux reconcile kustomization` requests a reconciliation now, without waiting for `interval`. Its `--with-source` flag first requests a source fetch, so the applier uses the newly fetched artifact.

```sh
flux resume kustomization scout
flux reconcile kustomization scout --with-source
kubectl -n starfleet-staging get deployment scout -o jsonpath='{.spec.replicas}{"\n"}'
```

The replica check now prints:

```text
1
```

The controller restored the value in Git. This is why a live `kubectl scale` is not a lasting GitOps change. Here the manual change was a controlled test, with suspension first. For a lasting change, edit the repository and let the controller apply it.

If a Kustomization is itself delivered by another GitOps controller, record suspension in that object's source repository too. Otherwise its parent can restore the old `suspend` value. The two Kustomizations in this playground were created directly, so no parent is managing their specification.

## Deliver a change from Git

Fetch credentials are read-only, but the playground also provides a writer account for deliberate repository changes. Clone the repository on your machine:

```sh
git clone http://platform:starfleet-gitops@127.0.0.1:3000/starfleet/scout-deploy.git
cd scout-deploy
```

Change `value: staging` to `value: staging-v2` in `overlays/staging/message.yaml`. This changes the environment value in the Deployment's pod template. A pod template describes the pods a Deployment should create; changing it starts a rollout of new pods.

Commit the file and push it. The commands set the commit identity for this example:

```sh
git add overlays/staging/message.yaml
git -c user.name=platform -c user.email=platform@starfleet.local commit -m "Update staging message"
git push
flux reconcile kustomization scout --with-source
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet-staging
```

The response from the new pod was shortened to the version and message lines:

```text
  "version": "6.15.0",
  "message": "staging-v2",
```

The source controller fetched the commit, and the kustomize controller applied the changed template and waited for ready pods. A request now carries the committed message. The workload's `revision` response field identifies the podinfo build; it is not the deployment repository's commit. Read the Flux artifact and applied revision for that Git commit.

Pruning follows the same repository workflow. Remove an object from the files rendered by the path, commit and push, then reconcile. With `prune: true`, the kustomize controller deletes the previously managed object. Suspension pauses that deletion too. It does not make a removed object permanently safe once reconciliation resumes.

You can now pause an applier, read its suspension separately from its last Ready condition, restore reconciliation and deliver a lasting change through Git. The controller status and the client response together show what happened.

## Common pitfalls

> [!WARNING]
> - **Expecting suspension to remove workloads.** Existing objects keep running.
> - **Trusting `READY=True` without reading `SUSPENDED`.** It can describe an older successful reconciliation.
> - **Reconciling only the applier after a Git push.** Use `--with-source` when you also need a fresh fetch.
> - **Keeping a live edit as the fix.** Reconciliation restores Git; commit the intended change instead.
