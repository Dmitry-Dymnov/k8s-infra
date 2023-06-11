/*
// Описываем деплой 
resource "k8s_manifest" "kubegraf-deploy" {
  for_each = fileset(path.module, "INFRA_RELEASES/projects/kubegraf/*.yaml")
  content  = file(each.value)
}
*/