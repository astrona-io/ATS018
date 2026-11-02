# Solution

## Step 1: push a commit and read the first symptom

Clone the repository, change `VERSION` and push to `main`:

```sh
git clone http://platform:starfleet-gitops@127.0.0.1:3000/starfleet/scout-app.git
cd scout-app
echo 6.15.1 > VERSION
git commit -am "Bump VERSION to 6.15.1"
git push origin main
```

After about 20 seconds, list the Workflows:

```sh
kubectl -n starfleet get workflows
```

```text
No resources found in starfleet namespace.
```

Nothing started. The Sensor decides whether an event starts a Workflow, so read its log:

```sh
kubectl -n argo-events logs -l sensor-name=push-ci --tail=3
```

The last line says `not interested in dependency push-main (didn't pass filter)`. Read the filter:

```sh
kubectl -n argo-events get sensor push-ci -o jsonpath='{.spec.dependencies[0].filters.data[0].value[0]}{"\n"}'
```

The filter accepts `refs/heads/master`. The branch is `main`, so the Sensor drops every push.

## Step 2: fix the branch filter

Patch the value, then wait for the Sensor pod to restart:

```sh
kubectl -n argo-events patch sensor push-ci --type=json \
  -p '[{"op":"replace","path":"/spec/dependencies/0/filters/data/0/value/0","value":"refs/heads/main"}]'
kubectl -n argo-events rollout status deploy -l sensor-name=push-ci --timeout=120s
```

Push a second commit, wait about 40 seconds and list the Workflows with the revision each one received:

```sh
echo 6.15.2 > VERSION
git commit -am "Bump VERSION to 6.15.2"
git push origin main
git rev-parse HEAD
kubectl -n starfleet get workflows -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,MSG:.status.message,REV:.spec.arguments.parameters[0].value'
```

A Workflow exists now, and it is `Failed` with `main: Error (exit code 2)`. Its revision is not the ID that `git rev-parse HEAD` printed. It is the ID of the first commit you pushed. Two faults show here.

## Step 3: fix the commit field

A Gitea push event holds two commit IDs. `body.before` is the head of the branch before the push, and `body.after` is the head after it. The trigger copies `body.before`, so each Workflow tests the previous commit. Replace it with `body.after`:

```sh
kubectl -n argo-events patch sensor push-ci --type=json \
  -p '[{"op":"replace","path":"/spec/triggers/0/template/argoWorkflow/parameters/0/src/dataKey","value":"body.after"}]'
```

## Step 4: fix the working directory

Read the log of the failed pod. Replace `<workflow-name>` with the name from the list:

```sh
kubectl -n starfleet logs -l workflows.argoproj.io/workflow=<workflow-name> -c main --prefix | grep -v INFO
```

The log says `/bin/sh: can't open 'test.sh': No such file or directory`. The template clones the repository to `/src`, but the container starts in `/wrong`. Patch the template:

```sh
kubectl -n starfleet patch workflowtemplate run-tests --type=json \
  -p '[{"op":"replace","path":"/spec/templates/0/container/workingDir","value":"/src"}]'
kubectl -n argo-events rollout status deploy -l sensor-name=push-ci --timeout=120s
```

Push a third commit and list the Workflows again after about 60 seconds:

```sh
echo 6.15.3 > VERSION
git commit -am "Bump VERSION to 6.15.3"
git push origin main
kubectl -n starfleet get workflows -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,MSG:.status.message,REV:.spec.arguments.parameters[0].value'
```

The newest Workflow now has the right revision, but its phase is `Error`:

```text
wait: Error (exit code 64): workflowtaskresults.argoproj.io is forbidden: User "system:serviceaccount:starfleet:workflow-runner" cannot create resource "workflowtaskresults" in API group "argoproj.io" in the namespace "starfleet"
```

## Step 5: bind the Role

The test itself ran. The `wait` container, which reports the result of each step to the workflow controller, is denied. It writes the result into a `workflowtaskresults` object, as the service account `workflow-runner`. The Role `workflow-executor` already allows that, but no RoleBinding connects it to the account. Save this as `rolebinding-workflow-executor.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: workflow-executor
  namespace: starfleet
subjects:
  - kind: ServiceAccount
    name: workflow-runner
    namespace: starfleet
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: workflow-executor
```

Apply it:

```sh
kubectl apply -f rolebinding-workflow-executor.yaml
```

Then check the permission:

```sh
kubectl auth can-i create workflowtaskresults.argoproj.io -n starfleet --as=system:serviceaccount:starfleet:workflow-runner
```

The answer is `yes`. Do not bind `cluster-admin` or add `*` rules; the grader rejects wide rights.

## Step 6: push the final commit and submit

Argo Workflows does not retry a finished Workflow, so push one more commit:

```sh
echo 6.15.4 > VERSION
git commit -am "Bump VERSION to 6.15.4"
git push origin main
git rev-parse HEAD
kubectl -n starfleet get workflows -l events.argoproj.io/sensor=push-ci \
  -o jsonpath='{range .items[*]}{.metadata.name}{"  "}{.status.phase}{"  "}{.spec.arguments.parameters[0].value}{"\n"}{end}'
```

The newest Workflow is `Succeeded`, and its revision is the commit ID that `git rev-parse HEAD` printed. Then submit:

```sh
astrona submit
```

The first check reads the WorkflowTemplate. The second reads the Sensor, its filter, its commit field and the pods. The third asks the Kubernetes API whether `workflow-runner` can write `workflowtaskresults` and nothing broader. The fourth compares the newest commit on `main` with the revision of a `Succeeded` Workflow that carries the label of the Sensor `push-ci`.
