# Solution

## Step 1: create the AnalysisTemplate

An `AnalysisTemplate` holds the metric query. This one divides the rate of `2xx` responses by the rate of all responses on `path="root"` for one pod template hash. A new pod has no rate data for about 45 seconds, so the metric starts after `initialDelay: 45s`. It succeeds at `0.99` or higher, and one failed measurement is allowed.

Save this as `analysistemplate-scout-success.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: scout-success
  namespace: starfleet
spec:
  args:
    - name: canary-hash
  metrics:
    - name: success-rate
      initialDelay: 45s
      interval: 15s
      failureLimit: 1
      successCondition: len(result) == 1 && result[0] >= 0.99
      failureCondition: len(result) != 1 || result[0] < 0.99
      provider:
        prometheus:
          address: http://kps-prometheus.monitoring.svc:9090
          query: |
            sum(rate(http_request_duration_seconds_count{namespace="starfleet",path="root",rollouts_pod_template_hash="{{args.canary-hash}}",status=~"2.."}[1m]))
            /
            sum(rate(http_request_duration_seconds_count{namespace="starfleet",path="root",rollouts_pod_template_hash="{{args.canary-hash}}"}[1m]))
```

Apply it:

```sh
kubectl apply -f analysistemplate-scout-success.yaml
```

## Step 2: add the header route and the background analysis, and release the good canary

The Rollout needs `managedRoutes` with the name `canary-header` so the controller may add and remove a header rule in `scout-route`. The steps keep one canary pod at weight 0 (`setCanaryScale`), add the header rule (`setHeaderRoute`), and pause until you promote. The weight steps come after. The background analysis starts at step 4, the pause after `setWeight: 20`, and gets the hash of the latest template.

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
          image: ghcr.io/stefanprodan/podinfo:6.14.0
          command: ["./podinfo", "--port=9898", "--port-metrics=9797"]
          env:
            - name: PODINFO_UI_MESSAGE
              value: good-build
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
    canary:
      stableService: scout
      canaryService: scout-canary
      trafficRouting:
        managedRoutes:
          - name: canary-header
        plugins:
          argoproj-labs/gatewayAPI:
            httpRoute: scout-route
            namespace: starfleet
      analysis:
        templates:
          - templateName: scout-success
        startingStep: 4
        args:
          - name: canary-hash
            valueFrom:
              podTemplateHashValue: Latest
      steps:
        - setCanaryScale:
            replicas: 1
        - setHeaderRoute:
            name: canary-header
            match:
              - headerName: x-canary
                headerValue:
                  exact: "yes"
        - pause: {}
        - setWeight: 20
        - pause: {duration: 90s}
        - setWeight: 50
        - pause: {duration: 30s}
```

Apply it:

```sh
kubectl apply -f rollout-scout.yaml
```

Then check the result. The Rollout pauses at step 3 with one canary pod. A request with the header goes to the canary, and a request without it goes to the stable pods:

```sh
kubectl argo rollouts get rollout scout -n starfleet
kubectl -n starfleet exec deploy/shuttle -- curl -s -H "x-canary: yes" http://$GATEWAY/ | grep '"message"'
kubectl -n starfleet exec deploy/shuttle -- curl -s http://$GATEWAY/ | grep '"message"'
```

The first request returns `good-build` and the second returns `stable`. Promote the pause:

```sh
kubectl argo rollouts promote scout -n starfleet
```

The Rollout sets weight 20, the background analysis starts and passes, the weight goes to 50, and the Rollout ends `Healthy` on `good-build`. Check that an `AnalysisRun` is `Successful`:

```sh
kubectl -n starfleet get analysisrun
```

## Step 3: release the faulty canary

Change the message to `bad-build` and add `--random-error` to the container command, so podinfo answers some requests with status 400, 409 or 500. Keep `--port-metrics=9797`. Save the changed file as `rollout-scout.yaml`. These are the lines that change:

```yaml
          command: ["./podinfo", "--port=9898", "--port-metrics=9797", "--random-error"]
          env:
            - name: PODINFO_UI_MESSAGE
              value: bad-build
```

Apply it and promote the header pause:

```sh
kubectl apply -f rollout-scout.yaml
kubectl argo rollouts promote scout -n starfleet
```

Then check the result. At weight 20 the background analysis sees a success rate below `0.99`. After the second failed measurement the controller aborts the release, removes the header rule and sends 100 percent of the requests to the stable pods. The `AnalysisRun` is `Failed` and the Rollout is `Degraded`:

```sh
kubectl argo rollouts get rollout scout -n starfleet
kubectl -n starfleet get analysisrun
```

## Step 4: restore the good template

Abort leaves the desired template on `bad-build`. Set the template back to `good-build` without `--random-error` and apply it. The stable pods already run this template, so the Rollout returns to `Healthy`:

```sh
kubectl apply -f rollout-scout.yaml
kubectl argo rollouts get rollout scout -n starfleet
kubectl -n starfleet exec deploy/shuttle -- curl -s http://$GATEWAY/ | grep '"message"'
```

The request returns `good-build`. Run `astrona submit` to grade.
