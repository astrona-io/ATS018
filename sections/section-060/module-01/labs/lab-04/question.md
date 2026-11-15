---
title: Create Deployments From Workflow Inputs
estimated_duration: 15m
---
# Question

Solve this question on: `terminal`

Argo Workflows and the `argo` command-line tool are installed. The ServiceAccount `deployment-writer` in namespace `starfleet` may create Deployments in `starfleet` and `outpost`.

1. Create a WorkflowTemplate `deploy-workload` in `starfleet` that runs as the ServiceAccount `deployment-writer` and declares four parameters: `image`, `name`, `namespace` and `msg`.
2. Add a `resource` template with action `create` that creates a Deployment. Fill its name, its namespace, the label `app: <name>` and the image of its one container from the parameters.
3. Make the container print the `msg` value to its log when it starts, then keep running. The resource step succeeds only when `status.availableReplicas > 0`.
4. Submit this run with the `argo` command-line tool:

```sh
argo submit -n starfleet --from workflowtemplate/deploy-workload \
  -p image=alpine:3.23 -p name=scout -p namespace=outpost \
  -p msg="scout is running" --wait
```

The workflow must finish `Succeeded`. Keep it for grading. Do not create the Deployment with `kubectl`, and do not write the run's values into the template.

If your shell cannot find `argo`, run `export PATH="$HOME/.astrona/bin:$PATH"`.
