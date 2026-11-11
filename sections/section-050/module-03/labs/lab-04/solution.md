# Solution

Save this as `canary-scout-promotion.yaml`:

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
    - name: scout-approval
      type: confirm-promotion
      url: http://flagger-loadtester.starfleet/gate/check
      timeout: 5s
    - name: load-test
      type: rollout
      url: http://flagger-loadtester.starfleet/
      timeout: 5s
      metadata:
        cmd: hey -z 1m -q 10 -c 2 http://scout-canary.starfleet/
```

Apply it:

```sh
kubectl apply -f canary-scout-promotion.yaml
```

Close the stored gate and trigger an image change:

```sh
kubectl -n starfleet exec deploy/shuttle -c shuttle -- curl -fsS --max-time 10 \
  -d '{"name":"scout","namespace":"starfleet"}' http://flagger-loadtester.starfleet/gate/close
kubectl -n starfleet set image deployment/scout scout=ghcr.io/stefanprodan/podinfo:6.15.0
kubectl -n starfleet wait canary/scout --for=jsonpath='{.status.phase}'=WaitingPromotion --timeout=600s
kubectl -n starfleet get virtualservice scout -o yaml
kubectl -n starfleet get deployment scout-primary -o yaml
CANARY_UID=$(kubectl -n starfleet get canary scout -o jsonpath='{.metadata.uid}')
kubectl -n starfleet get events --field-selector "involvedObject.uid=$CANARY_UID" \
  -o json > /tmp/scout-promotion-events.json
```

The route should send 50 percent to each destination while the primary stays on `6.14.0`. If the waiting event has not arrived, repeat the event capture before opening the gate. The saved events must contain `waiting for promotion approval scout-approval`.

Open the gate and verify the release:

```sh
kubectl -n starfleet exec deploy/shuttle -c shuttle -- curl -fsS --max-time 10 \
  -d '{"name":"scout","namespace":"starfleet"}' http://flagger-loadtester.starfleet/gate/open
kubectl -n starfleet wait canary/scout --for=jsonpath='{.status.phase}'=Succeeded --timeout=600s
kubectl -n starfleet rollout status deploy/scout-primary --timeout=180s
kubectl -n starfleet exec deploy/shuttle -c shuttle -- curl -fsS http://scout.starfleet/
```

The response must report `6.15.0`. Flagger continues health checks during the approval wait; an unhealthy candidate can still roll back.

Kubernetes may combine similar events and replace the approval message. The grader also reads Flagger’s controller logs to establish that approval followed the recorded wait and preceded promotion.
