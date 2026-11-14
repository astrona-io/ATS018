# Solution Walkthrough

You will read a failed run with `tkn`, add a Task that runs in parallel with another, extend a ClusterRole, start the Pipeline twice with different values, save one log to a file, and delete the failed run.

| Goal | Object | Command or field |
| --- | --- | --- |
| Find the cause | The failed PipelineRun | `tkn pipelinerun describe`, `tkn pipelinerun logs` |
| Run two Tasks together | Pipeline `outpost-onboard` | The same `runAfter` on both Tasks |
| Pass the values | Pipeline `outpost-onboard` | `$(tasks.plan-namespace.results.namespace)`, `$(params.tier)` |
| Allow the label | ClusterRole `namespace-provisioner` | The verb `patch` on `namespaces` |
| Start two runs | PipelineRuns | `tkn pipeline start`, `-p`, `-s` |
| Save a log | `/tmp/outpost-rigel-run.log` | `tkn pipelinerun logs` with a redirect |
| Remove the failure | PipelineRun `outpost-onboard-first-try` | `tkn pipelinerun delete` |

## The feedback loop

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-050/module-01/labs/lab-02
```

The five checks are `pipeline-task`, `rbac`, `site-runs`, `saved-log` and `failed-run-deleted`. None passes in the untouched environment. Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Find the cause

Make sure your shell finds the tool, then read the failed run:

```sh
export PATH="$HOME/.astrona/bin:$PATH"
tkn -n starfleet pipelinerun list
tkn -n starfleet pipelinerun describe outpost-onboard-first-try
tkn -n starfleet pipelinerun logs outpost-onboard-first-try
```

`tkn pipelinerun list` shows `outpost-onboard-first-try` with a failed status. `describe` shows the `Service Account` line with the value `default`, and the TaskRun table shows that `create-namespace` failed. The log lines of `[create-namespace : create]` hold a `Forbidden` error from the Kubernetes API server. The error names the account `default` and the verb it was not allowed to use.

The pods ran as `default` because the run named no ServiceAccount. So the fix for this failure is to start the new runs with `outpost-provisioner`.

## Add the Task

Two Tasks run in parallel when neither waits for the other. `report-namespace` waits only for `create-namespace`, so give `label-namespace` the same `runAfter`. A result reference to `plan-namespace` adds no other wait, because `create-namespace` already runs after it.

Save this as `pipeline-outpost-onboard.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: outpost-onboard
  namespace: starfleet
spec:
  params:
    - name: site
      type: string
    - name: tier
      type: string
  tasks:
    - name: plan-namespace
      taskRef:
        name: plan-namespace
      params:
        - name: site
          value: $(params.site)
    - name: create-namespace
      runAfter:
        - plan-namespace
      taskRef:
        name: create-namespace
      params:
        - name: namespace
          value: $(tasks.plan-namespace.results.namespace)
    - name: report-namespace
      runAfter:
        - create-namespace
      taskRef:
        name: report-namespace
      params:
        - name: namespace
          value: $(tasks.plan-namespace.results.namespace)
    - name: label-namespace
      runAfter:
        - create-namespace
      taskRef:
        name: label-namespace
      params:
        - name: namespace
          value: $(tasks.plan-namespace.results.namespace)
        - name: tier
          value: $(params.tier)
```

Apply it:

```sh
kubectl apply -f pipeline-outpost-onboard.yaml
```

The check `pipeline-task` turns green.

## Fix the rights

Read what the account may do now:

```sh
kubectl get clusterrole namespace-provisioner -o yaml
```

The rule allows `get` and `create` on `namespaces`. The Task `label-namespace` runs `kubectl label`, which sends a `patch` request to the API server. So that verb is missing.

Save this as `clusterrole-namespace-provisioner.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: namespace-provisioner
rules:
  - apiGroups: [""]
    resources: ["namespaces"]
    verbs: ["get", "create", "patch"]
```

Apply it:

```sh
kubectl apply -f clusterrole-namespace-provisioner.yaml
```

Then check the result. The command prints `yes` for an allowed request and `no` for a refused one:

```sh
kubectl auth can-i patch namespaces --as=system:serviceaccount:starfleet:outpost-provisioner
kubectl auth can-i delete namespaces --as=system:serviceaccount:starfleet:outpost-provisioner
```

The first command prints `yes` and the second prints `no`. The check `rbac` turns green.

## Run the Pipeline for two sites

Each `-p` sets one Pipeline param, and `-s` sets the ServiceAccount for all pods of the run. `--showlog` prints the log lines until the run ends:

```sh
tkn -n starfleet pipeline start outpost-onboard -p site=vega -p tier=gold -s outpost-provisioner --showlog
tkn -n starfleet pipeline start outpost-onboard -p site=rigel -p tier=silver -s outpost-provisioner --showlog
```

Now read the runs and the namespaces:

```sh
tkn -n starfleet pipelinerun list
kubectl get namespaces outpost-vega outpost-rigel --show-labels
```

Both new runs show `Succeeded`. Each namespace has its `tier` label, and a label `onboarded-by` with the name of the TaskRun that wrote it. The check `site-runs` turns green.

## Save the log

Find the name of the `rigel` run. It is the newest run, so `--last` selects it. The redirect sends the output to the file:

```sh
tkn -n starfleet pipelinerun logs --last > /tmp/outpost-rigel-run.log
grep 'namespace :' /tmp/outpost-rigel-run.log
```

Each line starts with `[<task> : <step>]`. Look for lines from `label-namespace` and from `report-namespace` that name `outpost-rigel`. The check `saved-log` turns green.

## Delete the failed run

`-f` skips the question that `tkn` otherwise asks before it deletes:

```sh
tkn -n starfleet pipelinerun delete outpost-onboard-first-try -f
tkn -n starfleet pipelinerun list
```

Only the two `Succeeded` runs remain. The check `failed-run-deleted` turns green.

## Submit

When all five checks are green, stop the watch with Ctrl-C and record the attempt once:

```sh
astrona submit --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-050/module-01/labs/lab-02
```

## If a check stays red

- **`pipeline-task`:** Read the Pipeline with `tkn -n starfleet pipeline describe outpost-onboard`. Both `label-namespace` and `report-namespace` must list only `create-namespace` in `runAfter`.
- **`rbac`:** Add only the missing verb on `namespaces`. Do not bind the account to `cluster-admin`, and do not add `delete`.
- **`site-runs`:** A run keeps the Pipeline it started with. If you changed the Pipeline after a run started, start a new run. If `label-namespace` failed, fix the ClusterRole first, then start a new run with the same values. The namespace must carry the label from a run that you keep.
- **`saved-log`:** Save the log after the run has ended, and do not use `--prefix=false`. If you started the `rigel` run again, or if `vega` ran last, save the log by run name: `tkn -n starfleet pipelinerun logs <name> > /tmp/outpost-rigel-run.log`.
- **`failed-run-deleted`:** A run that failed while you worked also counts. Delete each failed run by its name, and keep the `Succeeded` ones.
