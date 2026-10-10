# Shared Tasks With Resolvers

A platform team writes a Task such as "clone a repository" once, and many teams use it. If every team copies the YAML into its own namespace, a fix reaches nobody until each copy is changed by hand. Tekton avoids copies with resolvers. This part loads one Task from another namespace and another Task straight from a Git repository.

## What a resolver does

A `taskRef` with only a `name` looks for the Task in the namespace of the run. A `taskRef` with a `resolver` field asks a resolver to fetch the Task from somewhere else. A **resolver** is a component that fetches a Task or Pipeline definition from a source, such as another namespace, a Git repository or an OCI registry, and hands it to the Tekton controller for one run. In Tekton 1.17, the resolvers run in the deployment `tekton-pipelines-remote-resolvers` in the namespace `tekton-pipelines-resolvers`.

<!-- astrona:playground:renew -->

The resolvers that are switched on are listed in a ConfigMap. Read it:

```sh
kubectl -n tekton-pipelines-resolvers get configmap resolvers-feature-flags -o jsonpath='{.data}'; echo
```

The output is:

```text
{"enable-bundles-resolver":"true","enable-cluster-resolver":"true","enable-git-resolver":"true","enable-http-resolver":"true","enable-hub-resolver":"true"}
```

All five resolvers are on by default in Tekton Pipelines 1.17:

- `cluster` fetches a Task or Pipeline from another namespace of the same cluster.
- `git` fetches a YAML file from a Git repository at a branch, tag or commit.
- `bundles` fetches a definition stored as an OCI image (a Tekton bundle) in a registry.
- `http` fetches a YAML file from a URL.
- `hub` fetches a Task from a public catalog. Its default type is `artifact`, which means Artifact Hub. The old Tekton Hub service is shut down, so a `hub` reference with `type: tekton` has nothing to reach.

## The cluster resolver

The platform team keeps shared Tasks in their own namespace. Create the namespace `tekton-tasks`, and put a copy of the `fetch-source` Task in it. Make the copy from `task-fetch-source.yaml`: change `namespace: starfleet` to `namespace: tekton-tasks`, and save the result as `task-fetch-source-shared.yaml`.

Create the namespace and apply the shared Task:

```sh
kubectl create namespace tekton-tasks
kubectl apply -f task-fetch-source-shared.yaml
```

## The git resolver

The `scout-app` repository holds its own test Task in the file `tekton/run-tests.yaml`. Keeping the test Task next to the code means a change to the tests and a change to the code arrive in the same commit. This is the Task in the repository:

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: run-tests
spec:
  description: Runs test.sh from the root of the source workspace.
  workspaces:
    - name: source
  results:
    - name: version
      description: The tested application version
  steps:
    - name: test
      image: alpine:3.23
      workingDir: $(workspaces.source.path)
      script: |
        #!/bin/sh
        set -eu
        sh test.sh
        printf '%s' "$(cat VERSION)" > "$(results.version.path)"
```

It has no namespace, because it is never applied to the cluster. The resolver reads it for each run. Its `version` result now comes from the `VERSION` file.

## A Pipeline that uses both resolvers

Change the Pipeline so that `fetch-source` comes from the cluster resolver, `run-tests` comes from the git resolver, and `report-version` takes the version from the `run-tests` result.

Save this as `pipeline-scout-ci.yaml`:

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
    - name: report-version
      runAfter:
        - run-tests
      taskRef:
        name: report-version
      params:
        - name: version
          value: $(tasks.run-tests.results.version)
  results:
    - name: commit
      value: $(tasks.fetch-source.results.commit)
```

The `params` under `taskRef` belong to the resolver, not to the Task. The cluster resolver needs `kind`, `name` and `namespace`. The git resolver in this form needs `url`, `revision` and `pathInRepo`. It clones the repository without credentials, which works here because `scout-app` is public. For a private repository, add the resolver param `gitToken` with the name of a Secret in the namespace of the run that holds an access token.

Apply it, and start a run:

```sh
kubectl apply -f pipeline-scout-ci.yaml
kubectl create -f pipelinerun-scout-ci.yaml
```

Then check the result after about 40 seconds:

```sh
tkn -n starfleet pipelinerun logs --last
tkn -n starfleet pipelinerun describe --last
```

The output is (the `describe` part is shortened to the status and the TaskRuns):

```text
[fetch-source : clone] Cloned commit 9962c15

[run-tests : test] Checking VERSION
[run-tests : test] Tests passed for scout 6.15.0

[report-version : show-system] Running on 3.23.6

[report-version : write-summary] Reporting version 6.15.0

...
STARTED          DURATION   STATUS
40 seconds ago   21s        Succeeded
...
 NAME                            TASK NAME        STARTED          DURATION   STATUS
 scout-ci-f8x74-report-version   report-version   25 seconds ago   6s         Succeeded
 scout-ci-f8x74-run-tests        run-tests        31 seconds ago   6s         Succeeded
 scout-ci-f8x74-fetch-source     fetch-source     40 seconds ago   9s         Succeeded
```

The run looks the same as before, but two of the three Tasks no longer come from `starfleet`.

## Where a resolved Task came from

Each fetch is recorded in a ResolutionRequest, an object that the Tekton controller creates and the resolver answers. The TaskRun also records the exact source of its Task in `status.provenance`:

```sh
kubectl -n starfleet get resolutionrequests
kubectl -n starfleet get taskrun scout-ci-f8x74-run-tests -o jsonpath='{.status.provenance.refSource}'; echo
```

The output is:

```text
NAME                                       OWNERKIND     OWNER            SUCCEEDED   REASON   STARTTIME              ENDTIME
cluster-bf5b6c455bec20c851dd6b62535d17d1   PipelineRun   scout-ci-f8x74   True                 2026-10-10T17:41:51Z   2026-10-10T17:41:51Z
git-9648b459c500576e2a7a8d4102da1c74       PipelineRun   scout-ci-f8x74   True                 2026-10-10T17:41:51Z   2026-10-10T17:41:51Z
{"digest":{"sha1":"9962c157b23c9b7d3d3f224da0dbf099d10ba0bd"},"entryPoint":"tekton/run-tests.yaml","uri":"git+http://gitea-http.gitea.svc:3000/starfleet/scout-app.git"}
```

There is one request per resolver, both owned by the PipelineRun. The provenance names the repository, the file and the commit ID the Task came from, so you can tell later exactly which version of the Task ran.

## When the resolver cannot find the Task

A wrong path in a resolver reference fails the whole run before the Task starts. In `pipeline-scout-ci.yaml`, change `pathInRepo` to `tekton/run-test.yaml` (without the `s`), apply the file, and start a run:

```sh
kubectl apply -f pipeline-scout-ci.yaml
kubectl create -f pipelinerun-scout-ci.yaml
tkn -n starfleet pipelinerun describe --last
```

After about 30 seconds, `describe` shows (shortened):

```text
STARTED          DURATION   STATUS
31 seconds ago   3s         Failed(CouldntGetTask)

Message

Pipeline starfleet/scout-ci can't be Run; it contains Tasks that don't exist: Couldn't retrieve Task "'run-tests' resolver type git\nurl = http://gitea-http.gitea.svc:3000/starfleet/scout-app.git\n": error requesting remote resource: error getting "Git" "starfleet/git-147543ab73962f1c8588f0bfa9c9c21a": error opening file "tekton/run-test.yaml": file does not exist
```

The reason is `CouldntGetTask`, and the end of the message comes from the git resolver: it cloned the repository but did not find the file. No TaskRun ran at all, not even `fetch-source`, because the controller resolves every Task before it starts the first one. Change `pathInRepo` back to `tekton/run-tests.yaml` and apply the file again.

You can now reference a Task in another namespace with the cluster resolver and a Task in Git with the git resolver, check where a resolved Task came from, and read a resolver error. The pipeline now tests and reports a version, but it still runs only when someone starts it, and its result never reaches a cluster.

## Common pitfalls

> [!WARNING]
> - **Putting the Task params under `taskRef.params`.** Those are the resolver's params. The Task's own params stay in the `params` list of the Pipeline task.
> - **Pointing the git resolver at a private repository without `gitToken`.** Without it, the resolver clones anonymously and the fetch fails.
> - **Pointing `revision` at a branch and expecting a fixed Task.** A branch follows new commits, so the next run may get a different Task. Pin a tag or a commit ID when the Task must not change.
> - **Expecting the hub resolver to reach Tekton Hub.** Tekton Hub is shut down; the resolver's default is Artifact Hub.
> - **Looking for a pod after `CouldntGetTask`.** The run fails before any Task starts. Read the PipelineRun message.
