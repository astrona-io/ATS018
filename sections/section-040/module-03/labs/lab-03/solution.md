# Solution Walkthrough

You will read a WorkflowTemplate with the `argo` command-line tool, add a template and a step in the middle of its `steps` list, run the changed template, read the result of the new step and remove the run you no longer need.

| Goal | Object | Command or field |
| --- | --- | --- |
| Read the template | WorkflowTemplate `shuttle-release` | `argo template get -o yaml` |
| Add the checksum template | WorkflowTemplate `shuttle-release` | A new entry in `spec.templates` with `inputs`, `container` and `outputs` |
| Insert the step | WorkflowTemplate `shuttle-release` | A new group in the `steps` list of `main`, `argo template update` |
| Run and read | A new Workflow | `argo submit --from`, `argo get`, `argo logs` |
| Keep one success | Workflows in `starfleet` | `argo delete` |

## The feedback loop

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-040/module-03/labs/lab-03
```

The four checks are `step-inserted`, `workflow-succeeded`, `checksum-output` and `one-run`. None passes in the untouched environment. Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Read the template and the run that exists

Make sure your shell finds the tool, then look at what the lab starts with:

```sh
export PATH="$HOME/.astrona/bin:$PATH"
argo list -n starfleet
argo get -n starfleet @latest
argo template get -n starfleet shuttle-release -o yaml > shuttle-release.yaml
```

`argo list` shows one Workflow with `Succeeded` in the `STATUS` column. `argo get` prints a tree with three pods, one per step: `fetch-manifest`, `deploy` and `notify`. The file `shuttle-release.yaml` holds the template.

In the file, the template `main` has a `steps` list with three groups. Each group starts with a line that begins with `- -`. The step `deploy` takes the parameter `manifest` with the value `{{steps.fetch-manifest.outputs.parameters.manifest}}`. That is how one step reads the output parameter of an earlier step: `steps.<step name>.outputs.parameters.<parameter name>`. The template `fetch-manifest` exports that parameter from the file `/tmp/manifest.txt` with `outputs.parameters[].valueFrom.path`.

## Add the template and insert the step

Open `shuttle-release.yaml`. Remove the `status` block and, under `metadata`, the fields `resourceVersion`, `uid`, `creationTimestamp` and `generation`, so that `argo template update` sends a clean object. Then make two changes.

First, add the new template to `spec.templates`. It declares the input, hashes exactly the value of the input, writes the digest without a newline and exports it:

```yaml
    - name: verify-checksum
      inputs:
        parameters:
          - name: manifest
      container:
        image: alpine:3.23
        command: [sh, -c]
        args:
          - printf '%s' "{{inputs.parameters.manifest}}" | sha256sum | awk '{printf "%s", $1}' > /tmp/checksum.txt && cat /tmp/checksum.txt
      outputs:
        parameters:
          - name: checksum
            valueFrom:
              path: /tmp/checksum.txt
```

`printf '%s'` writes the value and nothing else. `echo` would add a newline, and the digest of the value plus a newline is a different digest. `sha256sum` prints the digest and a file name, so `awk` keeps the first field.

Second, insert a new group in the `steps` list of `main`, between the first and the second group, so that the list reads:

```yaml
      steps:
        - - name: fetch-manifest
            template: fetch-manifest
        - - name: verify-checksum
            template: verify-checksum
            arguments:
              parameters:
                - name: manifest
                  value: "{{steps.fetch-manifest.outputs.parameters.manifest}}"
        - - name: deploy
            template: deploy
            arguments:
              parameters:
                - name: manifest
                  value: "{{steps.fetch-manifest.outputs.parameters.manifest}}"
        - - name: notify
            template: notify
```

A line that starts with `- -` opens a new group, and a group starts only after the group before it ends. That is what puts `verify-checksum` between `fetch-manifest` and `deploy`. A line that starts with a single `-` at the inner indentation would join the group of `deploy`, and the two steps would start together.

Send the change to the cluster and read it back:

```sh
argo template update shuttle-release.yaml
argo template get -n starfleet shuttle-release
```

The output lists four steps in `main` and five templates. The check `step-inserted` turns green.

## Run the changed template

A change to a template does not change the run that already exists, so start a new one. `--wait` holds the command until the run ends:

```sh
argo submit -n starfleet --from workflowtemplate/shuttle-release --wait
argo get -n starfleet @latest
argo logs -n starfleet @latest
```

`argo get` shows `Succeeded` and a tree with four pods, with `verify-checksum` between `fetch-manifest` and `deploy`. `argo logs` prints one line per pod: the manifest from `fetch-manifest`, a 64-character hex digest from `verify-checksum`, `deploying shuttle 6.15.0 ...` from `deploy` and `release done` from `notify`.

You can compare the digest on your own machine. Read the manifest the run produced and hash it:

```sh
MANIFEST=$(kubectl -n starfleet get workflow "$(argo list -n starfleet -o name | head -n 1)" -o jsonpath='{.status.nodes[?(@.displayName=="fetch-manifest")].outputs.parameters[?(@.name=="manifest")].value}')
printf '%s' "$MANIFEST" | sha256sum
```

On macOS use `shasum -a 256` instead of `sha256sum`. The digest matches the line from `verify-checksum`. The checks `workflow-succeeded` and `checksum-output` turn green.

## Clean up

List what is there, then delete the run from before your change. Its name is the one that is not `@latest`:

```sh
argo list -n starfleet
argo delete -n starfleet <name of the old run>
argo list -n starfleet
```

If you started a run more than once, delete each extra run by its name and keep the newest success. The check `one-run` turns green.

## Submit

When all four checks are green, stop the watch with Ctrl-C and record the attempt once:

```sh
astrona submit --git ssh://git@github.com/astrona-io/ATS018.git -c sections/section-040/module-03/labs/lab-03
```

## If a check stays red

- **`step-inserted`:** Read the template with `argo template get -n starfleet shuttle-release -o yaml`. The list of `main` must have four groups, each with one step, in the order `fetch-manifest`, `verify-checksum`, `deploy`, `notify`. A step that starts with a single `-` under `deploy` joins the group of `deploy` and runs next to it, not before it. The step `verify-checksum` must pass the parameter `manifest`, and the template `verify-checksum` must declare it as an input, use `sha256sum` and export the output parameter `checksum` from a file.
- **`workflow-succeeded`:** A run keeps the template it started with. Start a new run after you change the template. Read a failed pod with `argo logs`. A step that reads `{{inputs.parameters.manifest}}` without an `inputs` block fails before its pod starts.
- **`checksum-output`:** The grader hashes the exact value of the output parameter `manifest` of `fetch-manifest`. Hash the value with `printf '%s'`, not with `echo`, and write only the digest to the file.
- **`one-run`:** The message counts the Workflows of the template. Delete the run from before your change and every extra run by name with `argo delete`.
