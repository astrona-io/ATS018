# Question

Solve this question on: `terminal`

## Scenario

The `drifter` team releases the `shuttle` service with Argo Workflows in the namespace `starfleet`. The WorkflowTemplate `shuttle-release` runs three steps in order: `fetch-manifest` writes the release manifest and exports it as the output parameter `manifest`, `deploy` prints the manifest it deploys, and `notify` reports that the release is done. One run of the template has already succeeded.

A review found that nothing checks the manifest before `deploy` uses it. The team wants a checksum step between the two.

Use the `argo` command-line tool for this work. It reads your kubeconfig and needs no web server. If your shell does not find it, run `export PATH="$HOME/.astrona/bin:$PATH"`.

## Tasks

1. **Add the template.** In the WorkflowTemplate `shuttle-release`, add a template named `verify-checksum`. It takes the input parameter `manifest`, computes the SHA-256 digest of exactly that value with `sha256sum`, writes the digest to a file and exports the file as the output parameter `checksum`. Use the image `alpine:3.23`.
2. **Insert the step.** In the `steps` list of the template `main`, add a step named `verify-checksum` that uses the template `verify-checksum`. It must start after `fetch-manifest` ends and end before `deploy` starts, so each of the four steps sits in its own group: `fetch-manifest`, `verify-checksum`, `deploy`, `notify`. Pass the parameter `manifest` with the value `{{steps.fetch-manifest.outputs.parameters.manifest}}`. Keep a `steps` list. Do not change it to a DAG (directed acyclic graph).
3. **Keep the rest.** Do not change the templates `fetch-manifest`, `deploy` and `notify`, the step `deploy` and its argument, the entrypoint or the ServiceAccount.
4. **Run it.** Start a new run with `argo submit --from workflowtemplate/shuttle-release` and wait until it is `Succeeded`. Read its tree with `argo get` and the checksum line with `argo logs`.
5. **Clean up.** Use `argo delete` so that `starfleet` holds exactly one Workflow: your `Succeeded` run of the changed template. The run that existed when the lab started must go.

Check your progress with `astrona submit --watch`. A plain `astrona submit` finishes the attempt and deletes the lab, so run it once, at the end.
