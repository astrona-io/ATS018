# Pass A Step Output Through A Checksum Check

A Workflow step can produce a value that a later step consumes. Argo stores an output parameter in the Workflow status, so you can compare the declared dependency with the value the run actually passed. A checksum is a useful example: changing one byte changes the expected digest.

## Insert a group between two steps

In a `steps` template, each outer list entry is a group. A new group waits for the previous group to finish. Insert the checksum in its own group between preparation and publication; putting it beside publication would let them run concurrently.

<!-- astrona:playground:renew -->

Save this as `workflowtemplate-probe-release.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: probe-release
  namespace: starfleet
spec:
  entrypoint: main
  serviceAccountName: workflow-runner
  templates:
    - name: main
      steps:
        - - name: prepare
            template: prepare
        - - name: checksum
            template: checksum
            arguments:
              parameters:
                - name: manifest
                  value: "{{steps.prepare.outputs.parameters.manifest}}"
        - - name: publish
            template: publish
            arguments:
              parameters:
                - name: checksum
                  value: "{{steps.checksum.outputs.parameters.checksum}}"
    - name: prepare
      container:
        image: alpine:3.23
        command: [sh, -c]
        args: ["printf '%s' 'release=probe-v2' > /tmp/manifest"]
      outputs:
        parameters:
          - name: manifest
            valueFrom:
              path: /tmp/manifest
    - name: checksum
      inputs:
        parameters:
          - name: manifest
      container:
        image: alpine:3.23
        command: [sh, -c]
        env:
          - name: MANIFEST
            value: "{{inputs.parameters.manifest}}"
        args:
          - printf '%s' "$MANIFEST" | sha256sum | cut -d ' ' -f 1 > /tmp/checksum
      outputs:
        parameters:
          - name: checksum
            valueFrom:
              path: /tmp/checksum
    - name: publish
      inputs:
        parameters:
          - name: checksum
      container:
        image: alpine:3.23
        command: [echo]
        args: ["checksum={{inputs.parameters.checksum}}"]
```

The checksum step receives the parameter as an environment variable. Quoting `"$MANIFEST"` prevents shell expansion and word splitting of the value. `printf '%s'` preserves the bytes without adding the newline that `echo` usually adds. The file named in `valueFrom.path` must exist inside the step container when it finishes.

Apply the template, then save the name of this particular run:

```sh
kubectl apply -f workflowtemplate-probe-release.yaml
RUN=$(argo submit -n starfleet --from workflowtemplate/probe-release -o name)
kubectl -n starfleet wait --for=jsonpath='{.status.phase}'=Succeeded "workflow/$RUN" --timeout=180s
argo get -n starfleet "$RUN"
argo logs -n starfleet "$RUN"
```

The tree should show preparation, checksum and publication in three consecutive groups. A run submitted before the edit retains its old template; submit a new run to test the change.

## Compare the output with the input

Read the Pod nodes from the saved run. `status.nodes` is a map keyed by generated node IDs, so select nodes by their `type` and `templateName`:

```sh
kubectl -n starfleet get workflow "$RUN" -o json > probe-release-run.json
jq -r '.status.nodes[] | select(.type == "Pod") | [.templateName, .phase, .startedAt, .finishedAt] | @tsv' probe-release-run.json
INPUT=$(jq -r '.status.nodes[] | select(.type == "Pod" and .templateName == "prepare") | .outputs.parameters[] | select(.name == "manifest") | .value' probe-release-run.json)
ACTUAL=$(jq -r '.status.nodes[] | select(.type == "Pod" and .templateName == "checksum") | .outputs.parameters[] | select(.name == "checksum") | .value' probe-release-run.json)
EXPECTED=$(printf '%s' "$INPUT" | shasum -a 256 | cut -d ' ' -f 1)
test "$ACTUAL" = "$EXPECTED" && printf 'Checksum matches the prepared value\n'
```

The terminal command uses `shasum`, available on macOS and the Linux runner; Alpine provides `sha256sum` inside the step. Confirm the checksum node started after preparation finished and publication started after the checksum finished. A `Succeeded` phase alone cannot prove that the inserted step used the intended input.

## Common pitfalls

> [!WARNING]
> - **Joining the next step's group.** A second inner list item runs in parallel with that step.
> - **Hashing with `echo`.** An extra newline changes the digest.
> - **Interpolating input into shell code.** Pass data through a quoted variable instead.
> - **Inspecting `@latest` after another run starts.** Keep the run name returned by submission.
