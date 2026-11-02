# Diagnose A Composite Resource That Is Not Ready

Argo CD now reports the production environment as `Degraded`, and the cause is not in Argo CD. It is somewhere below the composite resource. A Crossplane problem has up to four layers: the XR, the composed `Object` resources, the real Kubernetes objects and the pods. This part walks down the layers in order and ends with a fix in Git.

## Start at the XR and go down

The status of the XR says which resource is not Ready. Read its `Ready` condition:

<!-- astrona:playground:renew -->

```sh
kubectl -n starfleet-production get scoutenvironments.platform.starfleet.dev scout \
  -o jsonpath='{range .status.conditions[?(@.type=="Ready")]}{.reason}: {.message}{"\n"}{end}'
```

```text
Creating: Unready resources: deployment
```

The Crossplane core controller wrote this message. It names the composed resource `deployment`, the name used in the `Composition`. The `Service` is not in the list, so it is Ready. The next layer is the `Object` that wraps the Deployment. Each `Object` has its own conditions:

```sh
kubectl -n starfleet-production get objects.kubernetes.m.crossplane.io \
  -o jsonpath='{range .items[*]}{.metadata.name} {.spec.forProvider.manifest.kind} {range .status.conditions[*]}{.type}={.status}({.reason}) {end}{"\n"}{end}'
```

```text
scout-09e578f17c40 Service Ready=True(Available) Synced=True(ReconcileSuccess) 
scout-9b5f0e8fa013 Deployment Ready=False(Unavailable) Synced=True(ReconcileSuccess) 
```

The `Deployment` object is `Synced=True` and `Ready=False`. `Synced=True` means the provider created the Deployment without an error. `Ready=False` means the readiness rule of the `Composition` is not met: not every replica is updated and available. This is a problem in the real Deployment, not in Crossplane or the provider.

## Read the pods

Now use plain Kubernetes. List the pods and the events of the namespace:

```sh
kubectl -n starfleet-production get pods
kubectl -n starfleet-production get events --field-selector reason=Failed
```

```text
NAME                     READY   STATUS             RESTARTS   AGE
scout-57587c5d89-hv4sb   0/1     ImagePullBackOff   0          2m1s
scout-57587c5d89-mh27s   0/1     ImagePullBackOff   0          2m1s
```

```text
LAST SEEN   TYPE      REASON   OBJECT                       MESSAGE
37s         Warning   Failed   pod/scout-57587c5d89-hv4sb   Failed to pull image "ghcr.io/stefanprodan/podinfo:6.99.0": rpc error: code = NotFound desc = failed to pull and unpack image "ghcr.io/stefanprodan/podinfo:6.99.0": failed to resolve reference "ghcr.io/stefanprodan/podinfo:6.99.0": ghcr.io/stefanprodan/podinfo:6.99.0: not found
37s         Warning   Failed   pod/scout-57587c5d89-hv4sb   Error: ErrImagePull
11s         Warning   Failed   pod/scout-57587c5d89-hv4sb   Error: ImagePullBackOff
```

The second output is shortened to the lines that matter. The container runtime on the node could not find the image tag `6.99.0`. The XR in Git asks for that version, and the `Composition` copies it into the image name. The cause is the field `spec.version` in `environments/production/scoutenvironment.yaml`.

## Fix it in Git, not in the cluster

You could edit the Deployment with `kubectl edit`, but that is the wrong layer. Crossplane would put the old image back, because the XR owns the Deployment. Argo CD with self-heal on would also revert a change to the XR. The XR in Git is the single source of the value, so change it there.

Clone the repository, change the version and push:

```sh
git clone http://platform:starfleet-gitops@127.0.0.1:3000/starfleet/platform-infra.git platform-infra-fix
cd platform-infra-fix
sed -i.bak 's/version: 6.99.0/version: 6.15.0/' environments/production/scoutenvironment.yaml && rm environments/production/scoutenvironment.yaml.bak
git commit -am "Use the published podinfo tag in production"
git push
```

Then ask Argo CD to look at Git again and check the chain from the top:

```sh
argocd app get scout-platform --refresh | grep 'Health Status'
kubectl get scoutenvironments.platform.starfleet.dev -A
```

```text
Health Status:      Healthy
NAMESPACE              NAME    SYNCED   READY   COMPOSITION        AGE
starfleet-production   scout   True     True    scoutenvironment   2m37s
starfleet-staging      scout   True     True    scoutenvironment   2m37s
```

The `Health Status` can need another half minute before it changes; run the first command again if it still says `Degraded`. On the playground, the XR needed about 30 seconds after the push to become Ready. The Argo CD application controller synced the new commit. Crossplane changed the image in the Deployment. The Kubernetes Deployment controller replaced the pods.

Last, prove the result with a request from `shuttle`:

```sh
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet-production/ | grep -E '"(version|message)"'
```

```text
  "version": "6.15.0",
  "message": "production",
```

Production now answers with the published version.

You can now find the failing layer in a Crossplane stack: the XR condition names the resource, the `Object` conditions separate a provider error from an unready workload, and the pods and events give the reason. The fix goes into the XR in Git. The question left is whether the same repository can be delivered by Flux, and what changes when it is.

## Common pitfalls

> [!WARNING]
> - Do not stop at the XR. `Ready=False` only says that some composed resource is not Ready. The reason is one or two layers below.
> - `Synced=False` and `Ready=False` are different problems. `Synced=False` means Crossplane or the provider cannot apply the object. `Ready=False` with `Synced=True` means the object exists but does not work yet.
> - Do not fix a composed Deployment with `kubectl edit`. Crossplane owns it and restores the value from the XR. Change the XR in Git.
> - When you change the version of a running environment to a tag that does not exist, the old pods keep running while the new pod fails to pull. The old pods keep the Deployment available, so a readiness rule that only checks for availability stays true. The rule in this `Composition` also compares the updated replicas, and that is what turns the XR to `Ready=False`.

## Your mission: Deliver The Platform With Argo CD And Repair Production

You can now deliver a Crossplane repository with Argo CD, make Argo CD report the Ready state of an XR, and trace a failing environment down to its pods. The mission gives you a cluster with Crossplane, the provider and the function installed, and the repository in Git. You create the `Application`, add the health check, find the cause in production and fix it in Git, and prove from the `shuttle` pod that both environments answer.

Pause the playground, then start the lab and read the task:

```sh
astrona stop ats-018-playground-060-01
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-060/module-01/labs/lab-01
```

When the `Application` is `Healthy` and both environments are Ready, grade your work:

```sh
astrona submit -c sections/section-060/module-01/labs/lab-01
```

Then remove the lab and start the playground again:

```sh
astrona destroy ats-018-lab-060-01
astrona start ats-018-playground-060-01
```
