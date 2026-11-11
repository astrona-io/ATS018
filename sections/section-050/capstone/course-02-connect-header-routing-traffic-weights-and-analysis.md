# Connect Header Routing, Traffic Weights And Analysis

Header routing and weighted traffic answer different questions. A header rule lets selected test requests reach a candidate before ordinary traffic receives a weighted share. The route must be managed by the rollout controller so it is removed when that candidate is no longer being tested.

Create candidate capacity before routing test requests to it. At the first pause, compare a request with the test header against an ordinary request. This distinguishes a working header match from a route that accidentally sends every request to the candidate.

After traffic weights change, the background analysis needs measurements for the latest pod template hash. Inspect the AnalysisRun arguments and query, then allow time for scraping and rate calculation. A route split does not prove the analysis measures the right Pods.

Retain evidence for a good promotion and a later failed release. The failed analysis should abort the faulty candidate while the known-good template remains available. Avoid bypassing the analysis with a full promotion.

Recovery includes routing cleanup. Verify the managed header rule is gone, ordinary traffic returns to the stable Service, and responses contain the known-good message. Checking only the Rollout’s Healthy condition can miss a stale route that still directs some callers to the failed candidate.
