# Reconcile Git Sources With Flux Kustomizations

The `scout` application belongs in staging, with its image and settings held in Git. Flux is a GitOps controller that reads that desired state and changes the live cluster to match it. GitOps means keeping the desired state in a versioned Git repository and letting a controller apply it continuously.

Flux splits delivery into two objects. A `GitRepository` fetches a repository and stores its files as an artifact, a copy that another controller can use. A Flux `Kustomization` renders one path from that artifact and applies the resulting Kubernetes objects. You can check a fetch failure separately from an apply failure.

The module has three parts. **Fetch Git With A Flux Source** checks the controllers and creates the source. **Apply Paths And Order Dependencies** creates an application and the namespace it needs, then checks readiness and a real response. **Reconcile, Suspend And Resume** pauses delivery, proves that reconciliation repairs drift, and delivers a committed change.

## Learning objectives

After this module you can:

- Install the Flux controllers and verify them with `flux check`.
- Create a GitRepository and a Flux Kustomization with pruning enabled.
- Read Ready conditions and diagnose source and apply failures.
- Force reconciliation and suspend and resume a Kustomization.
- Order two Kustomizations with `dependsOn`.

## Before you start

You need namespaces, Deployments, Services, Secrets, Kustomize directories and basic Git commands. A namespace groups Kubernetes objects. A Deployment keeps application pods running, and a Service gives ready pods a stable network address. A Secret stores credentials or other private values.

The playground runs Kubernetes 1.35.8 and Flux 2.9.6. Its four controllers are in `flux-system`. The private `starfleet/scout-deploy` repository contains a shared base, a staging overlay and a namespace directory. The read-only Secret `scout-readonly` already exists. Gitea hosts the repository as bootstrap plumbing.

`shuttle` runs in `starfleet` as a client. There is no application in staging yet, and no GitRepository or Flux Kustomization. The node has podinfo 6.14.0 and 6.15.0 preloaded. Run commands on your machine against the playground; use the Flux 2.9.6 command-line tool.

<!-- astrona:playground -->
