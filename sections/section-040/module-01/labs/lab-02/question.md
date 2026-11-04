# Question

Solve this question on: `terminal`

## Scenario

The `drifter` team prepares a namespace for each new site with the Tekton Pipeline `outpost-onboard` in the namespace `starfleet`. The Pipeline runs the Tasks `plan-namespace`, `create-namespace` and `report-namespace`. The Task `plan-namespace` has a result `namespace`, which holds the name `outpost-<site>`.

The first run, `outpost-onboard-first-try`, failed. The team also wants each new namespace to carry a label for its tier. The Task `label-namespace` already exists in `starfleet` and does this work, but the Pipeline does not use it yet.

The ServiceAccount `outpost-provisioner` in `starfleet` is bound to the ClusterRole `namespace-provisioner`.

Use the `tkn` command-line tool to start and read the runs. If your shell does not find it, run `export PATH="$HOME/.astrona/bin:$PATH"`.

## Tasks

1. **Find the cause of the failure.** Use `tkn` in `starfleet` to find out why `outpost-onboard-first-try` failed, and which account its pods used.
2. **Add the Task.** Change the Pipeline `outpost-onboard`. Add a string param `tier` to the Pipeline. Add a Pipeline task named `label-namespace` that references the Task `label-namespace`. It must start at the same time as `report-namespace`, after `create-namespace` ends, and `report-namespace` must keep its current order. Set the Task param `namespace` from the result of `plan-namespace`, and the Task param `tier` from the Pipeline param `tier`.
3. **Fix the rights.** Change the ClusterRole `namespace-provisioner` so that all four Tasks can do their work on namespaces. Add only what they need, and allow nothing except namespaces. Give the ServiceAccount `default` no new rights.
4. **Run the Pipeline for two sites.** Use `tkn pipeline start` with `-p` to start two runs as `outpost-provisioner`. Use `site=vega` with `tier=gold`, and `site=rigel` with `tier=silver`. Both runs must end as `Succeeded`, and they must create and label `outpost-vega` and `outpost-rigel`.
5. **Save a log.** When the `rigel` run has ended, save the output of `tkn pipelinerun logs` for that run to `/tmp/outpost-rigel-run.log`.
6. **Clean up.** Use `tkn` to delete every failed PipelineRun of `outpost-onboard`. Keep the runs for both sites.

Check your progress with `astrona submit --watch`. A plain `astrona submit` finishes the attempt and deletes the lab, so run it once, at the end.
