# Summary

OpenTofu configuration describes desired settings. State maps resource addresses
to real objects and records their attributes. Initialization selects and
installs the pinned provider. Keep each state with its own configuration and
protect state and plan files because they can contain sensitive values.

A plan reads live resources and proposes changes. A binary plan preserves the
operations for apply; a human-readable diff supports review. After applying,
check both Kubernetes behaviour and a fresh plan. Adding a Service requires a
selector that matches pod labels and the correct target port.

OpenTofu changes resources when an apply runs. Crossplane runs controllers
that repeatedly reconcile desired and live state. Give each object a clear
owner, and change managed settings in the configuration so a later operation
does not restore an old value.

<!-- astrona:playground:destroy -->
