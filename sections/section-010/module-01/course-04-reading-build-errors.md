# Reading Kustomize Build Errors

In a GitOps setup, a Kustomize error does not appear in your terminal. It appears in the controller's status, often as one long line, minutes after the commit that caused it. So it pays to know the few errors that cover most real mistakes and to recognise each one from its first words. This part breaks the overlays on purpose, one mistake at a time, and reads each error. It ends with the one mistake that builds without an error at all.

## Where an error comes from

Kustomize stops at the first problem it meets and prints one line that starts with `error:`. The command exits with `1`, and nothing is applied: `kubectl apply -k` and `kubectl diff -k` both run the same build first, so they fail with the same message. The words right after `error:` tell you which stage failed:

| Error starts with | Stage that failed | Usual cause |
| --- | --- | --- |
| `accumulating resources` | Loading the `resources` list | A path that does not exist, or a folder without a `kustomization.yaml` |
| `no resource matches strategic merge patch` | Matching a patch file to an object | The patch's `kind` or `metadata.name` is not in the rendered objects |
| `replace operation does not apply` (or `add`, `remove`) | Running a JSON 6902 operation | The `path` points at a field that is not there |
| `resource with name ... does not match a config` | Running a shortcut field such as `replicas` | The name is not a workload in the build |

Every test below changes one line, runs `kubectl kustomize` on the overlay, and puts the line back. Make each change in your own files, read the error, and undo the change before the next test.

## A resource path that does not exist

<!-- astrona:playground:renew -->

In `overlays/production/kustomization.yaml`, change `../../base` to `../../bases`, then render:

```sh
kubectl kustomize overlays/production
```

You should see something like this (the full path to your `scout` folder is shortened to `.../scout` here, and it appears twice in the real line):

```text
error: accumulating resources: accumulation err='accumulating resources from '../../bases': evalsymlink failure on '.../scout/bases' : lstat .../scout/bases: no such file or directory': must build at directory: not a valid directory: evalsymlink failure on '.../scout/bases' : lstat .../scout/bases: no such file or directory
```

The line is long, but the first part says everything: `accumulating resources from '../../bases'` names the entry, and `no such file or directory` names the cause. The absolute path in the message shows where Kustomize looked, which helps when the relative path is right but you ran the command from the wrong folder. Change `../../bases` back to `../../base`.

## A patch file that matches no object

In `overlays/staging/deployment-env.yaml`, change `metadata.name` from `scout` to `scout-api`, then render the staging overlay:

```sh
kubectl kustomize overlays/staging
```

You should see:

```text
error: no resource matches strategic merge patch "Deployment.v1.apps/scout-api.[noNs]": no matches for Id Deployment.v1.apps/scout-api.[noNs]; failed to find unique target for patch Deployment.v1.apps/scout-api.[noNs]
```

The message names the patch by its ID: `Deployment.v1.apps/scout-api.[noNs]` is kind `Deployment`, version `v1`, group `apps`, name `scout-api` and no namespace. Compare that ID with the rendered objects: there is a `Deployment` named `scout`, but none named `scout-api`. The `[noNs]` part is a hint, too. Patches are matched before the overlay's `namespace` field is applied, so the objects have no namespace yet at that moment. Change the name back to `scout`.

## A JSON 6902 path that does not exist

In the production patch, change `/resources/requests/memory` to `/resource/requests/memory` (drop the `s`), then render:

```sh
kubectl kustomize overlays/production
```

You should see:

```text
error: replace operation does not apply: doc is missing path: /spec/template/spec/containers/0/resource/requests/memory: missing value
```

A `replace` needs the field to exist, and there is no field called `resource`. The message prints the full path it tried, so compare it with the rendered base one field at a time. An `add` operation would not have failed here in the same way: it creates the last field in the path, but every field before it must exist. Put the `s` back.

## A shortcut field with a wrong name

In the production `replicas` block, change `name: scout` to `name: scouts`, then render:

```sh
kubectl kustomize overlays/production
```

You should see:

```text
error: resource with name scouts does not match a config with the following GVK [Deployment.[noVer].[noGrp] StatefulSet.[noVer].[noGrp] ReplicaSet.[noVer].[noGrp] ReplicationController.[noVer].[noGrp]]
```

`GVK` means group, version and kind. The message lists the kinds that `replicas` can change and says that none of them has the name `scouts`. Change it back to `scout`.

## The mistake that builds cleanly

Every error so far stopped the build. One common mistake does not. In the production `patches` entry, change the target's `name: scout` to `name: scout-api`, then render and check the exit code:

```sh
kubectl kustomize overlays/production > /dev/null
echo $?
```

You should see:

```text
0
```

The build succeeded. A patch with a `target` block applies to every object the target selects, and **zero objects is a valid result**. Kustomize does not warn you. The rendered Deployment simply has no memory limit and the memory request from the base. `kubectl diff` makes the damage visible, because the production Deployment in the cluster still has the patched values:

```sh
kubectl diff -k overlays/production
```

The output, shortened to the changed lines, is:

```text
-  generation: 1
+  generation: 2
...
-          limits:
-            memory: 128Mi
...
-            memory: 64Mi
+            memory: 32Mi
```

Applying this would remove the memory limit from production and halve its memory request, and the build gave no hint. The same silence happens when a target names the overlay's own namespace, such as `namespace: starfleet-production`, because the objects have no namespace yet when patches run. Change the target name back to `scout` and run `kubectl diff -k overlays/production` once more: it prints nothing and exits with `0`.

You can now tell from the first words of a Kustomize error which stage failed and which line of which file to look at. You have also seen why a clean build is not proof that a patch did anything: a `target` that selects nothing is silent, and only reading the rendered output or the diff shows it.

## Common pitfalls

> [!WARNING]
> - **Reading only the end of a long error line.** The first words after `error:` name the stage and the entry; the end often repeats the same path.
> - **Trusting a clean build for patches with a `target`.** A target that selects nothing is not an error. Check the rendered output or the diff for the field the patch should change.
> - **Adding the overlay's namespace to a patch target.** Patches run before the `namespace` field, so the target then matches nothing.
> - **Fixing an error in the cluster instead of in the files.** The next render brings the mistake back. In a GitOps setup, the fix is always a commit.
