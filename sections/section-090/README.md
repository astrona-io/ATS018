# Section 090: Infrastructure Delivery With Crossplane

A GitOps controller delivers applications. A platform team also delivers the infrastructure and the platform APIs that those applications use. This section teaches Crossplane, which turns Kubernetes into a control plane for any resource: you describe a resource as a Kubernetes object, and a controller creates and maintains the real thing.

Argo CD or Flux delivers the Crossplane objects from Git. Crossplane then reconciles its managed resources all the time, so a change in Git reaches the cluster without a manual apply step.

**Curriculum item covered:** Implementing GitOps Workflows for Application and Infrastructure Deployment

---

## What You Will Master

- Install a Crossplane `Provider` and a `Function` and read their Healthy status
- Give a provider the permissions it needs and connect it with a `ClusterProviderConfig`
- Define your own platform API with a `CompositeResourceDefinition` (XRD)
- Map that API to real objects with a `Composition` in Pipeline mode
- Create a composite resource (XR) and read its Synced and Ready conditions
- Deliver the XRD, the `Composition` and the XRs from Git with an Argo CD `Application`, using sync waves
- Show the real health of an XR in Argo CD with a custom health check
- Diagnose a composite resource that is not Ready, and fix it through Git
- Deliver the same objects with a Flux `Kustomization` that uses `dependsOn` and `wait`

---

## The Learning Path

The section has one module. The module has a playground for practice.

### 1. Deliver Infrastructure Objects With Crossplane And GitOps
*   **Module Reader:** Deliver Infrastructure Objects With Crossplane And GitOps
*   **Hands-on Playground:** `sections/section-090/module-01/playground` — kind cluster with Crossplane 2.4.3, Gitea (repository `starfleet/platform-infra`), Argo CD 3.5.4 and Flux 2.9.6. The namespaces `starfleet`, `starfleet-staging` and `starfleet-production` exist, with `shuttle` in `starfleet`. Deliberately absent: no `Provider`, no `Function`, no XRD and no `Composition`. The repository holds a production environment with a wrong image tag.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-090/module-01/playground
    ```

---

## Ready for Assessment?

*   Take the knowledge check for this section.
