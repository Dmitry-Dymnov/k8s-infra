/*
// Создаем namespace
resource "kubernetes_namespace" "fluentbit-ns" {
  metadata {
    annotations = {
      name = "logging"
    }
    name = "logging"
  }
  lifecycle {
      ignore_changes = [
        metadata[0].annotations,
        metadata[0].labels
      ]
  }
}

// Описываем деплой основных компонентов fluentd
resource "k8s_manifest" "fluentbit-system" {
  for_each = fileset(path.module, "INFRA_RELEASES/projects/fluentbit/*.yaml")
  content  = file(each.value)
  depends_on = [kubernetes_namespace.fluentbit-ns]
}
*/