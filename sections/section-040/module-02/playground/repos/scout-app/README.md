# scout-app

Source of the `scout` application. The release pipeline reads `VERSION`,
publishes the podinfo image with that version to the in-cluster registry as
`registry.registry.svc:5000/starfleet/scout:<version>`, and writes the new tag
into `starfleet/scout-deploy`.
