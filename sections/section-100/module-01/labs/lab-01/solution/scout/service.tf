resource "kubernetes_service" "scout" {
  metadata {
    name      = "scout"
    namespace = kubernetes_deployment.scout.metadata[0].namespace
  }
  spec {
    selector = kubernetes_deployment.scout.spec[0].template[0].metadata[0].labels
    port {
      port        = 80
      target_port = 9898
    }
    type = "ClusterIP"
  }
}
