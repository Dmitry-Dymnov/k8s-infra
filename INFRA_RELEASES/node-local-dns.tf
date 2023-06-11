/*
resource "helm_release" "node-local-dns" {
  name       = "node-local-dns"
  chart      = "./INFRA_RELEASES/projects/node-local-dns"
  namespace  = "kube-system"
  values = [
    file("INFRA_RELEASES/projects/node-local-dns/values.yaml")
  ]
}
*/