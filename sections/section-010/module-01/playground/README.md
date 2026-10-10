# Build Environment Overlays With Kustomize — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-018-playground-010-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A single-node kind cluster (Kubernetes 1.35, `kindest/node:v1.35.8`) with the
empty namespaces `starfleet-staging` and `starfleet-production`, and the
`shuttle` client in `starfleet`. The podinfo images `6.14.0` and `6.15.0` are
preloaded. The learner writes the Kustomize files on their own machine.
Nothing to submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-018-playground-010-01
```

`astrona destroy` takes the environment name (`metadata.name` =
`ats-018-playground-010-01`), not the config path. `astrona submit` and
`astrona test` do not apply — there is no grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition (runtime, preloaded images, starting manifests) |
| `manifests/lab-start.yaml` | Namespaces and the `shuttle` client |
| `docs/overview.md` | What the environment contains and ideas to try |
