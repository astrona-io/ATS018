# Install A Provider And A Function

Kubernetes knows how to run pods and Services. It does not know how to create a database, a cloud bucket or, in this module, a Deployment on behalf of another team. Crossplane adds that knowledge in packages. This part installs the two packages the rest of the module needs and shows how to tell that they work.

## What Crossplane installs and what you add

The Crossplane Helm chart (installed for you) starts two pods in `crossplane-system`. The `crossplane` pod is the core controller. The `crossplane-rbac-manager` pod creates the Kubernetes permissions that Crossplane packages need. The core controller can store and compare objects, but it cannot create anything useful yet. Two kinds of package give it that ability:

- A `Provider` is a package that runs a controller and adds custom resource definitions (CRDs) for one kind of external system. It creates and maintains the real resources.
- A `Function` is a package that runs a small service. A `Composition` calls it to decide which objects a composite resource needs.

This module uses `provider-kubernetes`, which creates Kubernetes objects inside a cluster, and `function-patch-and-transform`, which copies fields from one object into others. Both are real Crossplane packages. Using the Kubernetes provider keeps the playground small: no cloud account is needed, and the result is a Deployment you can reach with `curl`.

<!-- astrona:playground:renew -->

Start by listing the pods that the chart created:

```sh
kubectl -n crossplane-system get pods
```

```text
NAME                                       READY   STATUS    RESTARTS   AGE
crossplane-5f46fd9588-pwr77                1/1     Running   0          24m
crossplane-rbac-manager-859ffb76c9-5m2c7   1/1     Running   0          24m
```

Only the core pods run. Your pod names and ages differ. The output below also shows the two packages after you install them, so it lists four pods at the end of this part.

## Install the provider

A provider pod needs a Kubernetes service account. Crossplane creates one with a generated name unless you set the name. A fixed name lets you give the provider permissions later. A `DeploymentRuntimeConfig` is the Crossplane object that changes how a package pod is built, and here it only sets the service account name.

Save this as `deploymentruntimeconfig-provider-kubernetes.yaml`:

```yaml
apiVersion: pkg.crossplane.io/v1beta1
kind: DeploymentRuntimeConfig
metadata:
  name: provider-kubernetes
spec:
  serviceAccountTemplate:
    metadata:
      name: provider-kubernetes
```

Save this as `provider-kubernetes.yaml`. The `package` field is the address of the package image, with an exact version:

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-kubernetes
spec:
  package: xpkg.crossplane.io/crossplane-contrib/provider-kubernetes:v1.4.1
  runtimeConfigRef:
    name: provider-kubernetes
```

Save this as `function-patch-and-transform.yaml`:

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Function
metadata:
  name: function-patch-and-transform
spec:
  package: xpkg.crossplane.io/crossplane-contrib/function-patch-and-transform:v0.11.2
```

Apply the three files. The runtime configuration goes first, so the provider pod starts with the right service account:

```sh
kubectl apply -f deploymentruntimeconfig-provider-kubernetes.yaml
kubectl apply -f provider-kubernetes.yaml -f function-patch-and-transform.yaml
```

Then check the result. Both packages download an image and start a pod, so wait a minute before the second command. The names are the full resource names, because `provider` and `function` also exist in other API groups:

```sh
kubectl get providers.pkg.crossplane.io
kubectl get functions.pkg.crossplane.io
```

```text
NAME                  INSTALLED   HEALTHY   PACKAGE                                                            AGE
provider-kubernetes   True        True      xpkg.crossplane.io/crossplane-contrib/provider-kubernetes:v1.4.1   7m26s
NAME                           INSTALLED   HEALTHY   PACKAGE                                                                      AGE
function-patch-and-transform   True        True      xpkg.crossplane.io/crossplane-contrib/function-patch-and-transform:v0.11.2   7m26s
```

`INSTALLED` means the Crossplane core controller downloaded the package and created its parts. `HEALTHY` means the package pod runs and answers. A package that is `INSTALLED` but not `HEALTHY` is still starting or cannot pull its image.

## Revisions and the pods behind a package

Every change to a package creates a revision, which is one numbered version of the installed package. The active revision owns the pod. List them:

```sh
kubectl get providerrevisions.pkg.crossplane.io,functionrevisions.pkg.crossplane.io
kubectl -n crossplane-system get pods
```

The first command prints one table for each kind. Here is the part that matters, with the columns shortened:

```text
NAME                                                  HEALTHY   STATE      
providerrevision.pkg.crossplane.io/provider-kubernetes-3d2253e98ffb   True      Active
functionrevision.pkg.crossplane.io/function-patch-and-transform-e9fec78aeef5   True      Active
```

```text
NAME                                                        READY   STATUS    RESTARTS   AGE
crossplane-5f46fd9588-pwr77                                 1/1     Running   0          24m
crossplane-rbac-manager-859ffb76c9-5m2c7                    1/1     Running   0          24m
function-patch-and-transform-e9fec78aeef5-b4467f8bf-kvlvj   1/1     Running   0          23m
provider-kubernetes-3d2253e98ffb-6cdc66dd57-479dj           1/1     Running   0          19m
```

The first output is shortened. If you change the provider, for example by adding a runtime configuration after it started, Crossplane keeps the old revision with the state `Inactive` and activates a new one. The package name in the pod name carries the revision hash.

## Connect the provider to the cluster

The provider pod now runs, but it has no connection details yet. A `ClusterProviderConfig` tells the provider which cluster to act on and which credentials to use. With `credentials.source: InjectedIdentity`, the provider uses the service account of its own pod, so it acts inside the cluster where it runs.

That service account has no permissions to create Deployments. Kubernetes denies everything that no role allows. A `ClusterRole` and a `ClusterRoleBinding` give the `provider-kubernetes` service account the permissions that the composed objects need.

Save this as `rbac-provider-kubernetes.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: provider-kubernetes-workloads
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["services", "configmaps"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: provider-kubernetes-workloads
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: provider-kubernetes-workloads
subjects:
  - kind: ServiceAccount
    name: provider-kubernetes
    namespace: crossplane-system
```

Save this as `clusterproviderconfig-default.yaml`:

```yaml
apiVersion: kubernetes.m.crossplane.io/v1alpha1
kind: ClusterProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: InjectedIdentity
```

Apply both files and check the configuration:

```sh
kubectl apply -f rbac-provider-kubernetes.yaml -f clusterproviderconfig-default.yaml
kubectl get clusterproviderconfigs.kubernetes.m.crossplane.io
```

```text
NAME      AGE
default   18m
```

The provider installs two API groups. The group `kubernetes.crossplane.io` is the older one, with cluster-scoped objects. The group `kubernetes.m.crossplane.io` holds namespaced objects, and this module uses it, because Crossplane 2 composes namespaced resources. You can list the kinds with `kubectl api-resources --api-group=kubernetes.m.crossplane.io`. The `Object` kind in that group wraps any Kubernetes manifest, and the provider creates the wrapped manifest in the cluster.

You now know how Crossplane gets its abilities: a `Provider` adds a controller and kinds, a `Function` adds composition logic, and a `ClusterProviderConfig` plus a role decide what the provider may touch. The open question is how a platform team turns these into a small API for other teams.

## Common pitfalls

> [!WARNING]
> - Do not read `INSTALLED True` as working. Check `HEALTHY True` on the `Provider` and the `Function` before you create anything that depends on them.
> - Use the full resource names `providers.pkg.crossplane.io` and `functions.pkg.crossplane.io` with `kubectl get`. A combined list of both kinds in one command showed only the function rows in this playground.
> - A provider that acts as its own service account can only create what its roles allow. Add the API group and the resource to the `ClusterRole` for every kind you wrap in an `Object`.
> - Pin the package version. A `package` without a tag follows the latest release, and a Git change is no longer the only reason your cluster changes.
