resource "kubernetes_service" "probe" {
  metadata {
    name      = "probe"
    namespace = kubernetes_deployment.probe.metadata[0].namespace
  }
  spec {
    selector = kubernetes_deployment.probe.spec[0].template[0].metadata[0].labels
    port {
      port        = 80
      target_port = 9898
    }
    type = "ClusterIP"
  }
}
