# Trace GitOps Ownership And Tenant Scope

Argo CD delivery has several independent decisions: which repository may be read, which source path is rendered, which project permits the destination, and which controller owns the resulting Application. A healthy controller does not establish that any one application passes those checks.

For a broken Application, begin with its conditions and resource results. A comparison error points toward source access or rendering. An apply error identifies a rejected object. A synced but unhealthy application needs workload inspection. Repair the desired state in Git and compare the observed revision with the commit containing the repair.

An ApplicationSet owns generated Applications. Its generator provides values and its template decides source paths, destinations and sync policy. Inspect each generated Application independently; a correct generator does not prove its workloads are ready.

An AppProject limits what its Applications may use. Check repositories, destinations, namespaced kinds and cluster-scoped kinds separately. A permission that lets the default project deploy into staging does not imply a second tenant should receive the same access.

Prove delivery at both levels: Synced and Healthy at the Application, then the required response through each Service. Keep automated sync, prune and self-heal enabled so the checked result remains controlled by the intended Git source.
