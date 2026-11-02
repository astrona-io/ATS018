# Split Traffic With The Gateway API Plugin

A canary release without a traffic router can only approximate a weight with whole pods. One new pod out of five gives about 20%, and one new pod out of two gives 50%. A traffic router removes that limit. It is a component that decides, for each request, which backend receives it. This part connects Argo Rollouts to a router, so a weight of 10% means that about 10% of requests reach the new version, no matter how many pods run.

## What the router and the plugin do

The router in this playground is the Kubernetes Gateway API. A `Gateway` is the object that opens a listener (a port that accepts requests). An `HTTPRoute` is the object that tells the Gateway where to send the requests it receives. Its `backendRefs` list names Services and gives each one a `weight`. The Gateway controller (Envoy Gateway here) reads the `HTTPRoute` and splits requests by those weights.

Argo Rollouts does not know the Gateway API itself. It uses a traffic router plugin, a separate program that the controller downloads and starts. The plugin `argoproj-labs/gatewayAPI` reads and edits the `HTTPRoute` for the Rollout. The Argo Rollouts controller decides the weight; the plugin writes it into the `HTTPRoute`; Envoy Gateway applies it to live requests.

The playground bootstrap already installed the plugin: it added the program's download address to the `argo-rollouts-config` ConfigMap, gave the controller permission to edit `HTTPRoute` objects, and restarted the controller. Check what the cluster holds for `scout`:

<!-- astrona:playground:renew -->

```sh
kubectl -n starfleet get gateway,httproute,svc
```

The output is:

```text
NAME                                              CLASS   ADDRESS         PROGRAMMED   AGE
gateway.gateway.networking.k8s.io/scout-gateway   eg      10.96.107.155   True         14m

NAME                                              HOSTNAMES   AGE
httproute.gateway.networking.k8s.io/scout-route               14m

NAME                   TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/scout          ClusterIP   10.96.163.205   <none>        80/TCP    14m
service/scout-canary   ClusterIP   10.96.205.43    <none>        80/TCP    14m
```

The `ADDRESS` of your Gateway differs, because the cluster assigns it. `shuttle` already has this address in its `GATEWAY` environment variable. Two Services exist: `scout` selects the stable pods and `scout-canary` selects the canary pods. The `HTTPRoute` sends 100% of requests to `scout` and 0% to `scout-canary`. Both Services keep these roles, and the controller moves the pod selector of each one to the right ReplicaSet.

## Connect the Rollout to the HTTPRoute

The next step is the Rollout. The field `strategy.canary.trafficRouting.plugins` names the plugin and the `HTTPRoute` to edit. `stableService` and `canaryService` name the two Services in the route. The steps use `setWeight`, which now means a share of requests. Save this as `rollout-scout.yaml`:

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
              value: stable
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
        plugins:
          argoproj-labs/gatewayAPI:
            httpRoute: scout-route
            namespace: starfleet
      steps:
        - setWeight: 10
        - pause: {}
        - setWeight: 50
        - pause: {}
```

Apply it:

```sh
kubectl apply -f rollout-scout.yaml
```

The pod template did not change, so no release starts. The Rollout stays `Healthy` and the `HTTPRoute` still shows `scout=100` and `scout-canary=0`. Now start a release. Change the image to podinfo 6.15.0 and read the result after about 20 seconds:

```sh
kubectl argo rollouts set image scout scout=ghcr.io/stefanprodan/podinfo:6.15.0 -n starfleet
kubectl argo rollouts get rollout scout -n starfleet --no-color | head -16
kubectl -n starfleet get httproute scout-route -o jsonpath='{range .spec.rules[0].backendRefs[*]}{.name}={.weight}{"\n"}{end}'
```

The output is:

```text
rollout "scout" image updated
Name:            scout
Namespace:       starfleet
Status:          ॥ Paused
Message:         CanaryPauseStep
Strategy:        Canary
  Step:          1/4
  SetWeight:     10
  ActualWeight:  10
Images:          ghcr.io/stefanprodan/podinfo:6.14.0 (stable)
                 ghcr.io/stefanprodan/podinfo:6.15.0 (canary)
Replicas:
  Desired:       2
  Current:       3
  Updated:       1
  Ready:         3
  Available:     3
scout=90
scout-canary=10
```

Look at the numbers. The Rollout has three pods: two stable and one canary. A replica split of one canary pod out of three would be 33%. The weight is 10%, because the plugin wrote `weight: 10` into the `HTTPRoute`. The controller uses the pod count only to have enough capacity; the router decides the share of requests.

## Prove the share with real requests

A status line is not proof. Send 100 requests from `shuttle` to the Gateway and count the `version` field in each response. This helper function runs the loop inside the `shuttle` pod. Paste it into your terminal:

```sh
count_versions() {
  kubectl -n starfleet exec deploy/shuttle -- sh -c 'for i in $(seq 1 100); do curl -s "http://$GATEWAY/" | grep -o "\"version\": \"[^\"]*\""; done | sort | uniq -c'
}
count_versions
```

The result from one run is:

```text
  89 "version": "6.14.0"
  11 "version": "6.15.0"
```

Eleven requests out of 100 reached the canary, which is close to the 10% weight. The exact number changes from run to run, because the router picks a backend for each request at random according to the weights. Promote the Rollout past the first pause, wait about 20 seconds, and count again:

```sh
kubectl argo rollouts promote scout -n starfleet
count_versions
```

At 50% the output was:

```text
  50 "version": "6.14.0"
  50 "version": "6.15.0"
```

A second promotion runs the last pause. The Rollout sets the weight to 100%, the canary becomes the stable version, and the plugin sets the `HTTPRoute` back to `scout=100` and `scout-canary=0`:

```sh
kubectl argo rollouts promote scout -n starfleet
kubectl argo rollouts get rollout scout -n starfleet --no-color | head -8
```

After about 25 seconds the header showed `Status: ✔ Healthy`, `Step: 4/4` and `Images: ghcr.io/stefanprodan/podinfo:6.15.0 (stable)`.

You now know how a Rollout connects to a router. The `trafficRouting` block names a plugin and an `HTTPRoute`, the controller chooses the weight, and the plugin writes it into the route. The weight is a share of requests, proved by a count from `shuttle`, and the pod count is a separate matter. A weight alone still sends random users to the canary. To send only your own test requests there, a second rule must match a request header.

## Common pitfalls

> [!WARNING]
> - **Reading a weight as a pod ratio.** With a router, 10% is a share of requests. Three pods do not mean 33%.
> - **Trusting a short sample.** Ten requests can show zero or three canary responses at a 10% weight. Count at least 100.
> - **Forgetting the permissions.** The controller needs a role that lets it get and update `HTTPRoute` objects and get Services. Without it the plugin cannot write the weights. The playground bootstrap grants this role.
> - **Editing the route by hand during a release.** The plugin owns the weights of the two backends and writes them again at the next step.
