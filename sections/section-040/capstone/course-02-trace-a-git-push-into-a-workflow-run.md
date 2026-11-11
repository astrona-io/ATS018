# Trace A Git Push Into A Workflow Run

An event-driven workflow adds a request path before the workflow’s own steps. The EventSource receives the webhook, the EventBus carries the event, and the Sensor filters it and creates a Workflow. A Running Sensor Pod proves none of those mappings by itself.

Trace the branch and commit separately. A branch filter should accept the intended full reference, such as `refs/heads/main`. The pushed commit ID must then become the workflow’s revision argument. Using a fixed branch in the workflow can run different source from the event that triggered it.

The Sensor identity and the workflow identity have different jobs. The Sensor needs permission to submit the Workflow. The workflow executor needs permission to report task results. Granting broad rights to the execution account hides a permission fault without repairing the intended boundary.

Inside the WorkflowTemplate, follow the clone destination into the test container’s working directory. A successful clone does not help a test step that starts outside that repository.

Make a fresh push after the repair. Match its commit ID to the Sensor-created Workflow argument, inspect the failed or successful node, and read its logs. A manually submitted Workflow tests the template but does not prove the webhook, filter and argument mapping work together.
