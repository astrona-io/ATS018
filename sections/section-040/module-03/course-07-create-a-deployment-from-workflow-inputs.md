# Create A Deployment From Workflow Inputs

A release workflow can create a Kubernetes Deployment directly. A resource template sends a manifest to the Kubernetes API and can wait for its status. A WorkflowTemplate stores that procedure so each run can supply a different image, workload name, destination namespace and workload purpose.

The workflow itself runs in `starfleet`. Its `namespace` parameter selects the Deployment's namespace. Those are separate choices: a parameter does not move the workflow or give its ServiceAccount more permissions. Here `task` describes the workload purpose. The example application returns it as its message through `PODINFO_UI_MESSAGE`. The resource action stays `create`; its API schema requires a literal operation.

## Give the workflow permission

The resource executor needs permission to manage Deployments in each destination. It also needs `create` and `patch` on WorkflowTaskResults in the workflow namespace to report its result. Use a namespaced Role and RoleBinding for each destination instead of granting cluster administrator access. Create the destination namespace if it is not already present.

<!-- astrona:playground:renew -->

Save this as `deployment-writer-rbac.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: deployment-writer
  namespace: starfleet
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: deployment-writer
  namespace: starfleet
rules:
- apiGroups:
  - apps
  resources:
  - deployments
  verbs:
  - get
  - list
  - watch
  - create
  - patch
  - update
- apiGroups:
  - argoproj.io
  resources:
  - workflowtaskresults
  verbs:
  - create
  - patch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: deployment-writer
  namespace: starfleet
subjects:
- kind: ServiceAccount
  name: deployment-writer
  namespace: starfleet
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: deployment-writer
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: deployment-writer
  namespace: outpost
rules:
- apiGroups:
  - apps
  resources:
  - deployments
  verbs:
  - get
  - list
  - watch
  - create
  - patch
  - update
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: deployment-writer
  namespace: outpost
subjects:
- kind: ServiceAccount
  name: deployment-writer
  namespace: starfleet
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: deployment-writer
```

Apply it:

```sh
kubectl create namespace outpost --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f deployment-writer-rbac.yaml
```

## Pass arguments into the resource template

`spec.arguments.parameters` declares values supplied to the workflow. The step's `arguments` passes those values into `deploy`, whose `inputs.parameters` declares its local inputs. The manifest substitutes those local values into the Deployment. Matching selector and pod labels are essential: the Deployment uses them to find its pods.

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

The `successCondition` keeps the resource step running until at least one replica is available. The readiness probe tests `/readyz` on the podinfo container. Accepting a Deployment manifest alone would not show that its pods can serve requests. The annotation records the workflow's UID, its unique identifier, so a later inspection can connect the Deployment to this run.

## Submit a run with concrete inputs

The Argo command-line interface uses `--from workflowtemplate/deploy-workload` to select the stored template. Each `-p` supplies one parameter; `--wait` waits for the workflow to finish. All values below are valid for this environment:

```sh
export PATH="$HOME/.astrona/bin:$PATH"
argo submit -n starfleet --from workflowtemplate/deploy-workload \
  -p image=ghcr.io/stefanprodan/podinfo:6.15.0 \
  -p name=workflow-scout -p namespace=outpost -p task=release-check --wait

argo submit -n starfleet --from workflowtemplate/deploy-workload \
  -p image=ghcr.io/stefanprodan/podinfo:6.14.0 \
  -p name=workflow-probe -p namespace=starfleet -p task=preview-check --wait
```

`create` requires an unused Deployment name. The `task` value changes the application message, not the Kubernetes operation or permissions. These names keep the example separate from other playground workloads. For another attempt, use a fresh name or delete only these example Deployments first.

Inspect the run list and the Deployments:

```sh
argo list -n starfleet
kubectl -n outpost rollout status deployment/workflow-scout --timeout=180s
kubectl -n starfleet rollout status deployment/workflow-probe --timeout=180s
kubectl -n outpost get deployment workflow-scout -o yaml
```

Use `argo get -n starfleet <workflow-name>` with a name from the list to read that run's node tree. Check its arguments and successful resource node, then compare its UID with the Deployment annotation. The annotation records an association; it is not an owner reference and does not arrange deletion. The Deployments keep running after the workflows finish.

## Common pitfalls

> [!WARNING]
> - A namespace input selects the destination of the manifest, while `argo submit -n` selects the workflow namespace.
> - Declaring an input does not pass a value to it. Keep the step's argument mapping and the resource template's inputs aligned.
> - A repeated `create` fails when the Deployment already exists. Use a new name for another run; changing `task` does not change the resource action.
> - A workflow can fail with Forbidden even when your own kubectl command works. The executor uses `deployment-writer`, not your user permissions.
> - Keep the Deployment selector and pod labels equal. Changing an existing Deployment selector is not a valid update.
