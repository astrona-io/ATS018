# Package And Configure Applications With Helm — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-018-playground-020-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

Kubernetes 1.35 with Helm 4.3.0 installed in `~/.astrona/bin`, preloaded podinfo images `6.14.0` and `6.15.0`, and the `shuttle` client. The learner writes the chart in the terminal. No application release is installed at startup.

## Run it

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-020/module-01/playground
astrona destroy ats-018-playground-020-01
```

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Runtime, images and bootstrap wiring |
| `bootstrap/` | Install Helm and prepare namespaces and client |
| `manifests/lab-start.yaml` | Namespaces and request client |
| `docs/overview.md` | Environment details and practice ideas |
