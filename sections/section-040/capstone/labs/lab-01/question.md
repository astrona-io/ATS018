# Question

Solve this question on: `terminal`

The `scout` application runs in the namespace `starfleet` at version `6.14.0`. Argo CD delivers it from the private Gitea repository `starfleet/scout-deploy`, with automated sync, prune and self-heal. The source repository `starfleet/scout-app` now has a `VERSION` file that says `6.15.0`. The base image `registry.registry.svc:5000/starfleet/podinfo:6.15.0` is in the in-cluster registry.

The release Pipeline `scout-release` already exists in `starfleet`, with the Tasks `fetch-source`, `run-tests`, `publish-image` and `update-deploy`. Nobody has run it yet, and it does not work. The release must run the tests before it publishes the image, publish the image, and then commit the new tag to `scout-deploy` so that Argo CD delivers version `6.15.0`.

The Tasks share the files of the repository through the Pipeline workspace `source`. Find out why the release fails and fix every cause. Do not delete a Task, do not remove a Task from the Pipeline, and do not remove the call to `test.sh` from `run-tests`. Do not change the Deployment with `kubectl`, and do not turn off or change the sync policy of the Argo CD `Application` `scout`.

When you finish, these must be true:

- The Task `run-tests` still runs `test.sh`, and its step starts in the `source` workspace.
- The Pipeline `scout-release` still runs `fetch-source`, `run-tests`, `publish-image` and `update-deploy`. `publish-image` runs after `run-tests`, and `update-deploy` runs after `publish-image`. Both `publish-image` and `update-deploy` get the `version` result of `fetch-source`.
- The Secret `gitea-credentials` in `starfleet` has the type `kubernetes.io/basic-auth`, the annotation `tekton.dev/git-0: http://gitea-http.gitea.svc:3000`, the user `platform` and the password `starfleet-gitops`. The service account `scout-ci` lists it.
- A `PipelineRun` of `scout-release` that uses the service account `scout-ci` has the status `Succeeded`.
- The registry holds the image `starfleet/scout:6.15.0`.
- The newest commit on `main` of `scout-deploy` is the commit the pipeline pushed. It sets `newTag: 6.15.0`.
- The `Application` `scout` is `Synced` and `Healthy`, and a request from the `shuttle` pod to `http://scout.starfleet` returns the version `6.15.0`.

You can reach Gitea from the lab terminal at `http://127.0.0.1:3000` and Argo CD at `https://127.0.0.1:8080`. The Gitea user is `platform` with the password `starfleet-gitops`. The `tkn` command-line tool and `kubectl` are installed.

Check your work with `astrona submit`.
