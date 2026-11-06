# Question

Solve this question on: `terminal`

## Scenario

The `scout-push` EventListener in `starfleet` receives requests but creates no runs. An EventListener is the Tekton Triggers resource that turns an incoming request into Kubernetes resources. Its trigger `push` references the missing binding and template `scout-unwired`, and its ServiceAccount `scout-listener` cannot create PipelineRuns.

The Pipeline `scout-check` already exists. A PipelineRun is one execution of a Pipeline; this Pipeline checks that its string params `revision` and `repository` are nonempty. The ServiceAccount `scout-runner` and the client Deployment `shuttle` also exist. Keep the Pipeline unchanged.

## Tasks

1. **Extract two payload fields.** Create the TriggerBinding `scout-push` in `starfleet`. A TriggerBinding names values extracted from a request. Set param `revision` to `$(body.ref)` and param `repository` to `$(body.repository.full_name)`.

2. **Create runs from those values.** Create the TriggerTemplate `scout-check` in `starfleet`. A TriggerTemplate defines resources to create with bound params. Declare `revision` and `repository`. Its first resource template must be a `tekton.dev/v1` PipelineRun in `starfleet` with `generateName: scout-check-`, referencing the existing Pipeline `scout-check`. Set its `revision` and `repository` params to `$(tt.params.revision)` and `$(tt.params.repository)`. Set `spec.taskRunTemplate.serviceAccountName` to `scout-runner`.

3. **Connect the listener and repair access.** Keep the EventListener `scout-push` and its trigger name `push`. Connect that trigger to the TriggerBinding `scout-push` and TriggerTemplate `scout-check`. Keep `spec.serviceAccountName: scout-listener`. Repair role-based access control (RBAC) so `scout-listener` can get, list and watch EventListeners, TriggerBindings and TriggerTemplates in `starfleet`, and create PipelineRuns there. Cluster-scoped read permissions are already provided. Accept requests with other field values too; do not hard-code the sample values in the template.

4. **Send an in-cluster request.** Use `curl` from the `shuttle` Deployment to send an HTTP POST request to `http://el-scout-push.starfleet.svc:8080`, with `Content-Type: application/json` and this JavaScript Object Notation (JSON) body: `{"ref":"refs/heads/main","repository":{"full_name":"starfleet/scout-app"}}`. Leave its event-created PipelineRun in the cluster. It must use `scout-runner`, carry `revision=refs/heads/main` and `repository=starfleet/scout-app`, and reach condition `Succeeded=True`. The listener must also create successful new runs with both matching params when it receives other payload values.
