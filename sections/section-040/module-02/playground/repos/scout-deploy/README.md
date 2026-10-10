# scout-deploy

The GitOps repository for `scout`. Argo CD syncs the root folder into the
namespace `starfleet`. The release pipeline changes only `newTag` in
`kustomization.yaml`.
