# Build Tekton Tasks And Pipelines — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-018-playground-040-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A single-node kind cluster (Kubernetes 1.35, `kindest/node:v1.35.8`) with
Tekton Pipelines 1.17.0 and its remote resolvers, the public Gitea repository
`starfleet/scout-app` (`VERSION`, `test.sh`, `tekton/run-tests.yaml`) and the
`run-tests` Task in `starfleet`, which fails on purpose because its
`workingDir` is `/workspace/wrong`. Nothing to submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-018-playground-040-01
```

The Tekton images are pulled at start, not preloaded: they are pinned by
digest in the release manifest, and preloading digest-pinned images makes the
pods fail with `CreateContainerError`.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition (runtime, preloaded images, bootstrap order) |
| `bootstrap/01-install-gitea.sh` | Starts Gitea and creates the user `platform` |
| `bootstrap/02-install-tekton.sh` | Installs Tekton Pipelines 1.17.0 and waits for its webhook |
| `bootstrap/03-seed.sh`, `seed-repo.sh` | Pushes `repos/scout-app` as a public repository and installs the broken Task |
| `manifests/` | Namespace, `shuttle`, Gitea and the `run-tests` Task |
| `repos/scout-app/` | Source files pushed into Gitea |
| `docs/overview.md` | What the environment contains and ideas to try |
