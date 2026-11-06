# Prerequisites

- Have `kubectl` 1.35 and `curl` on the terminal. The `shuttle` Deployment supplies `curl` inside the cluster. Bootstrap installs `tkn` 0.46.1 if it is absent; if needed, run `export PATH="$HOME/.astrona/bin:$PATH"`.
- Know that a Pipeline describes Tasks, a PipelineRun executes it, and params carry named values. A ServiceAccount gives a pod its Kubernetes identity. Role-based access control (RBAC) grants that identity permission through Roles and bindings.
- Bootstrap installs Tekton Pipelines 1.17.0 and Triggers 0.36.4. It creates `starfleet`, `shuttle`, the Pipeline `scout-check`, and the ServiceAccounts `scout-listener` and `scout-runner`.
- The EventListener `scout-push` exists. Its trigger `push` references the missing binding and template `scout-unwired`. The listener has read access to Triggers resources and cluster-scoped objects, but no right to create PipelineRuns.
- The node preloads `alpine:3.23` and `curlimages/curl:8.22.0`; the Tekton controller and helper images are pulled from `ghcr.io` during bootstrap. No Git server, registry or interceptor is needed.
