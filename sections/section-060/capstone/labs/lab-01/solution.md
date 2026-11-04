# Solution

Two faults hide in the repository. The `preview` environment sets `replicas: "1"` (a string), so the API server rejects it and the sync fails. The `Composition` sets the Service `targetPort` to `web`, but the container port is named `http`, so the Service has no endpoints even though every `ScoutEnvironment` reports `Ready`.

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch -c sections/section-060/capstone/labs/lab-01
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Step 1: Deliver the repository with Argo CD

Save this as `application-scout-platform.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: scout-platform
  namespace: argocd
spec:
  project: default
  source:
    repoURL: http://gitea-http.gitea.svc:3000/starfleet/platform-infra.git
    targetRevision: main
    path: .
    directory:
      recurse: true
  destination:
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - SkipDryRunOnMissingResource=true
```

Apply it:

```sh
kubectl apply -f application-scout-platform.yaml
```

```text
application.argoproj.io/scout-platform created
```

`recurse: true` is needed because the environments are in sub-folders. `SkipDryRunOnMissingResource=true` lets Argo CD apply the `ScoutEnvironment` objects before the `CompositeResourceDefinition` has created their kind.

## Step 2: Add the health check for ScoutEnvironment

Save this as `argocd-cm-health-scoutenvironment.yaml`:

```yaml
data:
  resource.customizations.health.platform.starfleet.dev_ScoutEnvironment: |
    hs = {}
    hs.status = "Progressing"
    hs.message = "Waiting for the Ready condition"
    if obj.status ~= nil and obj.status.conditions ~= nil then
      for _, condition in ipairs(obj.status.conditions) do
        if condition.type == "Ready" then
          if condition.status == "True" then
            hs.status = "Healthy"
            hs.message = "Ready"
          else
            hs.status = "Degraded"
            hs.message = condition.reason .. ": " .. (condition.message or "")
          end
        end
      end
    end
    return hs
```

Patch the Argo CD ConfigMap with it:

```sh
kubectl -n argocd patch configmap argocd-cm --patch-file argocd-cm-health-scoutenvironment.yaml
```

```text
configmap/argocd-cm patched
```

## Step 3: Read the first sync failure

After about a minute, read the Application:

```sh
kubectl -n argocd get application scout-platform -o jsonpath='{.status.sync.status}/{.status.health.status}{"\n"}{.status.operationState.message}{"\n"}'
```

```text
OutOfSync/Healthy
one or more synchronization tasks completed unsuccessfully, reason: ScoutEnvironment.platform.starfleet.dev "scout" is invalid: spec.replicas: Invalid value: "string": spec.replicas in body must be of type integer: "string". Retrying attempt #4 at 12:01AM.
```

The message names the field. The `preview` file has `replicas: "1"`. Staging and production were created, and Argo CD keeps retrying the failed operation.

## Step 4: Check the requests

Staging shows `Ready`, but a request from `shuttle` fails:

```sh
kubectl -n starfleet-staging get scoutenvironments scout
kubectl -n starfleet exec deploy/shuttle -- curl -s -m 5 -o /dev/null -w "%{http_code}\n" http://scout.starfleet-staging/
kubectl -n starfleet-staging get endpoints scout
kubectl -n starfleet-staging get svc scout -o jsonpath='{.spec.ports[0].targetPort}{"\n"}'
```

```text
NAME    SYNCED   READY   COMPOSITION        AGE
scout   True     True    scoutenvironment   90s
000
command terminated with exit code 7
NAME    ENDPOINTS   AGE
scout   <none>      89s
web
```

The pod is running, but the Service targets the port `web`. The pod names its port `http`. Crossplane reports `Ready` because the `Object` resources exist and the Deployment is available. It does not check the Service endpoints.

## Step 5: Fix both faults in Git

Clone the repository (use `kubectl -n gitea port-forward svc/gitea-http 3000:3000` in another terminal):

```sh
git clone http://platform:starfleet-gitops@127.0.0.1:3000/starfleet/platform-infra.git
cd platform-infra
```

In `environments/preview/scoutenvironment.yaml`, change `replicas: "1"` to `replicas: 1`. In `platform/composition.yaml`, change `targetPort: web` to `targetPort: http`. Then commit and push:

```sh
git commit -am "Fix the preview replicas type and the Service target port"
git push origin main
```

## Step 6: Stop the old retry

Argo CD keeps retrying the failed operation on the old commit. Terminate it, and the next sync uses the new commit:

```sh
argocd login 127.0.0.1:8080 --username admin --password "$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)" --insecure
argocd app terminate-op scout-platform
```

```text
Application 'scout-platform' operation terminating
```

## Step 7: Check the result

Wait about a minute, then check:

```sh
kubectl get scoutenvironments -A
for env in staging production preview; do kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet-$env/ | grep -E '"message"|"version"'; done
argocd app get scout-platform | grep -E 'Sync Status|Health Status'
```

```text
NAMESPACE              NAME    SYNCED   READY   COMPOSITION        AGE
starfleet-preview      scout   True     True    scoutenvironment   62s
starfleet-production   scout   True     True    scoutenvironment   6m26s
starfleet-staging      scout   True     True    scoutenvironment   6m26s
  "version": "6.15.0",
  "message": "staging",
  "version": "6.15.0",
  "message": "production",
  "version": "6.15.0",
  "message": "preview",
Sync Status:        Synced to main (740dfcf)
Health Status:      Healthy
```

The commit identifier in your output differs.

Stop the watch with Ctrl-C, then run the plain command once:

```sh
astrona submit -c sections/section-060/capstone/labs/lab-01
```
