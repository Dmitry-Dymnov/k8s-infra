/*
resource "kubernetes_namespace" "kyverno" {
  metadata {
    annotations = {
      name = "kyverno"
    }
    name = "kyverno"
  }
  lifecycle {
      ignore_changes = [
        metadata[0].annotations,
        metadata[0].labels
      ]
  }
}

resource "helm_release" "kyverno-helm" {
  name       = "kyverno"
  chart      = "./INFRA_RELEASES/projects/kyverno"
  namespace  = kubernetes_namespace.kyverno.metadata[0].name
  values = [
    file("INFRA_RELEASES/projects/kyverno/values.yaml")
  ]
  depends_on = [kubernetes_namespace.kyverno]
}

resource "helm_release" "kyverno-policies-helm" {
  name       = "kyverno-policies"
  chart      = "./INFRA_RELEASES/projects/kyverno-policies"
  namespace  = kubernetes_namespace.kyverno.metadata[0].name
  values = [
    file("INFRA_RELEASES/projects/kyverno-policies/values.yaml")
  ]
  depends_on = [helm_release.kyverno-helm]
}
*/