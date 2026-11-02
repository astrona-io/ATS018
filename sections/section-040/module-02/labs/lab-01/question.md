# Question

Solve this question on: `terminal`

The `scout` application runs in the namespace `starfleet` at version `6.14.0`. Argo CD delivers it from the private Gitea repository `starfleet/scout-deploy`, with automated sync, prune and self-heal. The source repository `starfleet/scout-app` now has a `VERSION` file that says `6.15.0`. The base image `registry.registry.svc:5000/starfleet/podinfo:6.15.0` is in the in-cluster registry.

The Tasks `fetch-source`, `publish-image` and `update-deploy` already exist in `starfleet`. There is no Pipeline, no Git credential and no service account for the pipeline. Build the release and deliver version `6.15.0` through Git. Do not change the Deployment with `kubectl`, and do not turn off or change the sync policy of the Argo CD `Application` `scout`.

When you finish, these must be true:

- The Secret `gitea-credentials` in `starfleet` has the type `kubernetes.io/basic-auth`, the annotation `tekton.dev/git-0: http://gitea-http.gitea.svc:3000`, the user `platform` and the password `starfleet-gitops`. The service account `scout-ci` lists it.
- The Pipeline `scout-release` in `starfleet` runs `fetch-source` on `http://gitea-http.gitea.svc:3000/starfleet/scout-app.git`, then `publish-image` and then `update-deploy`, both with the `version` result of `fetch-source`. The Pipeline has the result `deploy-commit` with the `commit` result of `update-deploy`.
- A `PipelineRun` of `scout-release` that uses the service account `scout-ci` has the status `Succeeded`.
- The registry holds the image `starfleet/scout:6.15.0`.
- The newest commit on `main` of `scout-deploy` is the commit the pipeline pushed. It sets `newTag: 6.15.0`.
- The `Application` `scout` is `Synced` and `Healthy`, and a request from the `shuttle` pod to `http://scout.starfleet` returns the version `6.15.0`.

You can reach Gitea from the lab terminal at `http://127.0.0.1:3000` and Argo CD at `https://127.0.0.1:8080`. The Gitea user is `platform` with the password `starfleet-gitops`.

Check your work with `astrona submit`.
