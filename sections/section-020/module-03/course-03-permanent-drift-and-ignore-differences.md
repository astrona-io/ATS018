# Permanent Drift And ignoreDifferences

Self-heal assumes that Argo CD is the only writer of the objects it manages. Some fields have a second, legitimate writer: a HorizontalPodAutoscaler changes `spec.replicas` of a Deployment, and admission webhooks add fields to many objects. When Git says one thing and another controller says another, self-heal turns into a fight that never ends. This part watches that fight on `scout-hpa` and stops it by telling Argo CD to leave one field alone.

## Two controllers, one field

The `hpa` folder holds a Deployment with `replicas: 1` and a HorizontalPodAutoscaler (HPA) for it with `minReplicas: 2`. An HPA is the Kubernetes object that changes a workload's replica count to keep a metric, here CPU use, near a target. It never allows fewer replicas than `minReplicas`.

<!-- astrona:playground:renew -->

Watch the replica count of the Deployment for half a minute:

```sh
for i in 1 2 3 4 5 6; do
  echo "$(date +%T) replicas=$(kubectl -n starfleet-hpa get deploy scout -o jsonpath='{.spec.replicas}')"
  sleep 5
done
```

You should see something like:

```text
18:09:51 replicas=1
18:09:56 replicas=1
18:10:01 replicas=2
18:10:06 replicas=1
18:10:11 replicas=1
18:10:16 replicas=2
```

The count keeps flipping. The HPA raises it to `2`; Argo CD sees the Deployment differ from Git, and self-heal sets it back to `1`; the HPA raises it again. The events of both sides show how long this has been going on:

```sh
kubectl -n starfleet-hpa get events --field-selector involvedObject.kind=HorizontalPodAutoscaler \
  -o custom-columns=COUNT:.count,REASON:.reason,MESSAGE:.message
```

You should see something like:

```text
COUNT   REASON              MESSAGE
10      SuccessfulRescale   New size: 2; reason: Current number of replicas below Spec.MinReplicas
```

Each round starts a pod and stops another. `argocd app diff scout-hpa` shows `replicas` when you catch the application between two rounds, and nothing right after a self-heal, which is why this kind of drift is easy to miss.

The cleanest fix is to delete `replicas` from the Deployment in Git, so Git no longer has an opinion. That is not always possible, for example when the manifest comes from a chart you do not own. The Argo CD fix works in every case.

## Ignore the field

`ignoreDifferences` in the `Application` tells the application controller to leave out chosen fields when it compares live state with Git. `jsonPointers` names fields by path, as in a JSON 6902 patch. In this playground the `Application` is not in Git, so you change it with `kubectl`.

Save this as `application-scout-hpa.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: scout-hpa
  namespace: argocd
spec:
  project: default
  source:
    repoURL: http://gitea-http.gitea.svc:3000/starfleet/scout-faults.git
    targetRevision: main
    path: hpa
  destination:
    server: https://kubernetes.default.svc
    namespace: starfleet-hpa
  ignoreDifferences:
    - group: apps
      kind: Deployment
      name: scout
      jsonPointers:
        - /spec/replicas
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

Apply it:

```sh
kubectl apply -f application-scout-hpa.yaml
```

Then watch the replica count again with the same loop. It stays at `2`, and `argocd app get scout-hpa` reports `Synced`. The difference still exists, but the comparison no longer counts it.

## Ignored in the comparison, not in the sync

There is a catch. Push any other change to the `hpa` folder, for example a larger memory request, and watch the replicas right after the sync. On the playground it looked like this:

```text
18:11:17 replicas=2
18:11:18 replicas=1
18:11:19 replicas=1
```

The sync applied the whole manifest from Git, `replicas: 1` included. `ignoreDifferences` only changes how the application controller compares; it does not change what a sync applies. The sync option `RespectIgnoreDifferences=true` makes the sync leave the ignored fields alone too. In `application-scout-hpa.yaml`, add it under `syncOptions`:

```yaml
    syncOptions:
      - CreateNamespace=true
      - RespectIgnoreDifferences=true
```

Apply it, push another change to the folder, and watch again. This time the count stayed at `2` through the whole sync, while the new memory request reached the Deployment.

Right after that sync, the HPA itself showed as `Degraded` for a few seconds, with the message `the HPA was unable to compute the replica count: failed to get cpu utilization: did not receive metrics for targeted pods (pods might be unready)`. New pods have no CPU numbers until metrics-server has measured them. It cleared on its own; a short `Degraded` right after a rollout is not a fault.

You can now recognise a fight between self-heal and another controller, and end it with `ignoreDifferences` plus `RespectIgnoreDifferences=true`. Every application so far was repaired by changing its source or its sync behaviour. The open question is the application that is perfectly synced and still does not work.

## Common pitfalls

> [!WARNING]
> - **Keeping `replicas` in Git for a workload with an HPA.** Self-heal and the HPA then fight forever. Remove the field, or ignore it.
> - **Using `ignoreDifferences` without `RespectIgnoreDifferences=true`.** The comparison ignores the field, but the next sync still overwrites it.
> - **Trusting a clean `argocd app diff` once.** Self-heal can hide drift between two rounds; watch the field over time.
> - **Ignoring more than needed.** Name the group, kind, object and field; a broad rule hides real drift.
