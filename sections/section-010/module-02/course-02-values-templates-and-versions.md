# Values, Templates And Versions

The `scout` release needs two replicas, image `6.15.0` and the message `release-ready`. A values file can set the replica count and image because the chart's Deployment template already reads them. It cannot set the message yet: a value has no effect until a template uses it.

A release is an installed copy of a chart. These commands use a release named `scout` in `starfleet-production`, installed from the chart directory `scout` with default image `6.14.0`. Keep its Service template and default values in place. An override file changes selected defaults for one environment.

<!-- astrona:playground:renew -->

Save this as `production-values.yaml`:

```yaml
replicaCount: 2
image:
  tag: "6.15.0"
message: release-ready
```

`replicaCount` changes the requested pod count. `image.tag` overrides only the nested tag; the repository stays at its default. `message` needs a matching template expression. Edit the template when you need a field that the chart does not expose, or when the structure of the rendered objects must change. Use values when the chart already exposes the setting.

Save this as `scout/templates/deployment.yaml`:

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

The new `env` list passes an environment variable to the container. Podinfo reads `PODINFO_UI_MESSAGE` and returns it in responses. The template reads `.Values.message`, and `quote` renders it as a quoted string. The other fields retain the pod selector, image, port, readiness probe and resource settings.

The chart has changed, so give the package a new version. The intended application version changes too. Save this as `scout/Chart.yaml`:

```yaml
apiVersion: v2
name: scout
description: A small podinfo workload for release practice
type: application
version: 0.2.0
appVersion: "6.15.0"
```

`version: 0.2.0` identifies this chart change. `appVersion: "6.15.0"` describes the intended application. The container still gets its image from the template and `image.tag`; changing metadata alone cannot upgrade it.

Check the exact combination you will deploy:

```sh
helm lint ./scout -f production-values.yaml
helm template scout ./scout --namespace starfleet-production -f production-values.yaml
```

Look for two replicas, image `6.15.0` and `PODINFO_UI_MESSAGE` set to `release-ready`. Linting cannot tell you that a custom values key is unused, so read the rendered fields as well.

Apply it:

```sh
helm upgrade --install scout ./scout --namespace starfleet-production --create-namespace -f production-values.yaml --wait=watcher --timeout 180s
```

`upgrade --install` upgrades an existing release or installs it if it is absent. `--create-namespace` creates the destination namespace when this command takes the install path. Helm creates a new revision, a numbered record of the release operation. Always pass the intended values file so the operation is repeatable.

Then check the result:

```sh
helm list --namespace starfleet-production
helm history scout --namespace starfleet-production
kubectl -n starfleet-production rollout status deploy/scout --timeout=180s
kubectl -n starfleet exec deploy/shuttle -- curl -fsS http://scout.starfleet-production/
```

Look for chart `scout-0.2.0`, application version `6.15.0` and a deployed revision. The response must contain version `6.15.0` and message `release-ready`. Kubernetes runs the image and environment settings in the rendered Deployment.

Helm merges chart defaults with values files. If you pass several `-f` files, the rightmost file wins for a shared key. A `--set` value overrides values files for that key. Keep lasting environment settings in a file so another operator can reproduce them.

A values edit changes inputs; a template edit changes what those inputs can produce. Chart metadata records package and application intent, while release history records what Helm actually installed. That history gives you a way to recover an earlier configuration.

## Common pitfalls

> [!WARNING]
> - **Adding an unused key.** A `message` value does nothing until the template reads it.
> - **Editing templates for every environment.** Use override files for settings the chart already exposes.
> - **Changing only appVersion.** Update `image.tag` when this template needs a new image.
> - **Skipping a chart version change.** Record template changes in `Chart.yaml`, even when working with a local chart.
