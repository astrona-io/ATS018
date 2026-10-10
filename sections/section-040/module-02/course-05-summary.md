# Summary

A release crosses from CI to GitOps at one point: a commit to the GitOps repository that names a new image tag. The pipeline writes to the registry and to Git, and only Argo CD writes to the cluster.

## What you learned

The pipeline publishes a version as an image tag in a registry and reports its digest, so the tag can later be checked against exactly one image. In this course the "build" is a copy of a podinfo base image to a new `scout` tag, because building images needs more memory than the playground has; a real pipeline builds the image from the source at the same point. A publish that fails stops the Pipeline, so no commit names an image that does not exist.

The pipeline then changes the tag in the GitOps repository with an ordinary `git` commit and push. A private repository needs credentials: a Secret of type `kubernetes.io/basic-auth` with the annotation `tekton.dev/git-0` set to the Git server address, listed in a ServiceAccount that the run uses. Tekton writes `.gitconfig` and `.git-credentials` into the home folder of each step from it. That service account needs no rights on workloads, and it should have none.

A Pipeline takes the version from the `VERSION` file in the source repository, passes it as a result to the publish and commit Tasks, and orders the commit after the publish with `runAfter`. `taskRunTemplate.serviceAccountName` on the PipelineRun gives every TaskRun the credentials. The proof of a release has two halves: `tkn pipelinerun describe` shows `Succeeded` and the GitOps commit, and `argocd app get` shows the application `Synced` to that commit and `Healthy`, followed by a request from `shuttle` that returns the new version.

Tekton Triggers starts the Pipeline from a push. An `EventListener` runs as the Deployment and Service `el-<name>` and receives the webhook; a `cel` interceptor filters events; a `TriggerBinding` reads values such as `$(body.after)` from the request; and a `TriggerTemplate` creates the PipelineRun with them. The `EventListener` needs its own service account bound to the two Triggers ClusterRoles. The key facts to remember are these:

- The pipeline never applies to the cluster; it commits to Git, and Argo CD syncs.
- Git credentials reach a step through an annotated Secret listed in the run's service account.
- Build from the pushed commit ID, not from the branch name.
- An `EventListener` answers with an event ID even when its filter drops the event.

<!-- astrona:playground:destroy -->
