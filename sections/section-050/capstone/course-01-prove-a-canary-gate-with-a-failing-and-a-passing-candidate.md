# Prove A Canary Gate With A Failing And A Passing Candidate

A canary analysis must measure the candidate, not a mixture dominated by stable Pods. A healthy stable workload can hide candidate failures when the metric query omits the candidate’s pod template hash.

Inspect the arguments passed from the Rollout into the AnalysisRun. Then inspect the query’s namespace, request path, status selection and hash filter. The success fraction needs matching populations: successful responses in the numerator and all responses for that same candidate and path in the denominator.

A new candidate needs time to receive traffic and produce enough samples for a rate. Missing data is a measurement problem to investigate, rather than evidence of a good release. Keep the analysis threshold, failure limit and pauses while diagnosing the query.

Exercise both decisions. A faulty candidate should fail on actual measurements and abort while the stable workload remains available. A good candidate should pass its analysis and proceed through the intended promotion steps. Keep the runs so their candidate identities and measurements can be inspected.

At the end, check the current stable ReplicaSet, available replicas and Service response. A healthy final state alone does not prove that the gate rejected the earlier faulty candidate.
