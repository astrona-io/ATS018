# Summary

Flux separates fetching from applying. A GitRepository names a repository, revision and credential Secret. The source controller fetches it and publishes an artifact. Its Ready condition proves that the fetch succeeded, and its artifact revision identifies the commit.

A Flux Kustomization names an artifact path and the source that supplies it. The kustomize controller renders that path, applies its objects and records them in its inventory. `targetNamespace` changes the destination of namespaced objects, but does not create a Namespace. A dependency Kustomization can create it first; `dependsOn` waits for that dependency's Ready condition.

With `wait: true`, readiness also includes health checks for the applied objects. Controller status should agree with real behaviour: a request from the client must reach the expected application version and settings. Source readiness alone cannot prove that.

Reconciliation repairs drift and applies committed changes. Suspension pauses that work while leaving existing objects running. Its status must be read separately from the last Ready condition. Resuming restores reconciliation, and `--with-source` requests a fresh fetch before applying. Pruning deletes previously managed objects that leave the rendered files.

<!-- astrona:playground:destroy -->
