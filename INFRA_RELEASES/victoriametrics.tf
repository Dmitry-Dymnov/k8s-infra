/*
resource "kubernetes_namespace" "monitoring-victoria-metrics" {
  metadata {
    annotations = {
      name = "monitoring"
    }
    labels = {
      projectName = "prometheus"
    }
    name = "monitoring"
  }
  lifecycle {
      ignore_changes = [
        metadata[0].annotations,
        metadata[0].labels
      ]
  }
}

resource "helm_release" "victoria-metrics-kube-metrics" {
  name       = "victoria-metrics-kube-metrics"
  chart      = "./INFRA_RELEASES/projects/victoriametrics/kube-state-metrics"
  namespace  = kubernetes_namespace.monitoring-victoria-metrics.metadata[0].name
  depends_on = [kubernetes_namespace.monitoring-victoria-metrics]
  values = [
    file("INFRA_RELEASES/projects/victoriametrics/kube-metrics-values.yaml")
  ]
}

resource "helm_release" "victoria-metrics-node-exporter" {
  name       = "victoria-metrics-node-exporter"
  chart      = "./INFRA_RELEASES/projects/victoriametrics/prometheus-node-exporter"
  namespace  = kubernetes_namespace.monitoring-victoria-metrics.metadata[0].name
  depends_on = [kubernetes_namespace.monitoring-victoria-metrics]
  values = [
    file("INFRA_RELEASES/projects/victoriametrics/node-exporter-values.yaml")
  ]
}

resource "helm_release" "victoria-metrics-cluster" {
  name       = "victoria-metrics-cluster"
  chart      = "./INFRA_RELEASES/projects/victoriametrics/victoria-metrics-cluster"
  namespace  = kubernetes_namespace.monitoring-victoria-metrics.metadata[0].name
  depends_on = [helm_release.victoria-metrics-node-exporter, helm_release.victoria-metrics-kube-metrics]
  values = [
    file("INFRA_RELEASES/projects/victoriametrics/vm-cluster-values.yaml")
  ]
}

resource "helm_release" "victoria-metrics-agent" {
  name       = "victoria-metrics-agent"
  chart      = "./INFRA_RELEASES/projects/victoriametrics/victoria-metrics-agent"
  namespace  = kubernetes_namespace.monitoring-victoria-metrics.metadata[0].name
  depends_on = [helm_release.victoria-metrics-cluster]
  values = [
    file("INFRA_RELEASES/projects/victoriametrics/vm-agent-values.yaml")
  ]
}

resource "helm_release" "victoria-metrics-frontend" {
  name       = "victoria-metrics-frontend"
  chart      = "./INFRA_RELEASES/projects/victoriametrics/victoria-metrics-frontend"
  namespace  = kubernetes_namespace.monitoring-victoria-metrics.metadata[0].name
  depends_on = [helm_release.victoria-metrics-cluster, helm_release.victoria-metrics-agent]
  values = [
    file("INFRA_RELEASES/projects/victoriametrics/vm-frontend-values.yaml")
  ]
}
*/