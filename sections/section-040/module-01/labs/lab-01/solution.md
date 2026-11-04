# Solution

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Step 1: start the Pipeline

The Pipeline `scout-ci` declares one workspace, `shared`. A `PipelineRun` must bind it. A `volumeClaimTemplate` makes Tekton create a PersistentVolumeClaim for the run.

Save this as `pipelinerun-scout-ci.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: scout-ci-
  namespace: starfleet
spec:
  pipelineRef:
    name: scout-ci
  workspaces:
    - name: shared
      volumeClaimTemplate:
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 100Mi
```

The file uses `generateName`, so you start it with `create`, not `apply`:

```sh
kubectl create -f pipelinerun-scout-ci.yaml
```

## Step 2: read the failure

Wait about 30 seconds. Then describe the newest PipelineRun:

```sh
tkn -n starfleet pipelinerun describe --last
```

The PipelineRun is `Failed`. The TaskRun `fetch-source` is `Succeeded` and the TaskRun `run-tests` is `Failed(StepFailed)`. Read the log of the failed TaskRun. Replace `<run-name>` with the name of your PipelineRun:

```sh
tkn -n starfleet taskrun logs <run-name>-run-tests
```

The step log says `sh: can't open 'test.sh': No such file or directory`. The step started in a folder without `test.sh`. Compare the folder of the step with the place where the workspace is mounted:

```sh
kubectl -n starfleet get task run-tests -o jsonpath='{.spec.steps[0].workingDir}{"\n"}'
```

The step has `workingDir: /workspace/wrong`. The workspace `source` is mounted at `/workspace/source`, and that is where `fetch-source` cloned the repository.

## Step 3: fix the Task

Point `workingDir` at the workspace with the Tekton variable. Save this as `task-run-tests.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: run-tests
  namespace: starfleet
spec:
  params:
    - name: version
      type: string
      default: 6.15.0
  workspaces:
    - name: source
  results:
    - name: version
      description: The tested application version
  steps:
    - name: test
      image: alpine:3.23
      workingDir: $(workspaces.source.path)
      env:
        - name: SCOUT_VERSION
          value: $(params.version)
      script: |
        #!/bin/sh
        set -eu
        sh test.sh
        printf '%s' "$SCOUT_VERSION" > "$(results.version.path)"
```

Apply it:

```sh
kubectl apply -f task-run-tests.yaml
```

A finished run never changes, so the old run stays `Failed`.

## Step 4: run the Pipeline again

Start a new run from the same file:

```sh
kubectl create -f pipelinerun-scout-ci.yaml
```

Then check the result after about 30 seconds:

```sh
tkn -n starfleet pipelinerun list
kubectl -n starfleet get pipelinerun -o jsonpath='{range .items[*]}{.metadata.name}{"  "}{.status.results[0].value}{"\n"}{end}'
```

The new run is `Succeeded`, and its `version` result is `6.15.0`. The old run is still listed as `Failed`.

## Step 5: submit

Stop the watch with Ctrl-C, then run the plain command once:

```sh
astrona submit
```

The first check reads the Task and the Pipeline. The second check looks for a `Succeeded` PipelineRun of `scout-ci` whose `run-tests` TaskRun started in the workspace and whose result `version` is `6.15.0`.
