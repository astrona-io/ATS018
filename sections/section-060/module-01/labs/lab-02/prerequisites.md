# Prerequisites

- `kubectl` 1.35 and the `argo` command-line tool on your `PATH`. Bootstrap installs `argo` v4.1.6 in `~/.astrona/bin` unless you already have an `argo`. If it is not found, run `export PATH="$HOME/.astrona/bin:$PATH"`.
- Know a Workflow, a WorkflowTemplate, Workflow parameters, a `steps` template and a resource template.
- Bootstrap installs Argo Workflows v4.1.6 in `starfleet` without its web server, and creates `outpost`, the `shuttle` pod, the ConfigMap `scout-release`, the WorkflowTemplates `scout-check` and `outpost-config`, and the ServiceAccounts `workflow-runner` and `outpost-provisioner`.
- One run of `scout-check` has already failed when the lab starts.
- The node preloads `alpine:3.23`, `curlimages/curl:8.22.0` and the Argo Workflows `v4.1.6` images.
