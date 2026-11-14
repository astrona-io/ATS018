# Prerequisites

You need `kubectl apply`, `kubectl set env`, and basic knowledge of Deployments and Service selectors. A Deployment manages copies of a pod template. A Service selects the pods that receive requests.

The terminal has `kubectl` and `curl`. Bootstrap uses Helm 4.3.0 when Helm is not already available. The cluster provides Flagger 1.45.0, load tester 0.39.0, and the `scout` and `shuttle` Deployments in `starfleet`. No service mesh or metrics backend is installed. Write the event file in the same terminal where you run `kubectl`.
