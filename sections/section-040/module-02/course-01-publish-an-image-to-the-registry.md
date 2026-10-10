# Publish An Image To The Registry

A new version of an application starts as a new container image in a registry. Before a pipeline can tell GitOps about a version, that image must exist under a tag the cluster can pull. This part explains where the pipeline stops and Argo CD takes over, and then writes the Task that publishes a new `scout` image tag.

## Where CI ends and GitOps begins

Two systems take part in a release, and each one writes to its own place. The pipeline writes an image to the registry and a commit to the GitOps repository. Argo CD reads the GitOps repository and writes to the cluster. No step of the pipeline changes a Deployment.

This has three effects. The GitOps repository stays the only description of what runs, so self-heal never fights the pipeline. The pipeline needs no permission to change workloads, so a broken or misused pipeline cannot change the cluster directly. And every release is a commit with a message and an author, which you can review or revert.

Start by checking the state the playground begins in:

<!-- astrona:playground:renew -->

```sh
kubectl -n argocd get applications
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet | grep version
kubectl -n starfleet exec deploy/shuttle -- curl -s http://registry.registry.svc:5000/v2/_catalog
kubectl -n starfleet exec deploy/shuttle -- curl -s http://registry.registry.svc:5000/v2/starfleet/scout/tags/list
```

The output is:

```text
NAME    SYNC STATUS   HEALTH STATUS
scout   Synced        Healthy
  "version": "6.14.0",
{"repositories":["starfleet/podinfo","starfleet/scout"]}
{"name":"starfleet/scout","tags":["6.14.0"]}
```

Argo CD keeps `scout` synced and healthy, and `scout` answers with version `6.14.0`. The last two lines come from the registry's HTTP API: the path `/v2/_catalog` lists the repositories, and `/v2/<repository>/tags/list` lists the tags of one repository. The `scout` repository holds a single tag.

## A Task that publishes a tag

A real pipeline builds the image from the source code. Building images takes much more memory than this playground has, so the "build" here is a copy: the Task copies a podinfo base image in the registry to a new `scout` tag with `crane`, a small command-line tool for registries. The rest of the flow is the same as with a real build: a new tag appears in the registry, and the Task reports its digest.

Save this as `task-publish-image.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: publish-image
  namespace: starfleet
spec:
  params:
    - name: version
      type: string
      description: The version to publish
  results:
    - name: image
      description: The published image with its digest
  steps:
    - name: copy
      image: gcr.io/go-containerregistry/crane/debug:v0.22.1
      script: |
        #!/busybox/sh
        set -eu
        SOURCE="registry.registry.svc:5000/starfleet/podinfo:$(params.version)"
        TARGET="registry.registry.svc:5000/starfleet/scout:$(params.version)"
        crane copy --insecure "$SOURCE" "$TARGET" 2> /tmp/copy.log || { cat /tmp/copy.log; exit 1; }
        DIGEST="$(crane digest --insecure "$TARGET")"
        echo "Published $TARGET ($DIGEST)"
        printf '%s@%s' "$TARGET" "$DIGEST" > "$(results.image.path)"
```

A few details matter here:

- The `debug` variant of the image contains a shell at `/busybox/sh`, which the `script` needs.
- `--insecure` lets `crane` talk to the registry over plain HTTP, because this registry has no TLS certificate.
- The step hides the copy log unless the copy fails, so the run log stays short.
- The result `image` holds the tag and the digest. A digest is the hash of the image manifest, so it names exactly one image even if someone moves the tag later.

Apply it:

```sh
kubectl apply -f task-publish-image.yaml
```

## Publish version 6.14.1

Start the Task with `tkn`, set the version, and follow the log:

```sh
tkn -n starfleet task start publish-image -p version=6.14.1 --showlog
```

The output is:

```text
TaskRun started: publish-image-run-ffv8g
Waiting for logs to be available...
[copy] Published registry.registry.svc:5000/starfleet/scout:6.14.1 (sha256:f9537f729129d339aaef049b76ab2cd4ff06a424f99e5f6a5923c10621018fb1)
```

Then check the result in the registry:

```sh
kubectl -n starfleet exec deploy/shuttle -- curl -s http://registry.registry.svc:5000/v2/starfleet/scout/tags/list
```

The output is:

```text
{"name":"starfleet/scout","tags":["6.14.0","6.14.1"]}
```

The new tag is in the registry. Nothing else changed: `scout` still runs `6.14.0`, because no file in the GitOps repository names the new tag yet.

## A tag that has no source

A pipeline must stop when the image it should publish does not exist. Ask for a version the registry has no base image for:

```sh
tkn -n starfleet task start publish-image -p version=6.16.0 --showlog
tkn -n starfleet taskrun list
```

The output is:

```text
TaskRun started: publish-image-run-hjlgj
Waiting for logs to be available...
[copy] 2026/10/10 17:54:35 Copying from registry.registry.svc:5000/starfleet/podinfo:6.16.0 to registry.registry.svc:5000/starfleet/scout:6.16.0
[copy] Error: fetching "registry.registry.svc:5000/starfleet/podinfo:6.16.0": GET http://registry.registry.svc:5000/v2/starfleet/podinfo/manifests/6.16.0: MANIFEST_UNKNOWN: manifest unknown; unknown tag=6.16.0

container step-copy has failed  : [{"key":"StartedAt","value":"2026-10-10T17:54:35.562Z","type":3}]
NAME                      STARTED          DURATION   STATUS
publish-image-run-hjlgj   5 seconds ago    5s         Failed(StepFailed)
publish-image-run-ffv8g   10 seconds ago   5s         Succeeded
```

The registry answered `MANIFEST_UNKNOWN` for the missing tag, `crane` exited with an error, and the step printed the copy log and failed. A failed publish must stop the release. In a Pipeline, a Task that runs after this one never starts, so no commit with a broken tag reaches Git.

You can now publish a new image tag from a Task and check it in the registry. The cluster still runs the old version, because nothing in Git points at the new tag. The open question is how a Task changes the GitOps repository, which is private and needs credentials.

## Common pitfalls

> [!WARNING]
> - **Applying the new version from the pipeline.** With automated sync and self-heal, Argo CD reverts any change that is not in Git. The pipeline must commit to Git instead.
> - **Using an image without a shell for a `script`.** The plain `crane` image has no shell. Use the `debug` variant and start the script with `#!/busybox/sh`.
> - **Forgetting `--insecure` for a registry over plain HTTP.** Without it, `crane` tries HTTPS and fails.
> - **Trusting a tag alone.** A tag can be moved to another image. Record the digest as well, as the `image` result does.
