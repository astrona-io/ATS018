# Verify Helm And Kustomize Deliveries Separately

Helm and Kustomize can deliver similar Kubernetes objects while keeping different records of intent. Helm stores a release with its chart and values. Kustomize renders the selected base and overlay into manifests. Keep the two sources separate when production uses a chart and staging uses an overlay.

For Helm, trace a value through the complete path: the values file supplies it, the template references it, the rendered manifest contains it, and the installed release uses it. Changing a values file has no effect if the template never reads that field. Chart version and application version also describe different things: the chart version identifies the package, while the image tag selects the container version.

For Kustomize, inspect the base reference, environment-specific transformations and generated settings. A ConfigMap generator needs a matching reference from the pod template. Keep the generated hash suffix so a settings change changes that reference and therefore the pod template.

Render both deliveries before applying them. Then compare the saved source with the live resources and test each Service from the client Pod. Replica counts show the rollout state; the response version and message show which application configuration is actually serving. Directly patching a Deployment leaves the saved chart or overlay unable to reproduce that result.
