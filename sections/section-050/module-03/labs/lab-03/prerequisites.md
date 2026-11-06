# Prerequisites

You need to read and apply Kubernetes YAML and use `kubectl get`, `wait`,
`set image` and `exec`. A webhook is an HTTP (Hypertext Transfer Protocol)
request that Flagger sends to another service for a release decision.

The terminal needs `kubectl`, curl, Bash and Helm 4.3.0 for bootstrap.
Bootstrap installs Helm if needed, Flagger 1.45.0 and load tester 0.39.0.
The environment preloads podinfo 6.14.0 and 6.15.0 and curl 8.22.0.
It initializes the ungated `scout` Canary and its primary Deployment.
No Istio or Prometheus is needed. Use the lab's Kubernetes context.
