# Solution

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch -c sections/section-050/module-01/labs/lab-01
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Step 1: write the Rollout for the current version

A Rollout has the same `selector` and pod template as the Deployment. It adds a `strategy` with the canary steps. Start on the version that runs now, `6.14.0`, so the controller treats the next change as a release.

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

Apply it:

```sh
kubectl apply -f rollout-scout.yaml
```

Then check the result:

```sh
kubectl argo rollouts status scout -n starfleet --timeout 180s
```

The first revision of a Rollout skips the canary steps. The command prints `Healthy` when the stable ReplicaSet has 5 ready pods.

## Step 2: remove the Deployment

The Deployment and the Rollout both select `app=scout`. Delete the Deployment so only the Rollout manages the pods:

```sh
kubectl -n starfleet delete deployment scout
kubectl -n starfleet get pods -l app=scout
```

Only the Rollout's pods remain, and the Service `scout` keeps sending requests to them.

## Step 3: release 6.15.0

Change the image. This is a template change, so the Rollout starts a release and stops at the first pause:

```sh
kubectl argo rollouts set image scout scout=ghcr.io/stefanprodan/podinfo:6.15.0 -n starfleet
kubectl argo rollouts get rollout scout -n starfleet --no-color
```

The status is `Paused` with `CanaryPauseStep`, step `1/4`, and `SetWeight: 20`. One of the 5 pods runs `6.15.0`.

## Step 4: promote both pauses

Promote the first pause. The Rollout moves to 60 percent and stops at the second pause:

```sh
kubectl argo rollouts promote scout -n starfleet
```

Wait until the status shows `Paused` again at step `3/4`, then promote the second pause:

```sh
kubectl argo rollouts promote scout -n starfleet
kubectl argo rollouts status scout -n starfleet --timeout 180s
```

Do not use `--full`: it skips the remaining steps.

## Step 5: prove the result

Wait a few seconds for the old pods to end, then send a request from `shuttle`:

```sh
kubectl argo rollouts get rollout scout -n starfleet --no-color
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout | grep '"version"'
```

The status is `Healthy` with `6.15.0 (stable)` and the response shows `"version": "6.15.0"`.

Stop the watch with Ctrl-C, then run the plain command once:

```sh
astrona submit -c sections/section-050/module-01/labs/lab-01
```
