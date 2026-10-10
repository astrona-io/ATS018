# Fetch Git With A Flux Source

The `scout-deploy` repository is private. Flux needs to fetch it before it can render any application files. A GitRepository says which repository and revision to fetch, how often to check, and which credential Secret to use. Start by checking that the controller which fetches Git is ready.

## Install and check the controllers

The playground already installed Flux 2.9.6. Repeating the pinned install makes the installation command concrete without creating a second installation. `flux install` applies controller Deployments and custom resource definitions. A custom resource definition adds a new kind of object to the Kubernetes application programming interface (API).

<!-- astrona:playground:renew -->

Run these commands on your machine against the playground:

```sh
flux install --version=v2.9.6
flux check
```

The install ends with this output, shortened to its readiness checks:

```text
◎ verifying installation
✔ helm-controller: deployment ready
✔ kustomize-controller: deployment ready
✔ notification-controller: deployment ready
✔ source-controller: deployment ready
✔ install finished
```

`flux check` checks Kubernetes compatibility, installed controller versions and custom resource definitions. Its output is shortened here:

```text
► checking prerequisites
✔ Kubernetes 1.35.8 >=1.33.0-0
► checking version in cluster
✔ distribution: flux-v2.9.6
✔ bootstrapped: false
► checking controllers
✔ helm-controller: deployment ready
► ghcr.io/fluxcd/helm-controller:v1.6.5
✔ kustomize-controller: deployment ready
► ghcr.io/fluxcd/kustomize-controller:v1.9.6
✔ notification-controller: deployment ready
► ghcr.io/fluxcd/notification-controller:v1.9.4
✔ source-controller: deployment ready
► ghcr.io/fluxcd/source-controller:v1.9.6
```

The source controller fetches Git and publishes artifacts. The kustomize controller renders and applies Kubernetes manifests. The helm controller installs chart releases. The notification controller sends notifications and handles configured webhook receivers. Only the first two are needed to deliver this repository, but all four are installed for this playground.

Installation alone does not connect Flux to Git. `bootstrapped: false` means this installation was not created through Flux's Git bootstrap workflow. You will create its source and applier explicitly.

## Fetch the deployment repository

A Secret is a Kubernetes object that stores private values. The Secret `scout-readonly` contains a username and password with read permission. It lives in `flux-system`, the same namespace as the source. The `secretRef` names that Secret; it does not contain the password in the source manifest.

Save this as `gitrepository-scout.yaml`:

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: scout
  namespace: flux-system
spec:
  interval: 1m
  url: http://gitea-http.gitea.svc:3000/starfleet/scout-deploy.git
  ref:
    branch: main
  secretRef:
    name: scout-readonly
```

Apply it:

```sh
kubectl apply -f gitrepository-scout.yaml
```

```text
gitrepository.source.toolkit.fluxcd.io/scout created
```

`ref.branch` selects `main`. `interval` tells the source controller how often to fetch. A successful fetch produces an artifact with a revision and a download address inside the cluster. The source has not deployed anything yet.

Then check the result:

```sh
kubectl -n flux-system wait gitrepository/scout --for=condition=Ready --timeout=90s
flux get sources git
kubectl -n flux-system get gitrepository scout -o jsonpath='{.status.artifact.revision}{"\n"}'
```

The source status and revision from the playground were:

```text
NAME 	REVISION          	SUSPENDED	READY	MESSAGE                                           
scout	main@sha1:fc4373ea	False    	True 	stored artifact for revision 'main@sha1:fc4373ea'
```

```text
main@sha1:fc4373eabde13cc546796801854ddc2d124794c2
```

`READY=True` means the fetch succeeded. The revision combines the branch and commit identifier; yours will differ because the playground creates a fresh repository. A source Ready condition proves that files were fetched, not that a workload runs.

An Argo CD Application combines source and destination settings in one object. Flux gives the fetched files their own GitRepository object. That split lets several appliers use the same fetched revision without giving each one separate Git credentials.

The repository is now available to Flux as an artifact. You know which component fetched it and which revision it stored. The remaining delivery work belongs to the kustomize controller.

## Common pitfalls

> [!WARNING]
> - **Putting the credential Secret in the application namespace.** The source reads its Secret from its own namespace, here `flux-system`.
> - **Reading source readiness as application health.** A fetched artifact has not yet been applied.
> - **Using the read-only account to push.** Fetch credentials and write credentials serve different jobs.
> - **Leaving the revision implicit.** Set the branch you intend to deliver and read the artifact revision when diagnosing a change.
