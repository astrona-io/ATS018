# Solution

On `terminal`, connect the existing EventListener to a binding and a template, then grant its account permission to create runs. An EventListener receives requests; the binding extracts params, and the template defines the PipelineRun to create. A PipelineRun is one execution of a Pipeline.

| Goal | Resource | Account |
| --- | --- | --- |
| Extract request fields | TriggerBinding `scout-push` | `scout-listener` reads it |
| Create a run with params | TriggerTemplate `scout-check` | `scout-listener` creates it |
| Execute the Tasks | PipelineRun of `scout-check` | `scout-runner` runs them |

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-050/module-02/labs/lab-02
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step. The checks are `binding`, `template`, `listener-access`, `student-request` and `event-runs`. All should fail before you make changes. A check that sends requests may take longer while it waits for a run.

## Step 1: inspect the listener

Read the listener and its account's permission. A ServiceAccount is a Kubernetes identity for pods. Role-based access control (RBAC) decides what that identity can do.

```sh
kubectl -n starfleet get eventlistener scout-push -o yaml
kubectl -n starfleet get pipeline scout-check -o yaml
kubectl -n starfleet auth can-i create pipelineruns.tekton.dev --as=system:serviceaccount:starfleet:scout-listener
```

Look for references to `scout-unwired` and a denied create permission. The Pipeline already accepts `revision` and `repository`. No watch check passes from inspection alone.

## Step 2: extract both request fields

Save this as `triggerbinding-scout-push.yaml`:

```yaml
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerBinding
metadata:
  name: scout-push
  namespace: starfleet
spec:
  params:
    - name: revision
      value: $(body.ref)
    - name: repository
      value: $(body.repository.full_name)
```

`apiVersion` and `kind` select the Triggers resource. `metadata` names it in `starfleet`. Each entry in `spec.params` assigns a name to a request value: `body.ref` reads the branch reference, and `body.repository.full_name` reads the nested repository name.

Apply it:

```sh
kubectl apply -f triggerbinding-scout-push.yaml
```

The watch terminal should now show `binding` passing. The other checks still need a template and a working listener.

## Step 3: define the created run

Save this as `triggertemplate-scout-check.yaml`:

```yaml
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerTemplate
metadata:
  name: scout-check
  namespace: starfleet
spec:
  params:
    - name: revision
    - name: repository
  resourcetemplates:
    - apiVersion: tekton.dev/v1
      kind: PipelineRun
      metadata:
        generateName: scout-check-
        namespace: starfleet
      spec:
        pipelineRef:
          name: scout-check
        params:
          - name: revision
            value: $(tt.params.revision)
          - name: repository
            value: $(tt.params.repository)
        taskRunTemplate:
          serviceAccountName: scout-runner
```

`spec.params` declares the binding's names. `resourcetemplates` contains the resource the listener will create. Its `generateName` lets Kubernetes assign a fresh name to each run. `pipelineRef` selects the existing Pipeline. Each `tt.params` expression substitutes a bound value into the run. `taskRunTemplate.serviceAccountName` selects the identity for its Tasks; it does not grant the listener any permissions.

Apply it:

```sh
kubectl apply -f triggertemplate-scout-check.yaml
```

The watch terminal should now show `binding` and `template` passing. The template check also confirms that you kept the supplied Pipeline unchanged. A template's existence does not prove that its embedded resource can be created; sending a request tests that path.

## Step 4: grant access and wire the listener

A RoleBinding grants permissions in one namespace. The installed ClusterRole `tekton-triggers-eventlistener-roles` includes the reads and run creation the listener needs. Save this as `rolebinding-scout-listener-runs.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: scout-listener-runs
  namespace: starfleet
subjects:
  - kind: ServiceAccount
    name: scout-listener
    namespace: starfleet
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: tekton-triggers-eventlistener-roles
```

`subjects` selects `scout-listener` in `starfleet`. `roleRef` selects the installed ClusterRole. Although the referenced role is a ClusterRole, this RoleBinding grants its permissions only in `starfleet`. The existing ClusterRoleBinding already grants access to cluster-scoped Triggers objects.

Apply it:

```sh
kubectl apply -f rolebinding-scout-listener-runs.yaml
```

Save this as `eventlistener-scout-push.yaml`:

```yaml
apiVersion: triggers.tekton.dev/v1beta1
kind: EventListener
metadata:
  name: scout-push
  namespace: starfleet
spec:
  serviceAccountName: scout-listener
  triggers:
    - name: push
      bindings:
        - ref: scout-push
      template:
        ref: scout-check
```

`serviceAccountName` selects the listener's identity. The trigger `push` now references the binding and template you created. It has no interceptor, so both the sample request and requests with other branch and repository values can reach the template.

Apply it:

```sh
kubectl apply -f eventlistener-scout-push.yaml
```

Then check the result:

```sh
kubectl -n starfleet rollout restart deploy/el-scout-push
kubectl -n starfleet rollout status deploy/el-scout-push --timeout=180s
kubectl -n starfleet auth can-i create pipelineruns.tekton.dev --as=system:serviceaccount:starfleet:scout-listener
```

Restarting the listener makes its pod load the new binding, template and listener configuration. Look for an available listener Deployment and an allowed create permission. The watch terminal should show `listener-access` passing. It should also show `event-runs` passing once its two requests create successful runs with their own values. That check removes its own runs afterward.

## Step 5: send the sample request from the cluster

The listener's Service is reachable inside the cluster. Send the JavaScript Object Notation (JSON) body from `shuttle`:

```sh
kubectl -n starfleet exec deploy/shuttle -- curl --fail-with-body --silent --show-error --max-time 20 \
  -H 'Content-Type: application/json' \
  -d '{"ref":"refs/heads/main","repository":{"full_name":"starfleet/scout-app"}}' \
  http://el-scout-push.starfleet.svc:8080
kubectl -n starfleet get pipelineruns -l triggers.tekton.dev/eventlistener=scout-push
```

The response should include an `eventID`. Acceptance alone does not prove that a run succeeded. In the run list, find the new `scout-check-` name. Replace `<RUN_NAME>` with that name:

```sh
kubectl -n starfleet get pipelinerun <RUN_NAME> -o yaml
kubectl -n starfleet wait --for=condition=Succeeded pipelinerun/<RUN_NAME> --timeout=120s
```

Check that the run's `revision` is `refs/heads/main`, its `repository` is `starfleet/scout-app`, and its task service account is `scout-runner`. Its label `triggers.tekton.dev/triggers-eventid` should match the response's `eventID`. The watch terminal should now show `student-request` passing, along with the other four checks. Leave this run in the cluster.

## If a check stays red

For `binding` or `template`, check the exact param names and substitution prefixes. The binding uses `body`; the template uses `tt.params`. A literal sample value in the template cannot pass `event-runs` with its different payloads.

For `listener-access`, check the RoleBinding subject and namespace. The listener uses `scout-listener`; the Tasks use `scout-runner`. Giving the run account permission does not repair the listener.

For `student-request` or `event-runs`, inspect the listener logs and the failed run:

```sh
kubectl -n starfleet logs deploy/el-scout-push --tail=50
kubectl -n starfleet get pipelineruns -o yaml
```

Look for missing binding or template references, forbidden create requests, and the run's `Succeeded` condition message. If `curl` cannot connect, check that the listener Deployment is available and that you sent the request from `shuttle` to the Service on port `8080`.

## Step 6: submit

Stop the watch with Ctrl-C, then run the plain command once:

```sh
astrona submit --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-050/module-02/labs/lab-02
```

This finishes the attempt and deletes the lab. The five checks cover field extraction, the template, listener wiring and access, your sample request and two new requests with different values.
