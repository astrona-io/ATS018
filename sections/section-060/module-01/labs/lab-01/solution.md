# Solution

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch -c sections/section-060/module-01/labs/lab-01
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Step 1: deliver the repository with Argo CD

An Argo CD `Application` names a Git path and a destination. One `Application` with the path `.` and `directory.recurse: true` reads the platform API and both environments. Automated sync with prune and self-heal keeps the cluster equal to Git. The sync option `SkipDryRunOnMissingResource=true` lets the `ScoutEnvironment` objects apply after the definition that creates their kind. The sync wave annotations in the files set that order: the definition first, then the `Composition`, then the environments.

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

Then check the result after about a minute. The `Application` is `Synced`, but the `ScoutEnvironment` rows have an empty `HEALTH` column, because Argo CD has no health check for that kind:

```sh
kubectl -n argocd get application scout-platform
kubectl get scoutenvironments.platform.starfleet.dev -A
```

The second command shows `READY False` for production. The `Application` still says `Healthy`.

## Step 2: add a health check for ScoutEnvironment

Argo CD reads health checks written in Lua from the ConfigMap `argocd-cm`. The key is `resource.customizations.health.<group>_<Kind>`. The script reads the `Ready` condition of the object.

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

Patch the ConfigMap with it:

```sh
kubectl -n argocd patch configmap argocd-cm --patch-file argocd-cm-health-scoutenvironment.yaml
```

Then check the result. Argo CD picks up the change without a restart. The production row is `Degraded` and the `Application` is `Degraded`:

```sh
kubectl -n argocd get application scout-platform
```

## Step 3: find the cause in the layers

Read the `Ready` condition of the production XR. It names the composed resource that is not Ready:

```sh
kubectl -n starfleet-production get scoutenvironments.platform.starfleet.dev scout \
  -o jsonpath='{range .status.conditions[?(@.type=="Ready")]}{.reason}: {.message}{"\n"}{end}'
```

The message says `Unready resources: deployment`. Look at the pods and the events of the namespace:

```sh
kubectl -n starfleet-production get pods
kubectl -n starfleet-production get events --field-selector reason=Failed
```

The pods are in `ImagePullBackOff`. The event says that the image `ghcr.io/stefanprodan/podinfo:6.99.0` was not found. The `Composition` copies `spec.version` of the XR into the image name, so the cause is the version in `environments/production/scoutenvironment.yaml`.

## Step 4: fix the version in Git

A change with `kubectl edit` would be undone: Crossplane owns the Deployment, and Argo CD self-heal restores the XR. Change the file in Git.

Clone the repository, change the version and push:

```sh
git clone http://platform:starfleet-gitops@127.0.0.1:3000/starfleet/platform-infra.git platform-infra-fix
cd platform-infra-fix
sed -i.bak 's/version: 6.99.0/version: 6.15.0/' environments/production/scoutenvironment.yaml && rm environments/production/scoutenvironment.yaml.bak
git commit -am "Use the published podinfo tag in production"
git push
```

Then wait about a minute and check the chain from the top:

```sh
kubectl -n argocd get application scout-platform
kubectl get scoutenvironments.platform.starfleet.dev -A
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet-production/ | grep -E '"(version|message)"'
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet-staging/ | grep -E '"(version|message)"'
```

The `Application` is `Synced` and `Healthy`, both XRs are `READY True`, and both environments return version `6.15.0`.

Stop the watch with Ctrl-C, then run the plain command once:

```sh
astrona submit -c sections/section-060/module-01/labs/lab-01
```
