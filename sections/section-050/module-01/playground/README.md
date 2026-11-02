# Roll Out A Canary With Argo Rollouts — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-018-playground-050-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no grading

A single-node kind cluster (`kindest/node:v1.35.8`) with the Argo Rollouts
1.10.0 controller in `argo-rollouts`. Namespace `starfleet` starts with a
five-replica `scout` Deployment on podinfo 6.14.0, its Service and the
`shuttle` client. Images 6.14.0 and 6.15.0 are preloaded. No Rollout, traffic
router or metrics provider exists. Nothing to submit.

Use `kubectl` 1.35.8 and `kubectl-argo-rollouts` 1.10.0 on the host, with the
plugin executable on `PATH`. Bootstrap needs outbound internet to fetch the
pinned controller install manifest. Scripts use macOS-compatible bash.

## Run it

```sh
astrona run -c sections/section-050/module-01/playground --trust
astrona destroy ats-018-playground-050-01
```

Run these commands from the course root. Destroy takes `metadata.name`, not
the configuration path. The learner writes the Rollout manifest locally;
bootstrap deliberately leaves the application as a Deployment.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Runtime, preloaded images, bootstrap and readiness checks |
| `bootstrap/01-install-argo-rollouts.sh` | Installs the pinned controller and waits for it |
| `manifests/lab-start.yaml` | Namespace, starting application, Service and client |
| `docs/overview.md` | Environment contents, readable helpers and practice tasks |
