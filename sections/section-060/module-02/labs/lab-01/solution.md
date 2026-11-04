# Solution Walkthrough

Inspect each working directory, save a review, then apply it. State is the
record that maps configuration addresses to real objects. Keep that mapping
while changing the resources through OpenTofu.

| Goal | Record | Command |
| --- | --- | --- |
| Read managed identities | Local state | `tofu state list` |
| Preview live changes | Saved binary plan | `tofu plan -out=change.plan` |
| Save a readable review | Text file | `tofu show -no-color change.plan > plan.txt` |
| Change live resources | Kubernetes API | `tofu apply change.plan` |

## The feedback loop

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-060/module-02/labs/lab-01
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

The checks are `scout`. Each requires a saved review and the applied
result, so none should pass on the untouched starting environment.

## Step 1: Review and apply scout

Read the files and state before making changes:

```sh
cd ~/resources/tofu/scout
ls -a
cat provider.tf
cat deployment.tf
tofu init
tofu state list
tofu show -no-color
kubectl -n starfleet get deployment scout
```

In `deployment.tf`, change `replicas = 1` to `replicas = 2` inside the
Deployment's `spec` block. Keep the other attributes unchanged.

Save this as `service.tf`:

```hcl
resource "kubernetes_service" "scout" {
  metadata {
    name      = "scout"
    namespace = kubernetes_deployment.scout.metadata[0].namespace
  }
  spec {
    selector = kubernetes_deployment.scout.spec[0].template[0].metadata[0].labels
    port {
      port        = 80
      target_port = 9898
    }
    type = "ClusterIP"
  }
}
```

The metadata block selects the name and the Deployment's namespace. The
selector reads the Deployment's pod labels. The port block forwards port 80
to port 9898, and `ClusterIP` keeps the address inside the cluster.

Apply it after reviewing the saved plan:

```sh
tofu plan -no-color -out=change.plan
tofu show -no-color change.plan > plan.txt
cat plan.txt
```

Look for the Deployment update from one replica to two and one Service creation. The plan
must retain the existing Deployment. Apply the reviewed binary plan:

```sh
tofu apply change.plan
kubectl -n starfleet rollout status deployment/scout --timeout=180s
kubectl -n starfleet exec deploy/shuttle -- curl -fsS http://scout.starfleet/
tofu plan -no-color
```

Look for version `6.15.0` in the response and a fresh plan with no changes.
The watch terminal shows `scout` passing. It compares the saved review with
live resource identities, checks state and configuration, and sends a request.
Stop the watch with Ctrl-C, then run the plain command once:

```sh
astrona submit --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-060/module-02/labs/lab-01
```

## If a check stays red

- A missing review means `change.plan` or `plan.txt` was not saved in the
  working directory. Generate the readable file with `tofu show`, not a copy
  of terminal text. Preserve the pre-apply review after applying.
- A wrong Service selector means it does not match pod labels. Read the
  labels from the Deployment resource and check port 80 targets port 9898.
- A fresh plan with changes means configuration and live resources differ.
  Fix the configuration and apply it; a manual Kubernetes edit is not enough.
- An initialization error means the provider download or credentials failed.
  Check network access and the supplied `kubeconfig` path. Do not delete state
  or switch to a different cluster to bypass the error.
