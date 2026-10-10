# Hand Off From A Tekton Pipeline To GitOps — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-018-playground-040-02
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A single-node kind cluster (Kubernetes 1.35, `kindest/node:v1.35.8`) with
Tekton Pipelines 1.17.0 and Triggers 0.36.4, a plain-HTTP registry
(`registry:3.1.2`), Gitea with the private repositories `starfleet/scout-app`
and `starfleet/scout-deploy`, and Argo CD 3.5.4 with the auto-syncing
Application `scout`. Measured at about 2.2 GB of memory on the kind node.
Nothing to submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-018-playground-040-02
```

## How the registry works

Pipelines push to `registry.registry.svc:5000`. The kind node cannot resolve
cluster DNS, so `bootstrap/02-install-registry.sh` runs a privileged Job that
writes `/etc/containerd/certs.d/registry.registry.svc:5000/hosts.toml` on the
node, pointing that name at the Service's ClusterIP over HTTP. The same job
script copies the podinfo base images into the registry with `crane`.

Gitea's `webhook.ALLOWED_HOST_LIST` is `private,loopback`: with `*`, Gitea
28 refused to deliver to the in-cluster `EventListener` address ("denied by
egress").

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition (runtime, preloaded images, bootstrap order, port forwards) |
| `bootstrap/01-install-gitea.sh` | Starts Gitea and creates the user `platform` |
| `bootstrap/02-install-registry.sh` | Starts the registry, configures containerd, seeds the images |
| `bootstrap/03-install-argocd.sh` | Installs Argo CD 3.5.4 without Dex and notifications |
| `bootstrap/04-install-tekton.sh` | Installs Tekton Pipelines and Triggers |
| `bootstrap/05-seed.sh`, `seed-repo.sh` | Pushes both repositories, creates the Application and the `fetch-source` Task |
| `manifests/` | Namespace and `shuttle`, Gitea, the registry, the Application and the Task |
| `repos/` | Content of `scout-app` and `scout-deploy` |
| `docs/overview.md` | What the environment contains and ideas to try |
