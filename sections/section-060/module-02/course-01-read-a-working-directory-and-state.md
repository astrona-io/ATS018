# Read A Working Directory And Its State

The `scout` Deployment already exists. Before changing it, find the configuration
that owns it. OpenTofu state is a record that maps configuration addresses to
real resource identities and stores their last known attributes. Without that
mapping, OpenTofu cannot treat an existing object as the resource in your files.

<!-- astrona:playground:renew -->

Start by reading the supplied working directory, the folder in which OpenTofu
loads configuration and stores local state:

```sh
cd ~/resources/tofu/scout
ls -a
cat provider.tf
cat deployment.tf
tofu version
```

Look for `provider.tf`, `deployment.tf`, `terraform.tfstate` and
`.terraform.lock.hcl`. The `.tf` files use HashiCorp Configuration Language
(HCL), a language of named blocks and attribute values. OpenTofu reads all the
`.tf` files in this directory together. File names help people organize the
configuration; they do not set an execution order.

Save this as `provider.tf`, preserving the pinned configuration:

```hcl
terraform {
  required_version = "= 1.13.2"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "= 3.4.0"
    }
  }
}

provider "kubernetes" {
  config_path = "${path.module}/kubeconfig"
}
```

The `terraform` block pins the executable and plugin versions. The `provider`
block tells the plugin which credentials to use. The `kubeconfig` file contains
connection details for this environment. Bootstrap writes it from Astrona's
current credentials. The provider does not automatically use `KUBECONFIG`, the
environment variable that kubectl reads, so the explicit `config_path` matters.

Apply it by initializing the working directory:

```sh
tofu init
tofu validate
tofu state list
tofu show -no-color
```

Initialization downloads the selected provider when needed and records its
selection and checksums in `.terraform.lock.hcl`. It does not create workloads.
Look for `kubernetes_deployment.scout` in the state list. This is a resource
address: its type followed by its configuration name. The state display lets
you inspect the namespace, replica count and image that OpenTofu recorded.

Read the live object separately:

```sh
kubectl -n starfleet get deployment scout -o yaml
```

Kubernetes holds the live object. The `.tf` files hold the desired settings,
and state holds the identity and recorded attributes. State is not a substitute
for the configuration or for a live check. Keep state files private because
they can hold sensitive values. Keep each directory's state with that directory;
do not copy another directory's state or edit its contents by hand.

You can now identify what OpenTofu manages before proposing a change. A plan
will read the live resources and show the difference that an apply would make.

## Common pitfalls

> [!WARNING]
> Running in the wrong directory can select a different state. Check the path
> before each operation. Do not delete `terraform.tfstate` to clear an error:
> losing the identity mapping can make OpenTofu try to create an object that
> already exists. Keep the provider lock file when you re-run initialization.
