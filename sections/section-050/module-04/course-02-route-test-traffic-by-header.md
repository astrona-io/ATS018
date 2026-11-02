# Route Test Traffic By Header

A weight sends a random share of all users to the canary. Before you give real users a new version, you often want only your own test requests to reach it. A header route does this. It is a rule in the `HTTPRoute` that matches a request header (a name and value the client adds to the request) and sends matching requests to the canary Service. This part adds such a rule to a Rollout and shows that requests with and without the header get different answers.

## Managed routes and the header step

An `HTTPRoute` can hold several rules. The first rule is the one from the last part: it splits traffic between `scout` and `scout-canary` by weight. A header rule is a second rule that the plugin creates while the release runs and deletes when it ends. The Rollout lists the rules it may create under `trafficRouting.managedRoutes`, each with a name. The step `setHeaderRoute` creates the rule with that name and gives it a match.

Two more details matter. First, the step `setCanaryScale` sets how many canary pods run, independent of the weight. A header route needs a canary pod to receive the test requests, but the weight is still 0. In a test without this step, the canary ReplicaSet stayed scaled down at zero pods. Second, the match uses `headerName` and `headerValue`. The value is an exact match here.

Change the pod message so the canary answers differently from the stable version, and add the new steps. The stable `scout` version is podinfo 6.15.0 and the message is `stable`. Save this as `rollout-scout.yaml`:

<!-- astrona:playground:renew -->

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
          command: ["./podinfo", "--port=9898", "--port-metrics=9797"]
          env:
            - name: PODINFO_UI_MESSAGE
              value: canary-build
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
        - pause: {}
```

Apply it. The message changed, so this starts a release:

```sh
kubectl apply -f rollout-scout.yaml
kubectl argo rollouts get rollout scout -n starfleet --no-color | head -15
```

After about 25 seconds the output was:

```text
Name:            scout
Namespace:       starfleet
Status:          ॥ Paused
Message:         CanaryPauseStep
Strategy:        Canary
  Step:          2/5
  SetWeight:     0
  ActualWeight:  0
Images:          ghcr.io/stefanprodan/podinfo:6.15.0 (canary, stable)
Replicas:
  Desired:       2
  Current:       3
  Updated:       1
  Ready:         3
  Available:     3
```

The Rollout is paused with one canary pod running and weight 0. The image is the same in both versions, so the plugin shows `(canary, stable)` on one line. Only the message differs. Read the route that the plugin changed:

```sh
kubectl -n starfleet get httproute scout-route -o yaml | sed -n '/^spec:/,/^status:/p'
```

The output has two rules. The first is unchanged:

```text
  - backendRefs:
    - group: ""
      kind: Service
      name: scout
      port: 80
      weight: 100
    - group: ""
      kind: Service
      name: scout-canary
      port: 80
      weight: 0
    matches:
    - path:
        type: PathPrefix
        value: /
```

The second is the managed route that the plugin added. It sends requests with the header `x-canary: yes` to `scout-canary` only:

```text
  - backendRefs:
    - group: ""
      kind: Service
      name: scout-canary
      port: 80
      weight: 1
    matches:
    - headers:
      - name: x-canary
        type: Exact
        value: "yes"
      path:
        type: PathPrefix
        value: /
    name: canary-header
```

## Test with and without the header

The rule is live, so send requests and read the `message` field. The first loop has no header. The second loop adds `x-canary: yes` with the `-H` option of `curl`:

```sh
kubectl -n starfleet exec deploy/shuttle -- sh -c 'echo "no header:"; for i in 1 2 3; do curl -s http://$GATEWAY/ | grep -o "\"message\": \"[^\"]*\""; done; echo "x-canary: yes:"; for i in 1 2 3; do curl -s -H "x-canary: yes" http://$GATEWAY/ | grep -o "\"message\": \"[^\"]*\""; done'
```

The output is:

```text
no header:
"message": "stable"
"message": "stable"
"message": "stable"
x-canary: yes:
"message": "canary-build"
"message": "canary-build"
"message": "canary-build"
```

Every request without the header reached the stable pods. Every request with the header reached the canary pod. Real users see no change while you test the new version. When the tests pass, promote the Rollout twice. The first promotion runs the weight step, and the second finishes the release:

```sh
kubectl argo rollouts promote scout -n starfleet
kubectl -n starfleet get httproute scout-route -o jsonpath='{range .spec.rules[*]}{.name}{" "}{range .backendRefs[*]}{.name}={.weight} {end}{"\n"}{end}'
kubectl argo rollouts promote scout -n starfleet
kubectl -n starfleet get httproute scout-route -o jsonpath='{range .spec.rules[*]}{.name}{" "}{range .backendRefs[*]}{.name}={.weight} {end}{"\n"}{end}'
```

After the first promotion (and about 15 seconds) the route showed both rules. The first rule has no name, so the line starts with a space:

```text
 scout=80 scout-canary=20 
canary-header scout-canary=1 
```

The 20% weight and the header rule run at the same time. After the second promotion the Rollout was `Healthy` and the plugin had removed the managed route:

```text
 scout=100 scout-canary=0 
```

The release shows how the plugin treats the route. The weight rule stays for the whole life of the `HTTPRoute`, while a managed rule exists only during the release that needs it. You can now send test requests to a canary before any real user, and you can prove with two `curl` loops that the header decides the backend. The next part lets Prometheus judge the real traffic and stop a bad release without anyone watching.

## Common pitfalls

> [!WARNING]
> - **Leaving out `setCanaryScale`.** Without a canary pod, the canary ReplicaSet stays at zero pods and the header route has nowhere to send requests.
> - **Forgetting `managedRoutes`.** The route name in `setHeaderRoute` must be listed there.
> - **Testing with the wrong header value.** The match is exact. `x-canary: Yes` does not match `yes`.
> - **Expecting the header rule to stay.** The plugin removes it when the release ends.
