# Run Workflows With The argo Command-Line Tool

Reading a Workflow with `kubectl` works, but it takes long `jsonpath` expressions and a label selector for every log. Starting a run from a template takes a small file each time. The `argo` command-line tool does these jobs in one short command, so a failed run is a matter of three commands, and a new run needs no file. This part starts, reads, repairs and cleans up runs with `argo`.

## What the tool talks to

`argo` reads your kubeconfig and talks to the Kubernetes API, as `kubectl` does. It does not need the Argo Workflows web server, which this playground does not have. So it has the same permissions as your `kubectl`, and the `-n` flag chooses the namespace. Without `-n` it uses the namespace of your current kubeconfig context, so always pass `-n starfleet` here.

The playground installs `argo` v4.1.6 in `~/.astrona/bin`, unless you already had an `argo`.

<!-- astrona:playground:renew -->

Put the tool on your `PATH`, check the version, and list the templates and the runs:

```sh
export PATH="$HOME/.astrona/bin:$PATH"
argo version --short
argo template list -n starfleet
argo list -n starfleet
```

`argo template list` shows the WorkflowTemplates in the namespace. `argo list` has a `STATUS` column with the phase of each run, and a new playground has no runs in it.

## Read why a run failed

This WorkflowTemplate checks a value in the operating system file of its container. It runs two steps in order, and the second one has a wrong file name in it. Save this as `workflowtemplate-probe-check.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: probe-check
  namespace: starfleet
spec:
  entrypoint: main
  serviceAccountName: workflow-runner
  arguments:
    parameters:
      - name: distro
        value: alpine
  templates:
    - name: main
      steps:
        - - name: prepare
            template: prepare
        - - name: check-distro
            template: check-distro
    - name: prepare
      container:
        image: alpine:3.23
        command: [echo, preparing the check]
    - name: check-distro
      container:
        image: alpine:3.23
        command: [sh, -c]
        args:
          - grep -Fqx "ID={{workflow.parameters.distro}}" /etc/os-releases
```

Apply it with `argo template create`, and read it back:

```sh
argo template create workflowtemplate-probe-check.yaml
argo template get -n starfleet probe-check
```

Start a run from the template. `--from` names the template, and `-p` sets a parameter for this run. Then read the run with the three commands that answer every failure. `@latest` stands for the newest run in the namespace:

```sh
argo submit -n starfleet --from workflowtemplate/probe-check -p distro=alpine --wait
argo list -n starfleet
argo get -n starfleet @latest
argo logs -n starfleet @latest
```

`--wait` holds the command until the run ends. `argo list` shows `Failed` for the run. `argo get` prints the `Status` and the `Message` of the run, then a tree of its steps with a pod and a message for each one: `prepare` passed and `check-distro` failed. `argo logs` prints the logs of the pods of the run, and the `grep` line says that it cannot open `/etc/os-releases`.

The file name in the template is wrong, so the repair belongs in the template. Change `/etc/os-releases` to `/etc/os-release` in your file. Then update the template and start a new run:

```sh
argo template update workflowtemplate-probe-check.yaml
argo submit -n starfleet --from workflowtemplate/probe-check -p distro=alpine --wait
argo list -n starfleet
```

The list now has a `Failed` run and a `Succeeded` run. The failed run stays failed, because a run keeps the template it started with.

## Run two steps at the same time

Each entry of a `steps` list is a group. A line that starts with `- -` opens a new group, and a group starts only after the group before it ends. A step at the inner indentation with a single `-` joins the current group, and all steps of one group start together.

To run a copy of `check-distro` at the same time as the original, change the `steps` list of `main` in your file so that it reads:

```yaml
steps:
  - - name: prepare
      template: prepare
  - - name: check-distro
      template: check-distro
    - name: check-distro-copy
      template: check-distro
```

Update the template, start a run and read it:

```sh
argo template update workflowtemplate-probe-check.yaml
argo submit -n starfleet --from workflowtemplate/probe-check -p distro=alpine --wait
argo get -n starfleet @latest
```

`argo get` lists both steps, each with its own pod, and neither of them starts before `prepare` ends.

A DAG (directed acyclic graph) gives the same order in another way. It has no groups. Each task lists what it waits for, so the same graph looks like this:

```yaml
dag:
  tasks:
    - name: prepare
      template: prepare
    - name: check-distro
      template: check-distro
      depends: prepare
    - name: check-distro-copy
      template: check-distro
      depends: prepare
```

Use `steps` when the job is a simple line of stages. Use a DAG when the waiting is uneven, for example when a task must wait for one branch but not for another. In `steps` that task has to wait for its whole group.

## Create objects in the namespace of a parameter

A template can also create Kubernetes objects. A `resource` template holds a manifest and applies it, and a parameter can choose where it goes. The pod does this with its own ServiceAccount, so that account needs the rights in the target namespace, and the executor rights in the namespace of the run.

First create the namespace and the account. Save this as `outpost-writer.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: outpost
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: outpost-writer
  namespace: starfleet
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: outpost-writer-executor
  namespace: starfleet
subjects:
  - kind: ServiceAccount
    name: outpost-writer
    namespace: starfleet
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: workflow-executor
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: settings-writer
  namespace: outpost
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "create", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: outpost-writer
  namespace: outpost
subjects:
  - kind: ServiceAccount
    name: outpost-writer
    namespace: starfleet
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: settings-writer
```

Apply it:

```sh
kubectl apply -f outpost-writer.yaml
```

Now the template. It names no ServiceAccount, so each run chooses one. Save this as `workflowtemplate-probe-settings.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: probe-settings
  namespace: starfleet
spec:
  entrypoint: settings
  arguments:
    parameters:
      - name: target-namespace
        value: starfleet
  templates:
    - name: settings
      resource:
        action: apply
        manifest: |
          apiVersion: v1
          kind: ConfigMap
          metadata:
            name: probe-settings
            namespace: "{{workflow.parameters.target-namespace}}"
          data:
            LOG_LEVEL: info
```

Keep the quotes around the parameter in the manifest. Create the template, start a run with the namespace and the account, and check the result:

```sh
argo template create workflowtemplate-probe-settings.yaml
argo submit -n starfleet --from workflowtemplate/probe-settings -p target-namespace=outpost --serviceaccount outpost-writer --wait
argo get -n starfleet @latest
kubectl -n outpost get configmap probe-settings
```

The `ServiceAccount` line of `argo get` names `outpost-writer`, and the ConfigMap exists in `outpost`. The flag `--serviceaccount` applies to this run only.

## Clean up the runs

Old runs and their pods stay until you delete them. Every run started with `--from` has the label `workflows.argoproj.io/workflow-template` with the name of its template, so you can select the runs of one template. `--status` selects by phase, and `--dry-run` prints what would go without deleting it. Delete the failed runs of `probe-check`:

```sh
argo list -n starfleet -l workflows.argoproj.io/workflow-template=probe-check
argo delete -n starfleet -l workflows.argoproj.io/workflow-template=probe-check --status Failed,Error --dry-run
argo delete -n starfleet -l workflows.argoproj.io/workflow-template=probe-check --status Failed,Error
```

This leaves two successful runs of `probe-check`. To keep only the newest one, take the name of the older one from the list and delete it with `argo delete -n starfleet <name>`. The ConfigMap in `outpost` stays, because deleting a run removes the run and its pods and nothing else that it created.

You can now start a run from a template with `argo`, read why it failed, repair the template, run steps in parallel, send a run to another namespace with the right account, and clear away what you no longer need.

## Common pitfalls

> [!WARNING]
> - **Forgetting `-n`.** `argo` uses the namespace of your kubeconfig context, so an empty list may only mean the wrong namespace.
> - **Repeating `- -` for a parallel step.** Each `- -` opens a new group, so the step then runs after the group before it instead of with it.
> - **Forgetting `-p` on a run that writes objects.** The run then uses the default value of the parameter, and its account may have no rights in that namespace.
> - **Giving rights in one namespace only.** The account needs the rights on the objects in the target namespace, and the rights on `workflowtaskresults` in the namespace of the run.
> - **Setting `setOwnerReference` on a resource in another namespace.** Kubernetes does not allow an owner in another namespace. Leave the field out.
> - **Expecting a fixed template to repair a run.** Start a new run with `argo submit`.
> - **Using `argo delete --all` to clean up.** It also deletes the successful runs. Select with `-l` and `--status`, and check with `--dry-run` first.

## Your mission: Run And Repair Workflows With The argo Command-Line Tool

You can now do the whole loop with `argo`. The mission starts from a failed run of another template. You find the cause, fix the template, run a copied step in parallel, create settings in `outpost` with the right account, and keep one successful run for each template.

Pause the playground, then start the lab and read the task:

```sh
astrona stop ats-018-playground-040-03
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-040/module-03/labs/lab-02
```

Check your progress with `--watch` while you work, because a plain `astrona submit` finishes the attempt and deletes the lab. Stop the watch with Ctrl-C and submit once at the end. Then remove the lab and start the playground again:

```sh
astrona submit --watch --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-040/module-03/labs/lab-02
astrona submit --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-040/module-03/labs/lab-02
astrona destroy ats-018-lab-040-03-02
astrona start ats-018-playground-040-03
```

## Your mission: Insert A Step Between Two Existing Steps

You can now read a template, change it with `argo template update` and read a run. The mission gives you a template that hands a manifest from one step to the next. You add a template that hashes the manifest, insert it as its own group between the two steps, run the changed template, read the digest with `argo logs` and remove the run from before the change.

Pause the playground, then start the lab and read the task:

```sh
astrona stop ats-018-playground-040-03
astrona run --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-040/module-03/labs/lab-03
```

Use `--watch` while you work, submit once at the end, then remove the lab and start the playground again:

```sh
astrona submit --watch --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-040/module-03/labs/lab-03
astrona submit --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-040/module-03/labs/lab-03
astrona destroy ats-018-lab-040-03-03
astrona start ats-018-playground-040-03
```
