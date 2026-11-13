# Prerequisites

Allow 35 minutes. Know how Kubernetes Deployments maintain pods and how
Service selectors choose pods. Be able to read OpenTofu configuration and run
`tofu init`, `tofu plan`, `tofu show` and `tofu apply`.

The terminal has OpenTofu 1.13.2, Kubernetes provider 3.4.0, kubectl, curl and
Python 3. Each directory under `~/resources/tofu` has its own provider
configuration, kubeconfig and real `terraform.tfstate`. Keep each state with
its configuration. The `shuttle` Deployment in `starfleet` sends test requests.
