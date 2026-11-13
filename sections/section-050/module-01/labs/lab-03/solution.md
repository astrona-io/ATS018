# Solution

Inspect the Pipeline and a failed run with `kubectl -n starfleet get pipelineruns` and `kubectl -n starfleet get pipelinerun <name> -o yaml`. The resolver error occurs before a Task pod can run.

Save the repaired Pipeline as `pipeline-scout-ci.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: scout-ci
  namespace: starfleet
spec:
  params:
  - name: repo-url
    type: string
    default: http://gitea-http.gitea.svc:3000/starfleet/scout-app.git
  workspaces:
  - name: shared
  tasks:
  - name: fetch-source
    taskRef:
      resolver: cluster
      params:
      - name: kind
        value: task
      - name: name
        value: fetch-source
      - name: namespace
        value: tekton-tasks
    params:
    - name: url
      value: $(params.repo-url)
    workspaces:
    - name: source
      workspace: shared
  - name: run-tests
    runAfter:
    - fetch-source
    taskRef:
      resolver: git
      params:
      - name: url
        value: http://gitea-http.gitea.svc:3000/starfleet/scout-app.git
      - name: revision
        value: main
      - name: pathInRepo
        value: tekton/run-tests.yaml
    workspaces:
    - name: source
      workspace: shared
  results:
  - name: version
    value: $(tasks.run-tests.results.version)
  - name: commit
    value: $(tasks.fetch-source.results.commit)
```

Apply it:

```sh
kubectl apply -f pipeline-scout-ci.yaml
```

Save this as `pipelinerun-scout-ci.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: scout-resolvers-
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

Create a fresh run and wait for it:

```sh
RUN=$(kubectl create -f pipelinerun-scout-ci.yaml -o name)
kubectl -n starfleet wait "$RUN" --for=condition=Succeeded --timeout=240s
kubectl -n starfleet get "$RUN" -o yaml
kubectl -n starfleet get taskruns
```

For the test TaskRun belonging to that PipelineRun, read its `status.provenance.refSource` with `kubectl -n starfleet get taskrun <name> -o yaml`. Compare its Git digest with the PipelineRun's `commit` result. The test Task and the tested source must come from the same commit.
