# Summary

A GitOps controller applies whatever a folder in Git renders to, again and again. Kustomize makes that output repeatable and keeps each environment's differences small and visible.

## What you learned

A base is a folder of plain Kubernetes manifests plus a `kustomization.yaml` file. Its `resources` field lists what to include, `labels` with `pairs` adds labels without touching selectors, and `images` sets the image tag in one place. `kubectl kustomize` renders a folder without contacting the cluster, and the same files always render to the same output. The older `commonLabels` field also changes selectors, which a running Deployment does not allow.

An overlay is a kustomization that lists the base in its `resources` and adds only its own changes. Shortcut fields cover the common cases: `namespace`, `labels`, `images` and `replicas`. A strategic merge patch looks like the object it changes and is matched by `kind` and `metadata.name`; it merges lists such as containers by name. A JSON 6902 patch is a list of `op` and `path` operations with a `target` block that selects the objects. Patches run before the overlay's `namespace` and `replicas` fields.

`configMapGenerator` creates a ConfigMap whose name ends in a hash of its content, and Kustomize rewrites every reference to the new name. A data change therefore changes the pod template, and the Deployment rolls out new pods. `kubectl diff -k` compares the rendered output with the cluster through a server-side dry run and exits with `1` when there are differences. `kubectl apply -k` applies the output but never deletes objects that left your files, such as old generated ConfigMaps.

A Kustomize build error starts with words that name the stage that failed: `accumulating resources` for a bad path, `no resource matches strategic merge patch` for a patch file without a matching object, and `replace operation does not apply` for a JSON 6902 path that does not exist. A patch whose `target` selects nothing is not an error at all, so only the rendered output or the diff shows it. The key facts to remember are these:

- One base holds what every environment shares; each overlay holds only its differences.
- Paths in a `kustomization.yaml` file are relative to the folder that holds that file.
- A changed generator literal produces a new ConfigMap name and a rollout.
- A `target` that matches nothing builds cleanly; read the diff before you apply.

<!-- astrona:playground:destroy -->
