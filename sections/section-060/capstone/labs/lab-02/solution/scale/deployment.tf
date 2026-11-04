resource "kubernetes_deployment" "scout" {
  metadata {
    name      = "scout"
    namespace = "starfleet-staging"
  }
  spec {
    replicas = 2
    selector {
      match_labels = { app = "scout" }
    }
    template {
      metadata {
        labels = { app = "scout" }
      }
      spec {
        container {
          name  = "scout"
          image = "ghcr.io/stefanprodan/podinfo:6.15.0"
          port {
            container_port = 9898
          }
          readiness_probe {
            http_get {
              path = "/readyz"
              port = 9898
            }
          }
          resources {
            requests = { cpu = "10m", memory = "32Mi" }
          }
        }
      }
    }
  }
}
