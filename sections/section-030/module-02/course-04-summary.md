# Summary

Many applications need two things that a single `Application` cannot give: a way to create them without copying, and a way to keep teams apart. Argo CD answers the first with app of apps and `ApplicationSet` objects, and the second with `AppProject` objects.

## What you learned

The app of apps pattern keeps `Application` manifests in a Git folder and delivers them with one parent `Application` whose destination namespace is `argocd`. It moves the copies into Git, but every child is still hand-written. The parent does not judge its children's health by default, and deleting an `Application` only deletes its objects when it carries the finalizer `resources-finalizer.argocd.argoproj.io`.

An `ApplicationSet` combines a generator with a template. The list generator takes its parameter sets from `elements`; the Git directory generator makes one parameter set per matching folder, with `{{.path.path}}` and `{{.path.basename}}`. With `goTemplate: true` and `missingkey=error`, placeholders use Go template syntax and a misspelled parameter fails instead of rendering empty. Generated applications have an owner reference to their `ApplicationSet`, are set back if edited by hand, carry the cascading-delete finalizer, and take over existing applications with the same name. The Git generator polls every three minutes; the annotation `argocd.argoproj.io/application-set-refresh=true` skips the wait.

An `AppProject` limits its applications through `sourceRepos`, `destinations`, `clusterResourceWhitelist` and `namespaceResourceWhitelist`. The `default` project allows everything. A repository or destination outside the rules makes the whole application invalid with an `InvalidSpecError` condition, while a kind that is not whitelisted blocks only that object with the message `resource <group>:<kind> is not permitted in project`. The key facts to remember are these:

- An `ApplicationSet` owns what it generates; change the template or the generator, never the `Application`.
- Removing an element or a folder deletes the generated application and its workloads unless `preserveResourcesOnDeletion` is set.
- The core API group is written as `''` in project whitelists.
- Put every tenant in its own project.

<!-- astrona:playground:destroy -->
