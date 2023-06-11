/*
resource "kubernetes_namespace" "goldilocks" {
  metadata {
    name = "goldilocks"
  }
  lifecycle {
      ignore_changes = [
        metadata[0].annotations,
        metadata[0].labels
      ]
  }
}

resource "helm_release" "goldilocks" {
  name       = "goldilocks"
  chart      = "./INFRA_RELEASES/projects/goldilocks/goldilocks"
  namespace  = kubernetes_namespace.goldilocks.metadata[0].name
  depends_on = [helm_release.vpa]
}

resource "helm_release" "vpa" {
  name       = "vpa"
  chart      = "./INFRA_RELEASES/projects/goldilocks/vpa"
  namespace  = kubernetes_namespace.goldilocks.metadata[0].name
}
*/