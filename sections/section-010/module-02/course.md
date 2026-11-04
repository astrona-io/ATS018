# Package And Configure Applications With Helm

Helm is a command-line tool that renders Kubernetes templates and manages installed copies of them. A chart is a package of templates and default values. A release is one installed copy of a chart, and a revision is a numbered record of an install, upgrade or rollback.

You will build a small chart for `scout`, change its configuration and recover an earlier release revision. This compact module teaches the Helm command-line workflow used in the CNPE simulator. CNPE means Certified Cloud Native Platform Engineer.

The module has three parts. **Chart Layout, Rendering And Installation** creates `Chart.yaml`, `values.yaml` and `templates/`, then checks and installs the chart. **Values, Templates And Versions** separates environment settings from template changes and upgrades a release. **History And Rollback** inspects revisions and restores a known configuration. The summary closes the module.

## Learning objectives

After this module you can:

- Read a chart's layout and render and lint it before installation.
- Choose a values override or a template edit and update chart and application versions.
- Install and upgrade a release in a namespace, list it, inspect its history and roll it back.

## Before you start

You need basic Kubernetes knowledge: a namespace groups resources, a Deployment maintains application pods, and a Service gives ready pods a stable address. You should know `kubectl get`, `kubectl apply` and `kubectl exec`.

The playground installs Helm **4.3.0** in the terminal's `~/.astrona/bin` directory. Use that terminal for all commands. It supplies Kubernetes 1.35, empty `starfleet-staging` and `starfleet-production` namespaces, and a `shuttle` client Deployment in `starfleet`. The podinfo application images `6.14.0` and `6.15.0`, and the client image `curlimages/curl:8.22.0`, are preloaded. Podinfo serves a response with its application version and message on port `9898`.

Write the chart in a new working directory in the terminal. Start the playground before following the commands.

<!-- astrona:playground -->
