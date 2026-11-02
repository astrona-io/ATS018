# Automate Image Updates With Flux

A new `scout` image tag sits in the registry, but the Git repository still names the old tag. Flux delivers only what Git says, so nothing changes in the cluster. You need the cluster to notice the new tag, write it into Git and then deliver it, with every step visible in a commit.

Flux image automation does this with three objects. An `ImageRepository` scans a container registry for tags. An `ImagePolicy` picks one tag from that list by a rule. An `ImageUpdateAutomation` edits a file in Git and pushes a commit with the chosen tag. The Flux source and kustomize controllers then deliver that commit like any other change.

The module has three parts. **Select A Tag With ImageRepository And ImagePolicy** scans the registry and chooses the newest version, including a policy that selects nothing. **Commit The Tag To Git** marks the field to update, creates the automation and follows the commit to the running pods. **Release A New Tag And Read The Status** publishes another tag and reads the status of each object along the way.

## Learning objectives

After this module you can:

- Create an `ImageRepository` and an `ImagePolicy` that select the newest semantic version of `scout`.
- Mark a field in a Kustomize file with an image policy marker comment.
- Create an `ImageUpdateAutomation` that commits the new tag to Gitea and read its status.
- Prove that a new tag in the registry becomes a Git commit, a reconciliation and a new version served to `shuttle`.
- Explain how the Flux image objects replace the commit step of a Tekton hand-off.

## Before you start

You need Kubernetes namespaces, Deployments and Services, and the commands `kubectl apply`, `kubectl get` and `kubectl exec`. You also need basic Git: `git clone`, `git commit` and `git push`. A container registry is a server that stores container images, each under a name and a tag.

The playground runs Kubernetes 1.35.8 and Flux 2.9.6 with its image reflector and image automation controllers. Flux already delivers `scout` version 6.14.0 from the Gitea repository `starfleet/scout-deploy`. An in-cluster registry holds the tags `6.14.0` and `6.15.0` of `scout`. A Secret with a read-write Git credential is ready in `flux-system`. No `ImageRepository`, `ImagePolicy` or `ImageUpdateAutomation` exists yet.

`shuttle` runs in `starfleet` as a client. Use the Flux 2.9.6 command-line tool on your machine; every command runs against the playground. The registry holds a copy of the podinfo image, so no new image is built. Publishing a tag only gives the same image a new name.

<!-- astrona:playground -->
