# Summary

A blue/green release starts a candidate configuration separately from the stable configuration. Argo Rollouts manages it through a Rollout, the resource that controls release progress. Its active and preview Services provide separate addresses by selecting different pod template hashes. A Service selects ready pods and gives them a stable address. Promotion changes the active selector, and a scale-down delay keeps old replicas available while networking updates propagate.

## What you learned

Prometheus collects the application's measurements from a dedicated metrics port. The podinfo request counter has a status label but no path label; the histogram's count series also identifies request paths. Selecting root requests and the candidate template hash prevents readiness checks and stable traffic from hiding candidate errors. Steady preview traffic produces measurements before active users reach the new configuration.

An AnalysisTemplate defines a query, arguments and conditions. An AnalysisRun records one evaluation of that template through timed measurements. Pre-promotion analysis checks the candidate before the active Service switches. A Successful result still leaves an operator pause when automatic promotion is disabled. Missing measurements or a value that is not a number must never stand in for a passing application.

Failed pre-promotion analysis aborts the release and retains the stable active selector. The Rollout can report Degraded while active users still receive successful responses. Abort does not repair the desired pod template, so remove the bad setting from the manifest and restore the intended state. Analysis phase, Service selectors and real application responses together prove the release outcome.

<!-- astrona:playground:destroy -->
