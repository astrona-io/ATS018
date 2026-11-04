# Question

Solve this question on: `terminal`

## Scenario

The `drifter` team checks each `scout` release with Argo Workflows in the namespace `starfleet`. The WorkflowTemplate `scout-check` compares a version with the record in the ConfigMap `scout-release`, and its last run failed. The team also wants settings for a new site in the namespace `outpost`. The WorkflowTemplate `outpost-config` creates them in the namespace named by its parameter `target-namespace`.

The ServiceAccount `outpost-provisioner` in `starfleet` has the rights that `outpost-config` needs in `outpost`. The template itself names no ServiceAccount.

Use the `argo` command-line tool for this work. It reads your kubeconfig and needs no web server. If your shell does not find it, run `export PATH="$HOME/.astrona/bin:$PATH"`.

## Tasks

1. **Find the cause of the failure.** Use `argo list`, `argo get` and `argo logs` in `starfleet` to find out why the existing run of `scout-check` failed.
2. **Fix the WorkflowTemplate.** Change `scout-check` so that its `check-version` template reads the right file. Do not change the ConfigMap `scout-release`, the volume or the argument `expected-version`, and keep the `grep` comparison.
3. **Run a copy of the step in parallel.** In the `steps` list of the template `main`, add a step named `check-version-copy` that uses the template `check-version`. It must start together with `check-version`, after `prepare` ends. Keep a `steps` list. Do not change it to a DAG (directed acyclic graph).
4. **Run the check.** Start a new run with `argo submit --from workflowtemplate/scout-check`. Repeat until a run with both copies of the step is `Succeeded`.
5. **Create the settings.** Start a run of `outpost-config` with `argo submit`, give it the parameter `target-namespace` with the value `outpost`, and run it as `outpost-provisioner`. Wait until it is `Succeeded`. The run creates the ConfigMap `scout-settings` and the ServiceAccount `scout` in `outpost`. Do not create them yourself and do not change `outpost-config`.
6. **Clean up.** Use `argo delete` so that `starfleet` holds exactly one Workflow for each of the two WorkflowTemplates, and both are `Succeeded`.

Check your progress with `astrona submit --watch`. A plain `astrona submit` finishes the attempt and deletes the lab, so run it once, at the end.
