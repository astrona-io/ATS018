# Trace A Kustomize Overlay From Source To Response

A Kustomize overlay transforms shared manifests into the objects for one environment. A successful build proves that the transformations can be evaluated. It does not prove that the rendered image exists, that a Service selects the intended Pods, or that the application uses the generated settings.

Inspect the rendered output before applying it. Follow the resource name and namespace from the overlay to the Deployment, then follow the pod labels into the Service selector. For a generated ConfigMap, check both its hashed name and the reference in the pod template. Kustomize rewrites that reference when the generated content changes; a hand-written ConfigMap bypasses this relationship.

Compare staging and production explicitly. The same base can produce different tags, replica counts, messages and memory settings without copying the base. A change that belongs to one environment should remain in its overlay. If both environments need the same correction, inspect the shared source.

After applying, distinguish a rollout problem from a routing problem. Updated and available replicas establish that the Deployment completed its rollout. A request through the Service establishes that selectors, ports and application configuration work together. Check the returned version and message for each namespace, rather than accepting the first healthy endpoint.
