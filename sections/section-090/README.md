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
