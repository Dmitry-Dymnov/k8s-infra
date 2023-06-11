/*
resource "kubernetes_namespace" "node-problem-detector" {
  metadata {
    annotations = {
      name = "node-problem-detector"
    }
    name = "node-problem-detector"
  }
  lifecycle {
      ignore_changes = [
        metadata[0].annotations,
        metadata[0].labels
      ]
  }
}

resource "kubernetes_limit_range" "node-problem-detector-limit-range" {
  metadata {
    name = "node-problem-detector-limit-range"
    namespace = "node-problem-detector"
  }
  spec {
    limit {
      type = "Pod"
      max = {
        cpu    = "100m"
        memory = "100Mi"
      }
      min = {
        cpu    = "20m"
        memory = "20Mi"
      }
    }
    limit {
      type = "Container"
      default = {
        cpu    = "100m"
        memory = "100Mi"
      }
      default_request = {
        cpu    = "20m"
        memory = "20Mi"
      }
    }
  }
  depends_on = [kubernetes_namespace.node-problem-detector]
}

resource "helm_release" "node-problem-detector-helm" {
  name       = "node-problem-detector"
  chart      = "./INFRA_RELEASES/projects/node-problem-detector"
  namespace  = kubernetes_namespace.node-problem-detector.metadata[0].name
  values = [
    file("INFRA_RELEASES/projects/node-problem-detector/values.yaml")
  ]
  depends_on = [kubernetes_limit_range.node-problem-detector-limit-range]
}
*/