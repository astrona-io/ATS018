# Prerequisites

- `kubectl` 1.35 and the `tkn` command-line tool on your `PATH`. Bootstrap installs `tkn` 0.46.1 in `~/.astrona/bin` unless you already have a `tkn`. If it is not found, run `export PATH="$HOME/.astrona/bin:$PATH"`.
- Know a Task, a Pipeline, a PipelineRun, `runAfter`, params and results, a ServiceAccount and a ClusterRole.
- Bootstrap installs Tekton Pipelines 1.17.0 and creates the namespace `starfleet`, the `shuttle` pod, the ServiceAccount `outpost-provisioner`, the ClusterRole and ClusterRoleBinding `namespace-provisioner`, four Tasks and the Pipeline `outpost-onboard`.
- One PipelineRun of `outpost-onboard` has already failed when the lab starts.
- The node preloads `alpine:3.23`, `alpine/kubectl:1.35.4` and `curlimages/curl:8.22.0`.
