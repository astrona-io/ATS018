# Summary

A Helm chart packages templates and default values. `Chart.yaml` describes the package, `values.yaml` supplies its defaults and `templates/` holds the resource templates. Rendering replaces expressions with concrete values. Linting checks chart structure and common mistakes; neither rendering nor linting proves that a workload can serve requests.

Use values for settings the template already exposes. Edit a template when the required resource field or structure is missing. Increment the chart version when the chart changes. The application version is descriptive metadata; the template decides which value sets the container image.

A release is one installed copy of a chart in a namespace. Installation creates it, and an upgrade records a new revision. List releases in their destination namespace and inspect history before choosing a rollback target. A rollback restores stored configuration and adds a new revision. Check both release status and the application response, and keep the desired values ready for the next upgrade.

<!-- astrona:playground:destroy -->
