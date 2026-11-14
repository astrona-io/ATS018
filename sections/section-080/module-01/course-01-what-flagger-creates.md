# What Flagger Creates For A Deployment

A Deployment replaces pods with a rolling update. It has no idea whether the new pods return errors. To release safely you need two versions running at once and a way to split the requests between them. This part creates a `Canary` and shows the objects Flagger builds so that this split is possible.

## One Deployment before the Canary

Look at what `scout` is before Flagger touches it. It is one Deployment with one replica, one Service and no mesh objects.

<!-- astrona:playground:renew -->

```sh
kubectl -n starfleet get deploy
```

```text
NAME                                 READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/flagger-loadtester   1/1     1            1           14s
deployment.apps/scout                1/1     1            1           32s
deployment.apps/shuttle              1/1     1            1           32s
```

The playground output may show a different age. A `Canary` is the Flagger resource that names a target workload and describes how to release it. Its `targetRef` points at the Deployment, `service` describes the Service Flagger manages, and `analysis` describes the checks. Here Flagger checks every 15 seconds, allows 3 failed checks, raises the canary weight by 10 percent per step and stops at 50 percent. The `load-test` webhook sends test requests to the canary while it is analysed.

Save this as `canary-scout.yaml`:

```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: scout
  namespace: starfleet
spec:
  provider: istio
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: scout
  progressDeadlineSeconds: 120
  service:
    port: 80
    targetPort: http
  analysis:
    interval: 15s
    threshold: 3
    maxWeight: 50
    stepWeight: 10
    metrics:
      - name: request-success-rate
        thresholdRange:
          min: 99
        interval: 30s
    webhooks:
      - name: load-test
        type: rollout
        url: http://flagger-loadtester.starfleet/
        timeout: 5s
        metadata:
          cmd: "hey -z 1m -q 10 -c 2 http://scout-canary.starfleet/"
```

Apply it:

```sh
kubectl apply -f canary-scout.yaml
```

Then check the result after about 45 seconds:

```sh
kubectl -n starfleet get canary scout
kubectl -n starfleet get deploy,svc,virtualservice,destinationrule
```

```text
NAME    STATUS        WEIGHT   LASTTRANSITIONTIME
scout   Initialized   0        2026-11-01T20:40:19Z
NAME                                 READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/flagger-loadtester   1/1     1            1           66s
deployment.apps/scout                0/0     0            0           84s
deployment.apps/scout-primary        1/1     1            1           39s
deployment.apps/shuttle              1/1     1            1           84s

NAME                         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/flagger-loadtester   ClusterIP   10.96.176.148   <none>        80/TCP    66s
service/scout                ClusterIP   10.96.18.213    <none>        80/TCP    84s
service/scout-canary         ClusterIP   10.96.17.117    <none>        80/TCP    39s
service/scout-primary        ClusterIP   10.96.201.235   <none>        80/TCP    39s

NAME                                       GATEWAYS   HOSTS       AGE
virtualservice.networking.istio.io/scout   ["mesh"]   ["scout"]   23s

NAME                                                HOST            AGE
destinationrule.networking.istio.io/scout-canary    scout-canary    24s
destinationrule.networking.istio.io/scout-primary   scout-primary   24s
```

The `Canary` status is `Initialized`. The output shows what the Flagger controller did to the `scout` Deployment.

## Who owns which object

The Flagger controller created `scout-primary`, a copy of the `scout` pod template, and scaled `scout` to zero replicas. The primary Deployment now serves all traffic. The original `scout` Deployment stays as the place where you edit the pod template. When you change it, Flagger starts the canary pods from it.

Flagger also created two extra Services, `scout-primary` and `scout-canary`, and two Istio `DestinationRule` objects, one for each. A `DestinationRule` defines the subsets and policies for traffic to a host. The Service `scout` still exists, and Istio now routes requests for it through the `VirtualService` that Flagger created. A `VirtualService` is the Istio object that holds the routing rules and the weight of each destination. Check the weights:

```sh
kubectl -n starfleet get virtualservice scout -o jsonpath='{.spec.http[0].route}{"\n"}'
```

```text
[{"destination":{"host":"scout-primary"},"weight":100},{"destination":{"host":"scout-canary"},"weight":0}]
```

Istio sidecar proxies send 100 percent of the requests for `scout` to the primary pods. During a release, Flagger edits these two weights and nothing else.

You now know what Flagger builds: a primary Deployment, a canary Deployment, two Services, two `DestinationRule` objects and one `VirtualService`. The open question is what makes Flagger start a release, and when it decides to promote.

## Common pitfalls

> [!WARNING]
> - Do not edit `scout-primary` or the generated Services and `VirtualService`. Flagger owns them and overwrites your change. Edit the `scout` Deployment.
> - Do not expect the `scout` Deployment to show running pods. It is scaled to zero between releases, and `0/0` is correct.
> - A `Canary` stays `Initializing` until the primary pods are ready. If sidecar injection is off in the namespace, the pods have no proxy and the mesh weights do nothing.
