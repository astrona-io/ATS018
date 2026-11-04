# Solution Walkthrough

You will read a failed run with the `argo` command-line tool, fix its WorkflowTemplate, run a step twice in parallel, start a second template with the right parameter and ServiceAccount, and remove the runs you no longer need.

| Goal | Object | Command or field |
| --- | --- | --- |
| Find the cause | The failed Workflow | `argo list`, `argo get`, `argo logs` |
| Fix the file name | WorkflowTemplate `scout-check` | `container.args` of `check-version`, `argo template update` |
| Run two steps together | WorkflowTemplate `scout-check` | The second group of `steps` in `main` |
| Create the settings | WorkflowTemplate `outpost-config` | `argo submit --from`, `-p`, `--serviceaccount` |
| Keep one success per template | Workflows in `starfleet` | `argo delete` |

## The feedback loop

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-040/module-03/labs/lab-02
```

The five checks are `template-fixed`, `parallel-steps`, `scout-check-run`, `outpost-run` and `one-success-each`. None passes in the untouched environment. Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Find the cause

Make sure your shell finds the tool, then read the failed run:

```sh
export PATH="$HOME/.astrona/bin:$PATH"
argo list -n starfleet
argo get -n starfleet @latest
argo logs -n starfleet @latest
```

`argo list` shows one Workflow with `Failed` in the `STATUS` column. `argo get` prints its `Status` and `Message` and a tree of its steps: `prepare` passed and `check-version` failed. `argo logs` shows that `grep` could not open `/release/VERSIONS`.

The file comes from a ConfigMap volume, and each key of the ConfigMap becomes one file. List the keys:

```sh
kubectl -n starfleet get configmap scout-release -o jsonpath='{.data}'
```

The key is `VERSION`, so the template reads a file that does not exist.

## Fix the template and copy the step

Save the current template to a file:

```sh
argo template get -n starfleet scout-check -o yaml > scout-check.yaml
```

Open `scout-check.yaml`. Change `/release/VERSIONS` to `/release/VERSION` in the `check-version` template. Then add the copy to the second group of the `steps` list in `main`, so that it reads:

```yaml
steps:
  - - name: prepare
      template: prepare
  - - name: check-version
      template: check-version
    - name: check-version-copy
      template: check-version
```

A line that starts with `- -` opens a new group, and a group starts only after the group before it ends. A line that starts with a single `-` at the inner indentation joins the current group, and all steps in a group start together. A DAG has no groups. Each task in a DAG lists the tasks it waits for in `depends`, so you would write `depends: prepare` on both tasks to get the same order.

Send the change to the cluster and read it back:

```sh
argo template update scout-check.yaml
argo template get -n starfleet scout-check
```

The checks `template-fixed` and `parallel-steps` turn green.

## Run the check

A fix to a template does not repair the run that already failed, so start a new one. `--wait` holds the command until the run ends:

```sh
argo submit -n starfleet --from workflowtemplate/scout-check --wait
argo get -n starfleet @latest
```

`argo get` shows `Succeeded` and both steps, each with its own pod. The check `scout-check-run` turns green.

## Create the settings

Start `outpost-config`. The parameter chooses the namespace, and the flag chooses the account for all pods of this run:

```sh
argo submit -n starfleet --from workflowtemplate/outpost-config -p target-namespace=outpost --serviceaccount outpost-provisioner --wait
argo get -n starfleet @latest
kubectl -n outpost get configmap scout-settings --show-labels
kubectl -n outpost get serviceaccount scout --show-labels
```

`argo get` shows `outpost-provisioner` on its `ServiceAccount` line and `Succeeded` as its status. The label `created-by-workflow` on both objects holds the name of this run. The check `outpost-run` turns green.

## Clean up

List what is there, preview the delete, then run it. The label selects the runs of one template, and `--status` selects the runs that did not succeed:

```sh
argo list -n starfleet
argo delete -n starfleet -l workflows.argoproj.io/workflow-template=scout-check --status Failed,Error --dry-run
argo delete -n starfleet -l workflows.argoproj.io/workflow-template=scout-check --status Failed,Error
argo list -n starfleet
```

If you started a run more than once, delete each extra run by its name with `argo delete -n starfleet <name>`, and keep the newest success of each template. Deleting a run does not delete the ConfigMap or the ServiceAccount it created in `outpost`, because they have no owner reference. The check `one-success-each` turns green.

## Submit

When all five checks are green, stop the watch with Ctrl-C and record the attempt once:

```sh
astrona submit --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-040/module-03/labs/lab-02
```

## If a check stays red

- **`template-fixed`:** Read the template with `argo template get -n starfleet scout-check -o yaml`. Keep `grep`, the `expected-version` parameter and the volume, and change only the path.
- **`parallel-steps`:** Check the indentation. The copy must start with a single `-` under `check-version`, not with `- -`, or it becomes a third group.
- **`scout-check-run`:** A run keeps the template it started with. Start a new run after you change the template, and do not delete that run.
- **`outpost-run`:** Read the run with `argo get` and its pod log with `argo logs`. Without `-p` the run writes to `starfleet`, where `outpost-provisioner` has no rights. Without `--serviceaccount` the pods use `default`, which has no rights either. Start a new run with both. The newest successful run must be the one you keep, because it wrote the label.
- **`one-success-each`:** The message counts the Workflows of each template. Delete the extra runs by name with `argo delete`.
