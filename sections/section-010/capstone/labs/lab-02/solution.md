# Solution Walkthrough

Build the production Helm release and the staging Kustomize overlay from the supplied files. A release is an installed copy of a Helm chart. A revision records one release operation.

| Goal | Where it lives | Command or file |
| --- | --- | --- |
| Resource structure | Chart templates | `scout/templates/deployment.yaml` |
| Environment settings | Values override | `production-values.yaml` |
| Package identity | Chart metadata | `scout/Chart.yaml` |
| Staging settings | Kustomize overlay | `scout-overlay/overlays/staging` |

## The feedback loop

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-010/capstone/labs/lab-02
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

The `chart-release` and `overlay` checks need work at startup. These are expected conditions, not a captured grading transcript.

## Step 1: Inspect the starting files

Use the lab terminal:

```sh
export PATH="$HOME/.astrona/bin:$PATH"
cd ~/resources
cat scout/Chart.yaml
cat scout/values.yaml
kubectl kustomize scout-overlay/overlays/staging
```

The starter chart has no message environment variable. The overlay only includes its base; it does not yet set the required namespace, image or generated configuration. No check is ready yet.

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
message: chart-production
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

Look for chart `scout-0.2.0`, application version `6.15.0` and message `chart-production`.

The watch terminal shows the `chart-release` check passing. If pods are still settling, wait for the Deployment with `kubectl -n starfleet-production rollout status deploy/scout --timeout=180s`.

## Step 3: Complete the staging overlay

A Kustomize base holds shared manifests. An overlay includes the base and applies environment changes. Save this as `~/resources/scout-overlay/overlays/staging/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: starfleet-staging
resources:
  - ../../base
images:
  - name: ghcr.io/stefanprodan/podinfo
    newTag: 6.15.0
replicas:
  - name: scout
    count: 1
configMapGenerator:
  - name: scout-settings
    literals:
      - PODINFO_UI_MESSAGE=overlay-staging
patches:
  - path: deployment-env.yaml
```

`resources` includes the unchanged base, and `namespace` sets the destination. `images` changes the application tag. `replicas` sets one pod. `configMapGenerator` creates the settings object with a content hash in its name. `patches` adds the environment reference to the Deployment.

Save this as `~/resources/scout-overlay/overlays/staging/deployment-env.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scout
spec:
  template:
    spec:
      containers:
        - name: scout
          envFrom:
            - configMapRef:
                name: scout-settings
```

The patch selects Deployment `scout` and merges the container named `scout`. Its `envFrom` loads the generated ConfigMap. Kustomize replaces `scout-settings` with the generated name in the rendered Deployment.

Render before applying:

```sh
kubectl kustomize scout-overlay/overlays/staging
```

Look for namespace `starfleet-staging`, image `6.15.0`, one replica and a generated ConfigMap name that matches the Deployment reference.

Apply it:

```sh
kubectl apply -k scout-overlay/overlays/staging
```

Then check the result:

```sh
kubectl -n starfleet-staging rollout status deploy/scout --timeout=180s
kubectl -n starfleet exec deploy/shuttle -- curl -fsS http://scout.starfleet-staging/
kubectl -n starfleet exec deploy/shuttle -- curl -fsS http://scout.starfleet-production/
```

Both responses should show version `6.15.0`. Staging must show `overlay-staging`; production must still show `chart-production`.

The watch terminal shows both `chart-release` and `overlay` passing. Stop the watch with Ctrl-C, then run the plain command once:

```sh
astrona submit --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-010/capstone/labs/lab-02
```

## If a check stays red

- **chart-release:** Check the saved chart, values path and Helm namespace. Adding a values key without using it in the template leaves the message unchanged. Read the rendered environment variable.
- **overlay:** Check the namespace and patch container name. Keep the generator hash enabled and use the generated reference through `envFrom`. Apply the saved overlay again if its files differ from the cluster.
