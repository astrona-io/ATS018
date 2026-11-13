# Summary

A broken `Application` fails at one of four stages, and each stage reports in its own place. Finding the stage first turns guessing into a short, fixed sequence of checks.

## What you learned

Argo CD reports problems in three places. `status.conditions` holds problems with the `Application` itself, such as a `ComparisonError` from the repo server. `status.operationState` holds the last sync operation with its phase, revision, retry count and message. The object table of `argocd app get` holds each object's sync status, health and message. Read them in the order of the stages: fetch and render, apply, drift, health.

A `ComparisonError` ends with words that name the source field: `app path does not exist` for `path`, `unable to resolve ... to a commit SHA` for `targetRevision`, `repository not found` for `repoURL`, and `authentication required` for missing credentials. A manifest the API server rejects shows as `OutOfSync` and `Missing` with the API server's validation error on the object. Argo CD 3.5 retries a failed automated sync on the same revision, so after a fix in Git, check `operationState.operation.sync.revision` and run `argocd app terminate-op` if it is still the old commit.

Resource hooks (`argocd.argoproj.io/hook: PreSync`, `Sync`, `PostSync`, `SyncFail`) run at fixed points of a sync, and their status is `Succeeded` rather than `Synced`. Sync waves (`argocd.argoproj.io/sync-wave`, a quoted number) apply lower waves first and wait for each wave to be healthy. A field with a second writer, such as `spec.replicas` under a HorizontalPodAutoscaler, makes self-heal fight that writer; `ignoreDifferences` removes the field from the comparison, and `RespectIgnoreDifferences=true` also keeps the sync from overwriting it.

A `Degraded` Deployment means its rollout passed `progressDeadlineSeconds`. The health message says that; the pod events say why, for example an image tag that does not exist. The fix is a commit, because self-heal reverts any change made with `kubectl`. The key facts to remember are these:

- `Unknown` sync status means nothing was rendered; read the conditions.
- A failed sync names the refused object in the object table.
- `ignoreDifferences` without `RespectIgnoreDifferences=true` still lets the sync overwrite the field.
- Fix the cause where it lives: the `Application` for source fields, Git for everything else.

<!-- astrona:playground:destroy -->
