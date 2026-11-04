# OpenTofu Playground

The `scout` Deployment has one replica in `starfleet`, but no Service. OpenTofu
is an infrastructure as code tool that plans changes before applying them.
State is its record of resource identities and known attributes. The terminal
has OpenTofu 1.13.2 and Kubernetes provider 3.4.0, with a working directory and
real state in `~/resources/tofu/scout`.

Read the supplied configuration before changing it:

```sh
cd ~/resources/tofu/scout
cat provider.tf
cat deployment.tf
tofu init
tofu state list
tofu show -no-color
tofu plan -no-color
```

Look for the existing Deployment address and no proposed changes. Try changing
its replica count in the configuration, saving a plan with `tofu plan -no-color
-out=change.plan` and reading it with `tofu show -no-color change.plan`. Apply
only a plan you have reviewed. You can also add a Service that selects the
Deployment's pod labels and forwards port 80 to port 9898.

The `shuttle` Deployment supplies a request client in `starfleet`. After adding
the Service, send a request with `kubectl -n starfleet exec deploy/shuttle --
curl -fsS http://scout.starfleet/` and look for version `6.15.0`.

Keep the local state and `kubeconfig` with their configuration. The provider
uses the explicit kubeconfig path; kubectl uses Astrona's current credentials.
There is no background OpenTofu reconciliation process and no grading here.
