# Follow GitOps Delivery Through Crossplane Reconciliation

Delivering a platform API requires several controllers to agree. Argo CD applies the API definition, Composition and composite resources from Git. Crossplane uses each composite resource to create and reconcile the underlying Kubernetes objects.

Establish the API before its instances. Sync waves order related resources, while dry-run handling must account for a resource kind that does not yet exist when the operation begins. A successful apply of the API definition is only the start of the reconciliation chain.

Inspect health at each level. Argo CD needs a health mapping for the custom composite kind if its Application health should reflect that object’s Ready condition. Crossplane conditions and composed-resource status explain why the environment is or is not ready.

When a desired value is wrong, repair the repository that owns it. Preserve the environment-specific replica count and message while following the image version into the composed Deployment. Patching the generated Deployment directly leaves Crossplane free to restore the incorrect declared state.

Verify that Argo CD applied the repaired revision and that each composite resource is Ready. Then request every environment through its Service. Readiness establishes controller health; the response establishes that the selected Pods serve the intended version and environment message.
