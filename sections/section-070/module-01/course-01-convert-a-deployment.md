# Convert A Deployment Into A Rollout

The `scout` Deployment starts with five ready pods running podinfo 6.14.0. A Deployment is a Kubernetes resource that manages ReplicaSets when its pod template changes. A ReplicaSet keeps a requested number of matching pods running. First check the running application so that you can compare it with the replacement.

<!-- astrona:playground:renew -->

```sh
kubectl -n starfleet get deploy scout
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout | grep '"version"'
kubectl argo rollouts version --short
```

The real run returned:

```text
NAME    READY   UP-TO-DATE   AVAILABLE   AGE
scout   5/5     5            5           11s
  "version": "6.14.0",
kubectl-argo-rollouts: v1.10.0+d90700a
```

The Service answers with 6.14.0, and the command-line plugin reports version 1.10.0. A Service is a Kubernetes resource that provides a stable address and selects ready pods by labels. The `scout` Service selects `app: scout`; it does not care whether a Deployment or a Rollout owns those pods.

## Why readiness is not a release decision

A Deployment rolling update creates new pods and removes old pods within its availability limits. A readiness probe decides whether each new pod can receive requests. It does not decide whether the new application behaves well enough to release to every user. A ready pod can still return the wrong result.

A canary release keeps a stable version serving while a new version receives a limited share of traffic. Argo Rollouts implements that release with a `Rollout`, a custom Kubernetes resource that adds canary and blue/green strategies. The Argo Rollouts controller creates and scales its ReplicaSets. The Kubernetes Deployment controller no longer manages this application after the conversion.

## Replace the workload controller

For this small playground, delete the Deployment before creating the Rollout. This conversion can briefly interrupt service while replacement pods start. Do not treat it as a procedure for a production application that must remain available. Argo Rollouts also supports a `workloadRef` migration that references an existing Deployment; this example uses a complete pod template to make ownership clear.

```sh
kubectl -n starfleet delete deployment scout --wait=true
```

The output is:

```text
deployment.apps "scout" deleted from starfleet namespace
```

Keep the Service. Do not leave a Deployment and a separate Rollout independently creating pods with the same selector: both would contribute endpoints to the Service, and the canary's replica split would no longer describe all its traffic.

Save this as `rollout-scout.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: scout
  namespace: starfleet
spec:
  replicas: 5
  revisionHistoryLimit: 3
  selector:
    matchLabels:
      app: scout
  template:
    metadata:
      labels:
        app: scout
    spec:
      containers:
        - name: scout
          image: ghcr.io/stefanprodan/podinfo:6.14.0
          ports:
            - name: http
              containerPort: 9898
          readinessProbe:
            httpGet:
              path: /readyz
              port: http
          resources:
            requests:
              cpu: 10m
              memory: 32Mi
            limits:
              memory: 64Mi
  strategy:
    canary:
      maxSurge: 1
      maxUnavailable: 0
      steps:
        - setWeight: 20
        - pause: {}
        - setWeight: 60
        - pause: {}
```

The `selector` matches the pod labels and the existing Service. `replicas: 5` gives the controller five copies to divide between stable and canary versions. `maxSurge: 1` permits one extra pod during a change, while `maxUnavailable: 0` requires the controller to maintain the desired availability during updates. Those limits do not protect availability when you delete the starting Deployment.

Apply it:

```sh
kubectl apply -f rollout-scout.yaml
```

The output is:

```text
rollout.argoproj.io/scout created
```

Then check the result:

```sh
kubectl argo rollouts status scout -n starfleet --timeout 120s
kubectl argo rollouts get rollout scout -n starfleet --no-color
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout | grep '"version"'
```

The output below is shortened to the status header:

```text
Healthy
Name:            scout
Namespace:       starfleet
Status:          ✔ Healthy
Strategy:        Canary
  Step:          4/4
  SetWeight:     100
  ActualWeight:  100
Images:          ghcr.io/stefanprodan/podinfo:6.14.0 (stable)
Replicas:
  Desired:       5
  Current:       5
  Updated:       5
  Ready:         5
  Available:     5
```

The response line from the same command block is:

```text
  "version": "6.14.0",
```

The first creation reaches `Healthy` with all five replicas on 6.14.0. Argo Rollouts skips the canary steps on the initial deployment because there is no previous stable version to retain. The first ReplicaSet becomes stable. The steps run when you change the pod template after that stable version exists.

You have replaced the workload controller while preserving the Service address and labels. The initial Rollout establishes the stable version; an image change is what starts a canary release with a meaningful old and new split.

## Common pitfalls

> [!WARNING]
> - **Expecting the initial creation to pause at 20%.** There is no stable version yet, so the first deployment skips the steps.
> - **Leaving two independent controllers behind one selector.** Extra Deployment pods invalidate the Rollout's replica split.
> - **Changing the pod labels without the Service selector.** Ready pods then receive no requests through that Service.
> - **Using this delete-and-create procedure without planning downtime.** Deleting the Deployment removes its application pods.
