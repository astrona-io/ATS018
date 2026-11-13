# Gate A Blue/Green Release With Analysis

A new application can start successfully and still return errors to users. A readiness probe tells Kubernetes whether a pod can receive requests. It does not decide whether a release has an acceptable error rate. A blue/green release runs stable and candidate configurations separately, then switches active traffic to the candidate in one step.

Argo Rollouts manages that switch through a Rollout, a Kubernetes resource that controls release progress. Its active Service selects the stable pods; its preview Service lets you test the candidate first. A Service gives selected ready pods a stable address. An AnalysisTemplate defines metric checks, and an AnalysisRun records one execution of those checks.

Keep one sentence in mind for this module: **query the candidate's metrics before you switch active traffic.** Prometheus, a system that collects and queries application measurements, provides the evidence. Argo Rollouts decides whether the evidence allows the release to continue.

The module has four parts. **Active And Preview Services** changes the pod template and proves the two addresses select separate configurations. **Promote And Measure The Candidate** switches traffic, observes delayed scale-down and queries the candidate's success fraction. **Pre-Promotion Analysis With Prometheus** attaches a metric check and keeps manual promotion after success. **Abort A Release On Failed Analysis** deploys a ready application with random errors, checks the automatic abort and restores the desired configuration.

## Learning objectives

After this module you can:

- Configure `blueGreen` with active and preview Services and automatic promotion disabled.
- Test a candidate through the preview Service before promotion.
- Write an AnalysisTemplate that queries Prometheus for the candidate's success rate.
- Attach pre-promotion analysis and read the AnalysisRun phase and measurements.
- Prove that failed analysis aborts a release while the stable configuration remains active.

## Before you start

You need Kubernetes basics: namespaces, labels, selectors, Services, pod templates, ReplicaSets and readiness probes. A ReplicaSet keeps copies of one pod template running. You also need `kubectl apply`, `kubectl get` and `kubectl exec`.

The playground runs Kubernetes 1.35.8 and Argo Rollouts 1.10.0. Use kubectl 1.35.8 and the kubectl-argo-rollouts plugin 1.10.0 on your machine. A plugin is an executable on your shell's `PATH` that adds commands to kubectl. These pages use `kubectl argo rollouts` to inspect and promote releases.

| Namespace | What is in it |
| --- | --- |
| `argo-rollouts` | The release controller and its custom resource definitions |
| `monitoring` | Prometheus Operator and a small Prometheus instance |
| `starfleet` | Two `scout` replicas, active and preview Services, a PodMonitor and the `shuttle` request client |

podinfo is a web application on port 9898 that returns its version and a configurable message. The starting configuration uses image 6.15.0 and message `stable`. Both Services initially select it. The examples keep the image tag and change configuration messages so responses identify each release. Automatic promotion is disabled, and no analysis exists yet.

A PodMonitor tells the Prometheus Operator which pods to scrape and which labels to retain. Prometheus scrapes the dedicated metrics port 9797 every 15 seconds. podinfo does not inject random application errors on that port. `shuttle` sends steady requests to both Services so candidate measurements exist before promotion.

Prometheus is forwarded to `http://127.0.0.1:9090`; the controller uses its separate in-cluster address.

Write the manifests in an empty folder on your machine. Keep the playground running and use its Kubernetes context for every command. No GitOps controller manages these objects, so you apply changes directly; in a GitOps environment, record the same desired state in Git and let its controller apply it.

<!-- astrona:playground -->
