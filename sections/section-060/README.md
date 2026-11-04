# Section 060: Infrastructure Deployment Through GitOps

Everything in the earlier sections delivers applications. A platform team also delivers the infrastructure and the platform APIs that those applications use. This section teaches Crossplane, which turns Kubernetes into a control plane for any resource: you describe a resource as a Kubernetes object, and a controller creates and maintains the real thing.

Argo CD or Flux delivers the Crossplane objects from Git. A compact OpenTofu module adds an explicit plan and apply workflow with the Kubernetes provider. OpenTofu runs changes on demand; Crossplane continuously reconciles its managed resources.

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
- Read OpenTofu state, save a readable plan, change an attribute and add a Kubernetes Service
- Compare OpenTofu apply operations with Crossplane reconciliation

---

## The Learning Path

The section has the modules below, in reading order. Each module has a playground for practice, and the section ends with a capstone challenge.

### 1. Deliver Infrastructure Objects With Crossplane And GitOps
*   **Module Reader:** Deliver Infrastructure Objects With Crossplane And GitOps
*   **Hands-on Playground:** `sections/section-060/module-01/playground` — kind cluster with Crossplane 2.4.3, Gitea (repository `starfleet/platform-infra`), Argo CD 3.5.4 and Flux 2.9.6. The namespaces `starfleet`, `starfleet-staging` and `starfleet-production` exist, with `shuttle` in `starfleet`. Deliberately absent: no `Provider`, no `Function`, no XRD and no `Composition`. The repository holds a production environment with a wrong image tag.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-060/module-01/playground
    ```

### 2. Plan And Apply Kubernetes Resources With OpenTofu

* **Module Reader:** Plan And Apply Kubernetes Resources With OpenTofu — three compact parts on state, attribute changes and adding a Service, followed by a summary, a 20-minute lab and ten questions.
* **Hands-on Playground:** OpenTofu 1.13.2 and Kubernetes provider 3.4.0 on the terminal. `~/resources/tofu/scout` has a managed Deployment and real local state, but no Service.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-060/module-02/playground
```

### Section Capstone Challenge
*   **Comprehensive Challenge:** Infrastructure Deployment Through GitOps Capstone — `sections/section-060/capstone/labs/lab-01`
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-060/capstone/labs/lab-01
    astrona submit -c .
    ```
*   **Hands-on Objective:** Deliver a Crossplane platform API and one environment from Git, find why the environment is not Ready, fix it in Git, and prove the application answers from `shuttle`.

* **OpenTofu Capstone:** Repair Three OpenTofu Working Directories — 35 minutes. Review a pending update in `scale`, add a Service in `expose`, and repair live drift in `drift`. Save a readable plan in each directory and prove the final state and requests agree.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-060/capstone/labs/lab-02
astrona submit --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-060/capstone/labs/lab-02
```

---

## Ready for Assessment?

*   Take the knowledge check for this section.
