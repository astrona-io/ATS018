# Prerequisites

- `kubectl` 1.35 and the `argo` command-line tool on your `PATH`. Bootstrap installs `argo` v4.1.6 in `~/.astrona/bin` unless you already have an `argo`. If it is not found, run `export PATH="$HOME/.astrona/bin:$PATH"`.
- Know a Workflow, a WorkflowTemplate, a `steps` template with groups, and input and output parameters.
- Bootstrap installs Argo Workflows v4.1.6 in `starfleet` without its web server, and creates the `shuttle` pod, the ServiceAccount `workflow-runner` and the WorkflowTemplate `shuttle-release`.
- One run of `shuttle-release` has already succeeded when the lab starts.
- The node preloads `alpine:3.23`, `curlimages/curl:8.22.0` and the Argo Workflows `v4.1.6` images.
