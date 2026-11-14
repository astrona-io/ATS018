# Review And Apply An Attribute Change

The `scout` Deployment needs two replicas. An attribute is a named setting in a
resource block, such as `replicas`. Changing the configuration does not change
the cluster until OpenTofu applies it. A plan is the proposed set of operations
that lets you review that change first.

<!-- astrona:playground:renew -->

Inspect the configuration and live replica count:

```sh
cd ~/resources/tofu/scout
cat deployment.tf
kubectl -n starfleet get deployment scout
```

Save this as `deployment.tf`, replacing the supplied Deployment configuration:

```hcl
resource "kubernetes_deployment" "scout" {
  metadata {
    name      = "scout"
    namespace = "starfleet"
  }
  spec {
    replicas = 2
    selector {
      match_labels = { app = "scout" }
    }
    template {
      metadata {
        labels = { app = "scout" }
      }
      spec {
        container {
          name  = "scout"
          image = "ghcr.io/stefanprodan/podinfo:6.15.0"
          port {
            container_port = 9898
          }
          readiness_probe {
            http_get {
              path = "/readyz"
              port = 9898
            }
          }
          resources {
            requests = { cpu = "10m", memory = "32Mi" }
          }
        }
      }
    }
  }
}
```

The `replicas` attribute inside `spec` now requests two pods. The selector,
pod labels, container image and readiness check keep their original values.
OpenTofu's Kubernetes provider will update the existing Deployment when the
plan is applied.

Apply it after reviewing a saved plan:

```sh
tofu init
tofu plan -no-color -out=change.plan
tofu show -no-color change.plan > plan.txt
cat plan.txt
```

Look for an in-place update of `kubernetes_deployment.scout`, with `replicas`
changing from one to two. Stop if the plan proposes an unexpected deletion or
replacement. `-no-color` removes terminal color codes. `-out` saves a binary
plan that OpenTofu can apply. `tofu show` converts that saved plan into readable
text, which the shell writes to `plan.txt`.

For a text-only review you can instead run `tofu plan -no-color > diff.txt`.
That file records the plan display, but it is not an executable plan. Use the
binary plan when you want to apply the exact operations you reviewed. Both
saved plans and their readable text can contain sensitive information.

After reviewing `plan.txt`, apply the binary plan:

```sh
tofu apply change.plan
kubectl -n starfleet rollout status deployment/scout --timeout=180s
kubectl -n starfleet get deployment scout
tofu show -no-color
tofu plan -no-color
```

A saved plan applies without a new approval prompt, so review it before running
`apply`. Without a plan file, `tofu apply` makes a fresh plan and asks you to
type `yes`. The Kubernetes Deployment controller creates the extra pod; OpenTofu
updates the Deployment and records the result in state. Look for two available
replicas and a final plan with no changes.

You have now reviewed a proposed update, applied it and checked the live result.
The Deployment has the right capacity, but it still needs a Service so clients
can reach its pods through a stable address.

## Common pitfalls

> [!WARNING]
> A text diff cannot be passed to `tofu apply`. Keep `change.plan` for applying
> and `plan.txt` for reading. If the configuration or cluster changes after
> review, make and review a fresh plan. Do not use `kubectl scale` as the lasting
> fix: the next normal plan compares that live change with the configuration.
