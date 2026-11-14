resource "kubernetes_deployment" "probe" {
  metadata {
    name      = "probe"
    namespace = "outpost"
  }
  spec {
    replicas = 1
    selector {
      match_labels = { app = "probe" }
    }
    template {
      metadata {
        labels = { app = "probe" }
      }
      spec {
        container {
          name  = "probe"
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
