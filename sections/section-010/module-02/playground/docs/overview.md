# Overview: Package And Configure Applications With Helm (Playground)

This playground provides an ungraded Kubernetes environment. Helm is the command-line tool that renders chart templates and manages releases. A chart packages templates and values; a release is one installed copy of a chart. You create the chart yourself in the terminal.

## What is ready

The terminal has Helm 4.3.0 in `~/.astrona/bin` and `kubectl` connected to Kubernetes 1.35. Add `~/.astrona/bin` to your `PATH` if your shell has another Helm version first. The node holds `ghcr.io/stefanprodan/podinfo:6.14.0`, `ghcr.io/stefanprodan/podinfo:6.15.0` and `curlimages/curl:8.22.0`.

| Namespace | Starting state |
| --- | --- |
| `starfleet` | The `shuttle` client Deployment for requests |
| `starfleet-staging` | Empty application namespace |
| `starfleet-production` | Empty application namespace |

Podinfo is a web application on port `9898`. Its response includes the application version and a message. Its `PODINFO_UI_MESSAGE` environment variable sets that message.

## Practice ideas

- Render one chart twice with different replica values and compare the manifests before installing either.
- Add a values key without reading it in a template. Check whether linting catches it, then inspect the rendered Deployment.
- Install the same chart as separate releases in staging and production. List each namespace's releases.
- Upgrade one release twice. Choose an earlier revision from history, roll back and inspect the new revision and response.

There is no grading or submission. Remove the playground when you finish exploring.
