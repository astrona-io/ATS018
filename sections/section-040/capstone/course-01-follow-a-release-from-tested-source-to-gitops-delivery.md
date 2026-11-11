# Follow A Release From Tested Source To GitOps Delivery

A successful release crosses several boundaries: source files, test results, an image registry, a deployment repository and a GitOps controller. Trace one version through those boundaries instead of treating a successful final Pod as proof that the pipeline worked.

A shared workspace carries files between Tasks. Results carry small values such as a version or commit. A test step can fail even when the workspace is mounted if its working directory points elsewhere. Ordering is separate again: image publication must wait for the tests, and the deployment commit must wait for publication.

The pipeline ServiceAccount needs the credentials used by its Git operation. Inspect the Secret type, Git host annotation and ServiceAccount association together. A credential that exists in the namespace is not automatically available to every Task.

In this exercise the publishing Task copies an existing image into the local registry. It does not compile application source. Prove the requested version exists in the registry, that the pipeline wrote the deployment repository’s newest commit, and that Argo CD applied that commit.

Keep the PipelineRun and inspect its task results as well as its final status. The final Service response should agree with the tested version, published image and GitOps revision. A manual Deployment change breaks that chain of evidence.
