# Active And Preview Services

The `scout` application starts with two pods running podinfo 6.15.0 and the message `stable`. A pod is a Kubernetes resource that runs containers. Its Rollout is an Argo Rollouts resource that manages a release through ReplicaSets. A ReplicaSet keeps copies of one pod template running.

A pod template holds the labels and container settings used to create pods. Check the starting release before changing its template.

<!-- astrona:playground:renew -->

```sh
kubectl argo rollouts get rollout scout -n starfleet --no-color
kubectl -n starfleet get service scout scout-preview -o custom-columns='NAME:.metadata.name,HASH:.spec.selector.rollouts-pod-template-hash'
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout | grep -E '"(version|message)"'
```

The status header is shortened below:

```text
Name:            scout
Namespace:       starfleet
Status:          ✔ Healthy
Strategy:        BlueGreen
Images:          ghcr.io/stefanprodan/podinfo:6.15.0 (stable, active)
Replicas:
  Desired:       2
  Current:       2
  Updated:       2
  Ready:         2
  Available:     2
```

The Service selectors and response from the same command block are:

```text
NAME            HASH
scout           5b574f8446
scout-preview   5b574f8446
  "version": "6.15.0",
  "message": "stable",
```

A Service provides a stable address and selects ready pods by labels. Both Services currently select the same ReplicaSet hash, `5b574f8446`. A hash is an identifier computed from the pod template. The first deployment has no older version to preserve, so Argo Rollouts establishes it as stable without waiting for promotion.

## Separate the candidate from active users

A blue/green release keeps the stable configuration behind an active Service while a candidate configuration starts behind a preview Service. Promotion changes the active Service selector to the candidate's hash. Argo Rollouts changes these selectors; the Kubernetes Service networking then forwards connections to the selected ready pods.

The image tag is not the only thing that defines a release. Environment variables, command arguments and other pod template fields can change application behaviour too. Keep podinfo 6.15.0 and change its message to `preview-good`. This makes the response identify the candidate even though both configurations use the same image.

Save this as `rollout-scout.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: scout
  namespace: starfleet
spec:
  replicas: 2
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
        image: ghcr.io/stefanprodan/podinfo:6.15.0
        command:
        - ./podinfo
        - --port=9898
        - --port-metrics=9797
        env:
        - name: PODINFO_UI_MESSAGE
          value: preview-good
        ports:
        - name: http
          containerPort: 9898
        - name: metrics
          containerPort: 9797
        readinessProbe:
          tcpSocket:
            port: http
        resources:
          requests:
            cpu: 10m
            memory: 32Mi
          limits:
            memory: 64Mi
  strategy:
    blueGreen:
      activeService: scout
      previewService: scout-preview
      autoPromotionEnabled: false
      scaleDownDelaySeconds: 30
```

`activeService` names the Service used by active clients. `previewService` names the separate address used to test the candidate. Both Services already exist in `starfleet`, the namespace that contains the Rollout. A namespace groups Kubernetes resources under one name.

`autoPromotionEnabled: false` requires an operator decision before switching active traffic. `scaleDownDelaySeconds: 30` keeps the old replicas running briefly after that switch. The Transmission Control Protocol (TCP) readiness probe checks whether the application port accepts a connection. It keeps the candidate ready even when an application response fails, so analysis can judge response quality separately.

Apply it:

```sh
kubectl apply -f rollout-scout.yaml
```

```text
rollout.argoproj.io/scout configured
```

Then check the result after the candidate pods become ready:

```sh
kubectl argo rollouts get rollout scout -n starfleet --no-color
kubectl -n starfleet get service scout scout-preview -o custom-columns='NAME:.metadata.name,HASH:.spec.selector.rollouts-pod-template-hash'
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout | grep -E '"(version|message)"'
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout-preview | grep -E '"(version|message)"'
```

The status header is shortened below:

```text
Name:            scout
Namespace:       starfleet
Status:          ॥ Paused
Message:         BlueGreenPause
Strategy:        BlueGreen
Images:          ghcr.io/stefanprodan/podinfo:6.15.0 (active, preview, stable)
Replicas:
  Desired:       2
  Current:       4
  Updated:       2
  Ready:         2
  Available:     2
```

The remaining selector and response output is:

```text
NAME            HASH
scout           5b574f8446
scout-preview   5849b6755f
  "version": "6.15.0",
  "message": "stable",
  "version": "6.15.0",
  "message": "preview-good",
```

The active Service still selects `5b574f8446` and returns `stable`. The preview Service selects `5849b6755f` and returns `preview-good`. The plugin's full tree marks that new ReplicaSet as `preview`; its image line combines roles for the shared image, so the image tag alone cannot distinguish these configurations.

`Paused` and `BlueGreenPause` mean the controller awaits promotion. They do not stop requests. `Current: 4` counts both two-pod ReplicaSets, while `Updated: 2` counts the candidate. Budget for both configurations during a blue/green release; the steady replica count does not describe its peak pod count.

You can now test a candidate through a separate Service while active requests continue to use the stable configuration. The Service hashes prove which templates each address selects, and the response messages prove which application configuration actually answers.

## Common pitfalls

> [!WARNING]
> - **Testing only the active Service.** It still selects the stable configuration before promotion.
> - **Removing the controller's hash selector.** Argo Rollouts uses that selector to keep the two configurations separate.
> - **Assuming a shared image means a shared release.** A changed environment variable creates a different pod template.
> - **Budgeting only for two pods.** This example runs four while stable and preview configurations coexist.
