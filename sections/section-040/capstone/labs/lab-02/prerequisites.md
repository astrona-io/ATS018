# Prerequisites

- `kubectl` 1.35 and `git`.
- Argo Workflows v4.1.6 (workflow controller) in the namespace `starfleet`. The lab installs it. The Argo server is not installed.
- Argo Events v1.9.11 in the namespace `argo-events`, with a one-pod JetStream EventBus named `default` and the service account `workflow-submitter`. The lab installs them.
- Gitea with the public repository `starfleet/scout-app` and a push webhook to the EventSource Service. The lab creates them. Gitea is reachable at `http://127.0.0.1:3000` from the lab terminal. The user `platform` has the password `starfleet-gitops` and can push.
- The EventSource `push-webhook`, the Sensor `push-ci`, the WorkflowTemplate `run-tests`, the service account `workflow-runner` and the `shuttle` client pod. The lab installs them, and they do not work yet.
