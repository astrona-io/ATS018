# Solution Walkthrough

Install the starter chart, add the required template field and values, then verify the upgraded release. A release is an installed copy of a Helm chart. A revision records one release operation.

| Goal | Where it lives | Command or file |
| --- | --- | --- |
| Resource structure | Chart templates | `scout/templates/deployment.yaml` |
| Environment settings | Values override | `production-values.yaml` |
| Package identity | Chart metadata | `scout/Chart.yaml` |

## The feedback loop

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-010/module-02/labs/lab-01
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

The `chart-release` check needs work at startup. These are expected conditions, not a captured grading transcript.

## Step 1: Install the baseline

Use the terminal where `kubectl` points at the lab. Read the starter metadata and values before changing them:

```sh
export PATH="$HOME/.astrona/bin:$PATH"
cd ~/resources
cat scout/Chart.yaml
cat scout/values.yaml
helm lint ./scout
helm template scout ./scout --namespace starfleet-production
helm install scout ./scout --namespace starfleet-production --wait=watcher --timeout 180s
helm history scout --namespace starfleet-production
```

Look for the initial revision with image `6.14.0`. No full check is ready yet: the chart requirements need the later upgrade.

## Step 2: Complete and deploy the chart

Save this as `~/resources/scout/templates/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}
  labels:
    app.kubernetes.io/instance: {{ .Release.Name }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app.kubernetes.io/instance: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app.kubernetes.io/instance: {{ .Release.Name }}
    spec:
      containers:
        - name: scout
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          ports:
            - name: http
              containerPort: 9898
          env:
            - name: PODINFO_UI_MESSAGE
              value: {{ .Values.message | quote }}
          readinessProbe:
            httpGet:
              path: /readyz
              port: http
          resources:
            requests:
              cpu: 10m
              memory: 32Mi
            limits:
              memory: 128Mi
```

`metadata.name` and the labels use the release name. The selector matches the pod labels. `replicas` reads the requested count, and `image` combines the repository and tag. The new `env` entry reads `.Values.message`; `quote` makes it a string. The probe checks `/readyz` on the named port. Resource requests and the memory limit keep the small workload bounded.

Save this as `~/resources/scout/Chart.yaml`:

```yaml
apiVersion: v2
name: scout
description: A small podinfo workload for release practice
type: application
version: 0.2.0
appVersion: "6.15.0"
```

`apiVersion` selects the chart format, and `name` identifies the chart. `type: application` describes an installable workload chart. `version` identifies the chart package; `appVersion` describes the application without changing the image.

Save this as `~/resources/production-values.yaml`:

```yaml
replicaCount: 2
image:
  tag: "6.15.0"
message: release-ready
```

`replicaCount` sets two pods. `image.tag` selects the new application image while retaining the default repository. `message` supplies the environment variable's value.

Check the chart and rendered Deployment:

```sh
cd ~/resources
helm lint ./scout -f production-values.yaml
helm template scout ./scout --namespace starfleet-production -f production-values.yaml
```

Look for two replicas, image `6.15.0` and the required message.

Apply it:

```sh
helm upgrade --install scout ./scout --namespace starfleet-production --create-namespace -f production-values.yaml --wait=watcher --timeout 180s
```

Then check the result:

```sh
helm list --namespace starfleet-production
kubectl -n starfleet exec deploy/shuttle -- curl -fsS http://scout.starfleet-production/
```

Look for chart `scout-0.2.0`, application version `6.15.0` and message `release-ready`.

The watch terminal shows the `chart-release` check passing. If pods are still settling, wait for the Deployment with `kubectl -n starfleet-production rollout status deploy/scout --timeout=180s`.

## Finish

The chart-release check compares the saved chart and values to the deployed manifest, then checks the live application response. Stop the watch and submit the final attempt when it passes. Practice history-based recovery in the next independent lab.
