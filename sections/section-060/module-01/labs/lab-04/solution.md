# Solution

A WorkflowTemplate is a stored workflow specification that you can run many times with different parameters. In this template the `main` step passes the four workflow parameters into the `deploy` template as `inputs.parameters`. The `deploy` template is a `resource` template: the Argo executor sends its manifest to the Kubernetes API instead of running a container. The manifest passes `msg` to the container as the environment variable `MSG`, and the shell command prints it with `echo "$MSG"`. An environment variable keeps a message with spaces or quotes in one piece.

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
      - name: msg
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
                - name: msg
                  value: "{{workflow.parameters.msg}}"
    - name: deploy
      inputs:
        parameters:
          - name: image
          - name: name
          - name: namespace
          - name: msg
      resource:
        action: create
        successCondition: status.availableReplicas > 0
        manifest: |
          apiVersion: apps/v1
          kind: Deployment
          metadata:
            name: "{{inputs.parameters.name}}"
            namespace: "{{inputs.parameters.namespace}}"
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
                      - name: MSG
                        value: "{{inputs.parameters.msg}}"
                    command:
                      - sh
                      - -c
                      - echo "$MSG"; while true; do sleep 3600; done
```

Apply it:

```sh
kubectl apply -f workflowtemplate-deploy-workload.yaml
```

Run `astrona submit` now. The `workflow-template` check passes; the other two fail because no workflow has run yet.

Each `-p` flag sets one workflow parameter. `--from workflowtemplate/deploy-workload` creates a Workflow from the stored template, and `--wait` keeps the command running until the workflow finishes:

```sh
export PATH="$HOME/.astrona/bin:$PATH"
argo submit -n starfleet --from workflowtemplate/deploy-workload \
  -p image=alpine:3.23 -p name=scout -p namespace=outpost \
  -p msg="scout is running" --wait
```

The workflow runs in `starfleet`. The `namespace` parameter only decides where the Deployment goes, here `outpost`. The `successCondition` keeps the resource step running until the Deployment has an available replica, so `Succeeded` means the pod runs.

Then check the result:

```sh
argo list -n starfleet
kubectl -n outpost get deployment scout -o wide
kubectl -n outpost logs deploy/scout
```

`argo list` shows the workflow with status `Succeeded`. The Deployment shows `1/1` ready and image `alpine:3.23`, and its log prints `scout is running`. Use `argo get -n starfleet <workflow-name>` to see the parameters and the resource node of the run.

A second run with a name that already exists fails, because action `create` refuses an existing object. Use a new name, or delete only that Deployment, before you run it again.

Run `astrona submit`. All three checks pass.
