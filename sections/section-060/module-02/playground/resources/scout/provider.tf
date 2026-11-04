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
