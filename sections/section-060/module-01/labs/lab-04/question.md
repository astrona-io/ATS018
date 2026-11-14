# Question

Solve this question on: `terminal`

Argo Workflows and its command-line tool are installed. The namespaces `starfleet` and `outpost` exist. ServiceAccount `deployment-writer` in `starfleet` has permission to report workflow results and manage Deployments in both namespaces. No WorkflowTemplate or target Deployment exists.

## Tasks

1. Create WorkflowTemplate `deploy-workload` in `starfleet` with the workflow parameters `image`, `name`, `namespace` and `task`. Pass all four into a template through `inputs.parameters`. Here `task` is a workload purpose, exposed through the container environment variable `PODINFO_UI_MESSAGE`.
2. Use a `resource` template to submit an `apps/v1` Deployment manifest. Fill its name, namespace, matching `app` labels and container image from those inputs. Set `resource.action: create` and use the `task` input for `PODINFO_UI_MESSAGE`. Set one replica, a readiness probe on `/readyz` at port `9898`, and annotation `training.astrona.io/workflow-uid: "{{workflow.uid}}"`. Wait for `status.availableReplicas > 0` before the resource step succeeds. Run as `deployment-writer`.
3. Submit both runs below with the Argo command-line tool. The values are ready to use; the template must work without editing between runs.
4. Inspect the two successful workflows and their resource nodes. Verify the ready Deployment `scout` in `outpost` uses image `6.15.0`, and `probe` in `starfleet` uses image `6.14.0`. Each Deployment's annotation must identify the workflow that created it.

```sh
argo submit -n starfleet --from workflowtemplate/deploy-workload \
  -p image=ghcr.io/stefanprodan/podinfo:6.15.0 \
  -p name=scout -p namespace=outpost -p task=release-check --wait

argo submit -n starfleet --from workflowtemplate/deploy-workload \
  -p image=ghcr.io/stefanprodan/podinfo:6.14.0 \
  -p name=probe -p namespace=starfleet -p task=preview-check --wait
```

Keep both successful runs for grading. Do not create the Deployments directly or use a container step that runs kubectl. Use `export PATH="$HOME/.astrona/bin:$PATH"` if your shell cannot find `argo`.

Learner work: about 15 minutes. Cluster startup, controller reconciliation and rollouts take additional time.
