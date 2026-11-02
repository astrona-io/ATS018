# Prerequisites

- `kubectl` 1.35 and the `tkn` command-line tool.
- Tekton Pipelines 1.17.0 in the namespace `tekton-pipelines`. The lab installs it.
- Gitea with the public repository `starfleet/scout-app`. The lab creates it. Gitea is reachable at `http://gitea-http.gitea.svc:3000` inside the cluster.
- The Tasks `fetch-source` and `run-tests` and the Pipeline `scout-ci` in the namespace `starfleet`. The lab installs them.
- The `shuttle` client pod in the namespace `starfleet`.
