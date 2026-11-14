# Overview: Deliver Infrastructure Objects With Crossplane And GitOps (Playground)

This playground starts a fresh Kubernetes cluster for working with Crossplane and GitOps. There is no grading or submission. Crossplane is a set of Kubernetes controllers that create and maintain resources from objects you define. Argo CD and Flux are the GitOps controllers that deliver those objects from Git.

## What's in the box

The single-node cluster runs Kubernetes 1.35.8 and Crossplane 2.4.3. A Git server (Gitea) holds the repository `starfleet/platform-infra`.

| Place | What is in it |
| --- | --- |
| `crossplane-system` | The Crossplane controller and the RBAC manager. No `Provider` and no `Function` yet |
| `argocd` | Argo CD 3.5.4 and the repository Secret `repo-platform-infra` |
| `flux-system` | Flux 2.9.6 (source, kustomize and notification controllers) and the Secret `platform-infra-auth` |
| `gitea` | The Git server |
| `starfleet` | The `shuttle` client pod |
| `starfleet-staging`, `starfleet-production` | Empty namespaces for the two environments |

The repository has the platform API in `platform/` (a `CompositeResourceDefinition` and a `Composition`) and one `ScoutEnvironment` each in `environments/staging` and `environments/production`. The production file asks for a podinfo tag that does not exist.

Argo CD answers on `https://127.0.0.1:8080` (user `admin`, password in the Secret `argocd-initial-admin-secret`). Gitea answers on `http://127.0.0.1:3000` with the user `platform` and the password `starfleet-gitops`.

## Helpers

Paste this function into each new terminal. It prints the version and message that an environment returns to `shuttle`. Give it the namespace.

```sh
ask_scout() {
  kubectl -n starfleet exec deploy/shuttle -- curl -s "http://scout.$1/" | grep -E '"(version|message)"'
}
```

For example, `ask_scout starfleet-staging`.

If you run more than one cluster, other tools can switch your `kubectl` context. Export a kubeconfig for this cluster only: `kind get kubeconfig --name astro-ats-018-playground-090-01 > kubeconfig-crossplane` and `export KUBECONFIG=$PWD/kubeconfig-crossplane`.

## Practice tasks

- Install `provider-kubernetes` v1.4.1 and `function-patch-and-transform` v0.11.2 and wait until both are `HEALTHY`.
- Apply the platform API and the staging environment by hand. Read the conditions of the XR, the `Object` resources and the Deployment.
- Deliver the repository with an Argo CD `Application` and add a health check so a not-Ready XR shows as `Degraded`.
- Find why production is not Ready, and fix it in Git.
- Remove the `Application` and deliver the same repository with two Flux `Kustomization` objects that use `dependsOn` and `wait`.
