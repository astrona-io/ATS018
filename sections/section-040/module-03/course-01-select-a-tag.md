# Select A Tag With ImageRepository And ImagePolicy

`scout` runs version 6.14.0, and the registry already holds 6.15.0. A person could edit the Git repository by hand each time a tag appears. Flux can do the lookup instead: the image reflector controller scans the registry on a schedule and keeps the list of tags in the cluster. This part creates the two objects that find and choose a tag, and no file in Git changes yet.

## Scan the registry

An `ImageRepository` tells the image reflector controller which image repository to scan and how often. The controller stores the tags it finds in the object status. It never pulls the image itself; it only reads the tag list from the registry.

<!-- astrona:playground:renew -->

First confirm which version `scout` serves today:

```sh
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet.svc
```

The response is shortened to the version lines:

```text
  "version": "6.14.0",
  "message": "greetings from podinfo v6.14.0",
```

Save this as `imagerepository-scout.yaml`:

```yaml
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImageRepository
metadata:
  name: scout
  namespace: flux-system
spec:
  image: registry.registry.svc:5000/starfleet/scout
  interval: 1m
  insecure: true
```

Apply it:

```sh
kubectl apply -f imagerepository-scout.yaml
```

The registry in the playground speaks plain HTTP, so `insecure: true` lets the controller connect without Transport Layer Security (TLS). A registry with TLS does not need this field. Then check the result:

```sh
flux get image repository -n flux-system
```

```text
NAME 	LAST SCAN                	SUSPENDED	READY	MESSAGE                                               
scout	2026-11-01T22:09:22+01:00	False    	True 	successful scan: found 4 tags with checksum 917973477
```

The scan found four tags, not two. Read the list the controller stored:

```sh
kubectl -n flux-system get imagerepository scout -o jsonpath='{.status.lastScanResult.latestTags}'
```

```text
["sha256-72611294759dc6b304d1f3efa2d4b1de212ce422866244f31bc29f731e3b2079","sha256-29186ab823274ed31b94c55f533f63402c33c506d7be1666b303b398e5adc204","6.15.0","6.14.0"]
```

Two entries start with `sha256-`. The registry stores signature and attestation data for an image under tags like these. They are not versions, and the next object ignores them.

## Choose a tag with a policy

An `ImagePolicy` reads the tag list of one `ImageRepository` and picks a single tag by a rule. The rule here is `semver`, which means semantic versioning: a version number in the form `major.minor.patch`, such as `6.15.0`. A semver range such as `>=7.0.0` says which versions are allowed, and the policy picks the highest one inside it. Tags that are not valid versions, like the `sha256-` tags, never match.

Start with a range that no tag satisfies. Save this as `imagepolicy-scout.yaml`:

```yaml
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImagePolicy
metadata:
  name: scout
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: scout
  policy:
    semver:
      range: ">=7.0.0"
```

Apply it:

```sh
kubectl apply -f imagepolicy-scout.yaml
```

Then check the result:

```sh
kubectl -n flux-system wait imagepolicy/scout --for=condition=Ready=False --timeout=60s
flux get image policy -n flux-system
```

```text
NAME 	IMAGE	TAG	READY	MESSAGE                                               
scout	     	   	False	unable to determine latest version from provided list
```

The `TAG` column is empty and `READY` is `False`. The message says the controller read the tag list but no tag fits the range. The registry has no version 7 or higher, so the policy has nothing to select. The scan itself worked, which is why the `ImageRepository` stays Ready.

Now widen the range. Edit `imagepolicy-scout.yaml` and change the range line to `range: ">=6.14.0"`. Apply it again:

```sh
kubectl apply -f imagepolicy-scout.yaml
```

Then check the result:

```sh
kubectl -n flux-system wait imagepolicy/scout --for=condition=Ready --timeout=60s
flux get image policy -n flux-system
```

```text
NAME 	IMAGE                                     	TAG   	READY	MESSAGE                                                                            
scout	registry.registry.svc:5000/starfleet/scout	6.15.0	True 	Latest image tag for registry.registry.svc:5000/starfleet/scout resolved to 6.15.0
```

The policy now resolves to `6.15.0`, the highest version in the range. The chosen tag is also stored in the status as `latestRef`, and Flux uses that field when it writes the tag to Git. Nothing runs 6.15.0 yet: the Deployment still uses 6.14.0, because no object has written the tag to Git.

You now know how Flux finds tags and picks one, and how to read a policy that selects nothing. The chosen tag lives only in the cluster status. The open question is how it reaches the Git repository, so the Kustomization can deliver it.

## Common pitfalls

> [!WARNING]
> - **Reading a Ready `ImageRepository` as a chosen tag.** The scan can succeed while the policy selects nothing. Check `flux get image policy` for the `TAG` column.
> - **Forgetting `insecure: true` on a plain HTTP registry.** The controller tries HTTPS, the scan fails with `server gave HTTP response to HTTPS client`, `READY` is `False` and no tags appear.
> - **Using a range that matches no version.** The message `unable to determine latest version from provided list` means the range is wrong, not the registry.
> - **Expecting the policy to change the cluster.** An `ImagePolicy` only records a tag. It never edits Git or a Deployment.
