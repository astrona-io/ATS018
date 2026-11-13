# Solution Walkthrough

Inspect the competing desired values:

```sh
kubectl -n argocd get application scout-hpa -o yaml
kubectl -n starfleet-hpa get deployment scout -o yaml
kubectl -n starfleet-hpa describe hpa scout
```

Configure both comparison and sync behavior:

```sh
kubectl -n argocd patch application scout-hpa --type=merge -p '{"spec":{"ignoreDifferences":[{"group":"apps","kind":"Deployment","name":"scout","namespace":"starfleet-hpa","jsonPointers":["/spec/replicas"]}],"syncPolicy":{"syncOptions":["CreateNamespace=true","RespectIgnoreDifferences=true"]}}}'
kubectl -n argocd annotate application scout-hpa argocd.argoproj.io/refresh=hard --overwrite
kubectl -n argocd wait --for=jsonpath='{.status.sync.status}'=Synced application/scout-hpa --timeout=240s
kubectl -n starfleet-hpa get deployment,hpa scout
```

`ignoreDifferences` suppresses the comparison difference. `RespectIgnoreDifferences=true` also preserves the live replica count during a sync of an existing resource. It does not supply a replica count before the Deployment exists. Keep the exception scoped to this Deployment and keep self-heal enabled so unrelated drift is still repaired.

A Synced status alone cannot prove this ownership split. The grader commits another field and checks both the resulting sync and a subsequent self-heal while observing replicas.
