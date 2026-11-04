# Solution

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch -c sections/section-050/module-02/labs/lab-01
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Step 1: write the gate

An AnalysisTemplate holds the Prometheus query and the conditions. The controller runs inside the cluster, so the address is the in-cluster Service address of Prometheus. The argument `candidate-hash` selects the pods of one template through the label `rollouts_pod_template_hash`. The first measurement waits 45 seconds because a new pod needs several 15-second scrapes before its rate has data.

Save this as `analysistemplate-scout-success.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: scout-success
  namespace: starfleet
spec:
  args:
    - name: candidate-hash
  metrics:
    - name: success-rate
      initialDelay: 45s
      interval: 15s
      count: 3
      failureLimit: 1
      successCondition: len(result) == 1 && result[0] >= 0.99
      failureCondition: len(result) != 1 || result[0] < 0.99
      provider:
        prometheus:
          address: http://kps-prometheus.monitoring.svc:9090
          query: |
            sum(rate(http_request_duration_seconds_count{namespace="starfleet",path="root",rollouts_pod_template_hash="{{args.candidate-hash}}",status=~"2.."}[2m]))
            /
            sum(rate(http_request_duration_seconds_count{namespace="starfleet",path="root",rollouts_pod_template_hash="{{args.candidate-hash}}"}[2m]))
```

Apply it:

```sh
kubectl apply -f analysistemplate-scout-success.yaml
```

Then check the result:

```sh
kubectl -n starfleet get analysistemplate scout-success
```

## Step 2: release the good candidate through the gate

Add `prePromotionAnalysis` to the Rollout and change the message to `gated-good`. The message change is a new pod template, so it starts a release. `podTemplateHashValue: Latest` passes the candidate's hash to the query.

Save this as `rollout-scout-gated.yaml`:

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
          value: gated-good
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
      prePromotionAnalysis:
        templates:
        - templateName: scout-success
        args:
        - name: candidate-hash
          valueFrom:
            podTemplateHashValue: Latest
```

Apply it:

```sh
kubectl apply -f rollout-scout-gated.yaml
```

Then check the result after about 90 seconds:

```sh
kubectl -n starfleet get analysisrun
kubectl argo rollouts get rollout scout -n starfleet --no-color
```

The AnalysisRun is `Successful` and the Rollout is `Paused` with `BlueGreenPause`. Active requests still return the old message. The `gate-recorder` watcher writes the pause and the passed analysis into the ConfigMap `gate-trace`. Promote the candidate with a normal promotion. The watcher then records that the active Service switched after both:

```sh
kubectl argo rollouts promote scout -n starfleet
kubectl argo rollouts status scout -n starfleet --timeout 180s
```

## Step 3: release the faulty candidate

Save this as `rollout-scout-bad.yaml`. It adds `--random-error` and the message `bad-release`:

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
        - --random-error
        env:
        - name: PODINFO_UI_MESSAGE
          value: bad-release
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
      prePromotionAnalysis:
        templates:
        - templateName: scout-success
        args:
        - name: candidate-hash
          valueFrom:
            podTemplateHashValue: Latest
```

Apply it:

```sh
kubectl apply -f rollout-scout-bad.yaml
```

Then check the result after about 90 seconds:

```sh
kubectl -n starfleet get analysisrun
kubectl argo rollouts get rollout scout -n starfleet --no-color
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout | grep '"message"'
```

The newest AnalysisRun is `Failed` with measurements below `0.99`. The Rollout is `Degraded` with `RolloutAborted`, and the active Service still returns `gated-good`. Do not use `promote --full`: it skips the analysis and switches the active Service before the analysis passes. The `gate-recorder` records that, and `astrona submit` fails.

## Step 4: restore the good template

An abort does not change the desired template. Apply the saved good Rollout again:

```sh
kubectl apply -f rollout-scout-gated.yaml
kubectl argo rollouts status scout -n starfleet --timeout 180s
```

The Rollout is `Healthy` on the accepted template. Send a request from `shuttle`:

```sh
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout | grep '"message"'
```

Stop the watch with Ctrl-C, then run the plain command once:

```sh
astrona submit -c sections/section-050/module-02/labs/lab-01
```
