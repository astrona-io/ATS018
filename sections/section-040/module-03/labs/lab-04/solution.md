# Solution

A WorkflowTemplate stores a reusable workflow specification. Workflow arguments enter the `main` step, which passes them to the resource template's local inputs. The resource template creates the Deployment and waits for an available replica.

Save this as `workflowtemplate-deploy-workload.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: deploy-workload
  namespace: starfleet
spec:
  entrypoint: main
  serviceAccountName: deployment-writer
  arguments:
    parameters:
      - name: image
      - name: name
      - name: namespace
      - name: task
        value: release-check
  templates:
    - name: main
      steps:
        - - name: deploy
            template: deploy
            arguments:
              parameters:
                - name: image
                  value: "{{workflow.parameters.image}}"
                - name: name
                  value: "{{workflow.parameters.name}}"
                - name: namespace
                  value: "{{workflow.parameters.namespace}}"
                - name: task
                  value: "{{workflow.parameters.task}}"
    - name: deploy
      inputs:
        parameters:
          - name: image
          - name: name
          - name: namespace
          - name: task
      resource:
        action: create
        successCondition: status.availableReplicas > 0
        manifest: |
          apiVersion: apps/v1
          kind: Deployment
          metadata:
            name: "{{inputs.parameters.name}}"
            namespace: "{{inputs.parameters.namespace}}"
            annotations:
              training.astrona.io/workflow-uid: "{{workflow.uid}}"
          spec:
            replicas: 1
            selector:
              matchLabels:
                app: "{{inputs.parameters.name}}"
            template:
              metadata:
                labels:
                  app: "{{inputs.parameters.name}}"
              spec:
                containers:
                  - name: workload
                    image: "{{inputs.parameters.image}}"
                    env:
                      - name: PODINFO_UI_MESSAGE
                        value: "{{inputs.parameters.task}}"
                    ports:
                      - name: http
                        containerPort: 9898
                    readinessProbe:
                      httpGet:
                        path: /readyz
                        port: http
                    resources:
                      requests:
                        cpu: 10m
                        memory: 32Mi
```

Apply it:

```sh
kubectl apply -f workflowtemplate-deploy-workload.yaml
```

Submit two runs with different inputs:

```sh
export PATH="$HOME/.astrona/bin:$PATH"
argo submit -n starfleet --from workflowtemplate/deploy-workload \
  -p image=ghcr.io/stefanprodan/podinfo:6.15.0 \
  -p name=scout -p namespace=outpost -p task=release-check --wait

argo submit -n starfleet --from workflowtemplate/deploy-workload \
  -p image=ghcr.io/stefanprodan/podinfo:6.14.0 \
  -p name=probe -p namespace=starfleet -p task=preview-check --wait
```

Inspect the runs and their Deployments:

```sh
argo list -n starfleet
kubectl -n outpost rollout status deployment/scout --timeout=180s
kubectl -n starfleet rollout status deployment/probe --timeout=180s
kubectl -n outpost get deployment scout -o yaml
kubectl -n starfleet get deployment probe -o yaml
```

Use `argo get -n starfleet <workflow-name>` with a name from `argo list` to inspect a specific run. The workflow runs in `starfleet`; the `namespace` input controls where its Deployment is created. The Deployment remains after the workflow finishes. A second run with an existing Deployment name fails. Use a fresh name, or delete only the lab Deployment before repeating a run. Keep the successful runs and compare their UIDs with the Deployment annotations.
