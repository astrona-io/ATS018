# Solution

Start with the overview, then take one application at a time. For each one, find which component reports the problem, then fix it in the place where the fault lives.

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch -c sections/section-020/module-03/labs/lab-01
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Step 1: read all three applications

```sh
kubectl -n argocd get applications
```

Each `Application` shows a sync status and a health status. `scout-path` has the status `Unknown` or an error, and the other two are not `Synced` and `Healthy`. To see why, read the conditions and the last operation of each one:

```sh
kubectl -n argocd get application scout-path -o jsonpath='{.status.conditions}'
kubectl -n argocd get application scout-reject -o jsonpath='{.status.operationState.message}'
kubectl -n argocd get application scout-image -o jsonpath='{.status.health.status}'
```

You get three different faults:

- `scout-path`: the condition is a `ComparisonError`. The repo server (the Argo CD component that renders manifests from Git) cannot find the folder `paths`.
- `scout-reject`: the sync operation fails because the Kubernetes API server rejects the Deployment. The message says that the container port `99999` must be between 1 and 65535.
- `scout-image`: the sync works, but the health status is `Progressing` or `Degraded`, because the pods cannot pull the image `ghcr.io/stefanprodan/podinfo:6.51.0`.

## Step 2: fix scout-path in the Application

The fault is in the `Application` itself: the folder in Git is `path`, not `paths`. The `Application` is not stored in Git, so change it with `kubectl`:

```sh
kubectl -n argocd patch application scout-path --type merge -p '{"spec":{"source":{"path":"path"}}}'
```

## Step 3: fix scout-reject and scout-image in Git

Both faults are in files in the repository. A manual change to the live objects would be reverted by self-heal, so commit the fix. Clone the repository:

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

Keep the port-forward running and open a second terminal:

```sh
git clone http://platform:starfleet-gitops@127.0.0.1:3000/starfleet/scout-faults.git
cd scout-faults
```

In `reject/scout.yaml`, change `containerPort: 99999` to `containerPort: 9898`. In `image/scout.yaml`, change the image tag `6.51.0` to `6.15.0`. Then commit and push:

```sh
git commit -am "Fix the rejected port and the image tag"
git push origin main
```

## Step 4: stop the old retry of scout-reject

The failed sync of `scout-reject` keeps retrying with the commit it started on. A running operation keeps its revision, so the new commit waits until the retries stop. Terminate the operation:

```sh
argocd app terminate-op scout-reject
```

If you do not use the `argocd` tool, set the phase of the operation yourself:

```sh
kubectl -n argocd patch application scout-reject --type merge -p '{"status":{"operationState":{"phase":"Terminating"}}}'
```

Ask Argo CD to read Git again for all three applications, instead of waiting for the next poll:

```sh
kubectl -n argocd annotate application scout-path scout-reject scout-image argocd.argoproj.io/refresh=hard --overwrite
```

## Step 5: check the result

Wait until all three are `Synced` and `Healthy`:

```sh
kubectl -n argocd get applications
```

Then send a request from `shuttle` to each namespace:

```sh
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet-path/
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet-reject/
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout.starfleet-image/
```

Each JSON response must show `"version": "6.15.0"`.

Stop the watch with Ctrl-C, then run the plain command once:

```sh
astrona submit -c sections/section-020/module-03/labs/lab-01
```

## Common mistakes

- Running `kubectl edit` or `kubectl set image` on the live Deployment. Self-heal reverts it, and the file in Git stays wrong.
- Pushing the fix and waiting. A retrying operation keeps its old revision, so `scout-reject` stays stuck until you terminate the operation.
- Turning off `selfHeal` or `prune` to make drift disappear. The grader checks that both are still on.
- Changing the `path` of `scout-reject` or `scout-image` to a working folder such as `path`. The grader checks the folder.
