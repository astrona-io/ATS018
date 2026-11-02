# Solution

## Step 1: create the Canary

A `Canary` names the target Deployment and holds the release policy. Flagger checks every 15 seconds, moves 10 percent of the requests per step up to 50 percent, and allows 3 failed checks. The `rollout` webhook calls the load tester, so the canary pods receive requests and the success rate has values.

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
```

The status is `Initialized`. Flagger created `scout-primary` and scaled `scout` to zero replicas. Wait until the status is `Initialized`, and then wait about one more minute so Prometheus can scrape the first Istio metrics, before you release a new image. A release started earlier can fail with `no values found for istio metric` and roll back.

## Step 2: promote 6.15.0

Change the image of the `scout` Deployment. This is a new pod template, so Flagger starts a release:

```sh
kubectl -n starfleet set image deploy/scout scout=ghcr.io/stefanprodan/podinfo:6.15.0
kubectl -n starfleet get canary scout --watch
```

The weight rises from 10 to 50, then the status becomes `Succeeded`. Press `Ctrl+C`. A `no values found` warning at the first step is normal: Flagger halts until the load tester has produced requests.

## Step 3: release the faulty template

Add `--random-error` to the container command. The pods stay ready, but some responses have status 400, 409 or 500:

```sh
kubectl -n starfleet patch deploy scout --type=json -p='[{"op":"add","path":"/spec/template/spec/containers/0/command","value":["./podinfo","--port=9898","--random-error"]}]'
kubectl -n starfleet get canary scout --watch
```

The weight stays at 10 while the checks fail. After the third failed check the status becomes `Failed` and the weight returns to 0. Read the reason and prove the primary pods still serve:

```sh
kubectl -n starfleet describe canary scout | sed -n '/Events:/,$p' | tail -4
kubectl -n starfleet exec deploy/shuttle -c shuttle -- curl -s http://scout.starfleet/ | grep -E '"(version|message)"'
```

The events show a success rate below 99 percent and `Rolling back`. The response still shows version `6.15.0`. Do not lower `thresholdRange.min` or `threshold`: that would promote the faulty version.

## Step 4: release the fix

Flagger does not repair the Deployment. Remove the faulty command and set the message `fixed`:

```sh
kubectl -n starfleet patch deploy scout --type=json -p='[{"op":"remove","path":"/spec/template/spec/containers/0/command"},{"op":"add","path":"/spec/template/spec/containers/0/env","value":[{"name":"PODINFO_UI_MESSAGE","value":"fixed"}]}]'
kubectl -n starfleet get canary scout --watch
```

After about three minutes the status is `Succeeded`. Check the result and run `astrona submit`:

```sh
kubectl -n starfleet exec deploy/shuttle -c shuttle -- curl -s http://scout.starfleet/ | grep -E '"(version|message)"'
```

The response shows version `6.15.0` and the message `fixed`.
