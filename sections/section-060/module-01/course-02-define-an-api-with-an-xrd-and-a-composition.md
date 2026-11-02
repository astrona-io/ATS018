# Define An API With An XRD And A Composition

Other teams should not write a Deployment and a Service by hand for every environment. They should ask for an environment and give three values: a version, a replica count and a message. This part builds that API. It defines the new kind, maps it to real objects, and creates the first environment.

## Read the platform API in the repository

The platform team keeps its API definitions in Git. Clone the repository from Gitea and look at the files:

<!-- astrona:playground:renew -->

```sh
git clone http://platform:starfleet-gitops@127.0.0.1:3000/starfleet/platform-infra.git
cd platform-infra
find . -name '*.yaml' -not -path './.git/*' | sort
```

```text
./environments/production/scoutenvironment.yaml
./environments/staging/scoutenvironment.yaml
./platform/composition.yaml
./platform/xrd.yaml
```

The `platform` folder holds the API. A `CompositeResourceDefinition` (XRD) is the object that defines a new kind and its fields. Crossplane reads it and creates a custom resource definition for that kind. The file `platform/xrd.yaml` defines the kind `ScoutEnvironment` in the group `platform.starfleet.dev`. Its main parts are:

```yaml
apiVersion: apiextensions.crossplane.io/v2
kind: CompositeResourceDefinition
metadata:
  name: scoutenvironments.platform.starfleet.dev
spec:
  scope: Namespaced
  group: platform.starfleet.dev
  names:
    kind: ScoutEnvironment
    plural: scoutenvironments
  versions:
    - name: v1alpha1
      served: true
      referenceable: true
      schema:
        openAPIV3Schema:
          # type object, with spec.version (required), spec.replicas (default 1)
          # and spec.message (default hello)
```

The comment replaces the schema lines in this excerpt. With `scope: Namespaced`, every `ScoutEnvironment` lives in a namespace, like a Deployment. The name of an XRD is always the plural name plus the group.

An object of this new kind is called a composite resource (XR). In older Crossplane versions, a team created a separate "claim" object that pointed to a cluster-scoped XR. Crossplane 2 removes that step for namespaced XRDs: the team creates the XR itself.

## Map the API to real objects

An XRD defines what a team can ask for. A `Composition` defines what Crossplane creates for it. In `Pipeline` mode, a `Composition` lists steps. Each step calls a function with an input. This `Composition` has one step that calls `function-patch-and-transform`. The input lists two resources, `deployment` and `service`. Each resource has a `base`, which is a complete `Object` from the provider, and `patches`, which copy fields from the XR into that base.

The patches for the Deployment show the idea:

```yaml
patches:
  - type: FromCompositeFieldPath
    fromFieldPath: metadata.namespace
    toFieldPath: spec.forProvider.manifest.metadata.namespace
  - type: FromCompositeFieldPath
    fromFieldPath: spec.replicas
    toFieldPath: spec.forProvider.manifest.spec.replicas
  - type: FromCompositeFieldPath
    fromFieldPath: spec.version
    toFieldPath: spec.forProvider.manifest.spec.template.spec.containers[0].image
    transforms:
      - type: string
        string:
          type: Format
          fmt: ghcr.io/stefanprodan/podinfo:%s
```

Each patch reads a field of the XR and writes it into the `Object`. The `Format` transform turns the version `6.15.0` into the image `ghcr.io/stefanprodan/podinfo:6.15.0`. The first patch is not optional: the wrapped manifest has no namespace of its own, and without this patch the provider fails with `cannot get object: an empty namespace may not be set when a resource name is provided`.

The Deployment resource also sets a readiness rule. By default, an `Object` is Ready as soon as the provider created it. That would make an environment Ready even when its pods cannot start. This `Composition` uses a CEL (Common Expression Language) query instead:

```yaml
readiness:
  policy: DeriveFromCelQuery
  celQuery: has(object.status.availableReplicas) && has(object.status.updatedReplicas) && object.status.availableReplicas == object.spec.replicas && object.status.updatedReplicas == object.spec.replicas
```

The `Object` is Ready only when all replicas are updated and available. The query reads the observed Deployment, which the provider passes in as `object`.

## Create the first environment

Apply the API first and wait until the XRD is established. Established means Crossplane created the new custom resource definition and the API server serves it:

```sh
kubectl apply -f platform/
kubectl wait --for=condition=Established xrd/scoutenvironments.platform.starfleet.dev --timeout=60s
```

```text
compositeresourcedefinition.apiextensions.crossplane.io/scoutenvironments.platform.starfleet.dev created
composition.apiextensions.crossplane.io/scoutenvironment created
compositeresourcedefinition.apiextensions.crossplane.io/scoutenvironments.platform.starfleet.dev condition met
```

Now the cluster has a new kind. The staging file is a plain XR with three values. Apply it, wait a little, and read the result:

```sh
cat environments/staging/scoutenvironment.yaml
kubectl apply -f environments/staging/
kubectl -n starfleet-staging get scoutenvironments.platform.starfleet.dev,objects.kubernetes.m.crossplane.io,deploy,svc
```

The `cat` command prints the XR. The `argocd.argoproj.io/sync-wave` annotation is used in the next part. Crossplane ignores it:

```text
apiVersion: platform.starfleet.dev/v1alpha1
kind: ScoutEnvironment
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"
  name: scout
  namespace: starfleet-staging
spec:
  version: 6.15.0
  replicas: 1
  message: staging
```

After about 40 seconds, the last command shows:

```text
NAME                                            SYNCED   READY   COMPOSITION        AGE
scoutenvironment.platform.starfleet.dev/scout   True     True    scoutenvironment   75s

NAME                                                   KIND         PROVIDERCONFIG   SYNCED   READY   AGE
object.kubernetes.m.crossplane.io/scout-a926650203d8   Service      default          True     True    74s
object.kubernetes.m.crossplane.io/scout-e89de5df4050   Deployment   default          True     True    74s

NAME                    READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/scout   1/1     1            1           40s

NAME            TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
service/scout   ClusterIP   10.96.90.192   <none>        80/TCP    40s
```

Your object names and cluster IP differ. Each level has two conditions. `SYNCED` means Crossplane could compose the resources and apply them without an error. `READY` means every composed resource is Ready. The XR is the top level, the two `Object` resources are the middle level, and the Deployment and the Service are the real objects the provider created.

Prove that the environment works with a request from `shuttle`:

```sh
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet-staging/ | grep -E '"(version|message)"'
```

```text
  "version": "6.15.0",
  "message": "staging",
```

The `scout` pod answers with the version and the message from the XR. The Crossplane function computed the pod template, the provider created the Deployment, and the Kubernetes controllers started the pods.

You can now read an XRD and a `Composition`, and you know the three levels of status. The environment exists only because you ran `kubectl apply`. The open question is how Git, not a person, becomes the source of this state.

## Common pitfalls

> [!WARNING]
> - Do not apply an XR in the same command as its XRD. The kind does not exist until the XRD is `Established`, and the apply fails with a "no matches for kind" error. Wait first.
> - A `Composition` that does not copy the namespace into the wrapped manifest leaves the `Object` with `SYNCED False` and the message `cannot get object: an empty namespace may not be set when a resource name is provided`.
> - Do not expect `READY` to mean that pods run. With the default readiness policy, an `Object` is Ready when the provider created it. Write a readiness rule that checks the observed object.
> - Do not edit the generated Deployment or Service. Crossplane owns them and puts the XR values back. Change the XR.
