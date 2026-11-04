# Solution Walkthrough

Install the starter chart, add the required template field and values, then use release history to recover the desired configuration. A release is an installed copy of a Helm chart. A revision records one release operation.

| Goal | Where it lives | Command or file |
| --- | --- | --- |
| Resource structure | Chart templates | `scout/templates/deployment.yaml` |
| Environment settings | Values override | `production-values.yaml` |
| Package identity | Chart metadata | `scout/Chart.yaml` |
| Recovery | Stored release revisions | `helm history`, `helm rollback` |

## The feedback loop

Run grading from the host terminal where you started the lab. Re-run it after each change:

```sh
astrona submit --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-010/module-02/labs/lab-01
```

The `chart-release` and `rollback` checks need work at startup. These are expected conditions, not a captured grading transcript.

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

Look for the initial revision with image `6.14.0`. No full check is ready yet: the chart and rollback requirements need the later operations.

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

Run the check from the host terminal:

```sh
astrona submit --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-010/module-02/labs/lab-01
```

The `chart-release` check should now pass. If pods are still settling, wait for the Deployment with `kubectl -n starfleet-production rollout status deploy/scout --timeout=180s` and submit again.

## Step 3: Upgrade once and roll back

Create the temporary revision without changing the desired values file:

```sh
helm upgrade --install scout ./scout --namespace starfleet-production -f production-values.yaml --set message=temporary --wait=watcher --timeout 180s
helm history scout --namespace starfleet-production
kubectl -n starfleet exec deploy/shuttle -- curl -fsS http://scout.starfleet-production/
```

Look for revision 3 and message `temporary`. The chart check needs the desired message restored. In the required clean sequence, revision 2 contains that message. Roll back to it:

```sh
helm rollback scout 2 --namespace starfleet-production --wait=watcher --timeout 180s
helm history scout --namespace starfleet-production
kubectl -n starfleet-production rollout status deploy/scout --timeout=180s
kubectl -n starfleet exec deploy/shuttle -- curl -fsS http://scout.starfleet-production/
```

Look for a new deployed revision that records the rollback to 2. The response should show version `6.15.0` and message `release-ready` again. The saved chart and values still describe this desired configuration.

Run the check from the host terminal:

```sh
astrona submit --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-010/module-02/labs/lab-01
```

Both `chart-release` and `rollback` should now pass.

## If a check stays red

- **chart-release:** Confirm that the terminal files are under `~/resources` and that the release is in `starfleet-production`. A saved template that differs from the installed one needs a Helm operation, not a live Deployment edit.
- **rollback:** Read history. Revision 1 must be the starter install, revision 2 the desired upgrade and revision 3 the temporary change. The latest operation must roll back to 2. If you added extra upgrades before establishing this sequence, restart the disposable lab and follow the sequence once.
