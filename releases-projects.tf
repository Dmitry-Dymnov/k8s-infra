// Описываем деплой основных компонентов
locals {
  all_value_files = fileset(path.module, "PROJECTS_CHARTS/**/*.yaml")
  namespace_enabled = {
    for basename, val in local.all_value_files:
      basename => val if yamldecode(file("${path.module}/${(basename)}"))["namespace"] == "enable"
  }
  role_binding_enabled = {
    for basename, val in local.all_value_files:
      basename => val if yamldecode(file("${path.module}/${(basename)}"))["roleBinding"] == "enable" && yamldecode(file("${path.module}/${(basename)}"))["namespace"] == "enable"
  }
  service_account_enabled = {
    for basename, val in local.all_value_files:
      regex("^[^.]*", basename(basename)) => basename...
  }
  limit_range_enabled = {
    for basename, val in local.all_value_files:
      basename => val if yamldecode(file("${path.module}/${(basename)}"))["limitRange"] == "enable" && yamldecode(file("${path.module}/${(basename)}"))["namespace"] == "enable"
  }
  resource_quota_enabled = {
    for basename, val in local.all_value_files:
      basename => val if yamldecode(file("${path.module}/${(basename)}"))["resourceQuota"] == "enable" && yamldecode(file("${path.module}/${(basename)}"))["namespace"] == "enable"
  }
  network_policy_enabled = {
    for basename, val in local.all_value_files:
      basename => val if yamldecode(file("${path.module}/${(basename)}"))["NetworkPolicies"] == "enable" && yamldecode(file("${path.module}/${(basename)}"))["namespace"] == "enable"
  }
  all_uniq_basename = merge(local.service_account_enabled)
}

resource "kubernetes_namespace" "projects-accounts" {
  metadata {
    name = "projects-accounts"
  }
  lifecycle {
      ignore_changes = [
        metadata[0].annotations,
        metadata[0].labels
      ]
  }
}

resource "kubernetes_namespace" "namespaces-releases" {
  for_each = {
    for ns in local.namespace_enabled:
      join("-", [regex("^[^.]*", basename("${ns}")), regex("[[:lower:]][^/]*", "${ns}")]) => ns
  }
  metadata {
    name = join("", [regex("^[^.]*", basename(each.value)), "-", regex("[[:lower:]][^/]*", each.value)])
    labels = {
      "goldilocks.fairwinds.com/enabled" = "true"
      ns: join("", [regex("^[^.]*", basename(each.value)), "-", regex("[[:lower:]][^/]*", each.value)])
    }
  }
  lifecycle {
      ignore_changes = [
        metadata[0].annotations,
        metadata[0].labels
      ]
  }
}

resource "kubernetes_service_account" "projects-accounts" {
  depends_on = [kubernetes_namespace.namespaces-releases]
  for_each = local.all_uniq_basename
  metadata {
    name       = "${each.key}-sa"
    namespace = kubernetes_namespace.projects-accounts.metadata[0].name
  }
  lifecycle {
      ignore_changes = [
        metadata[0].annotations,
        metadata[0].labels
      ]
  }
}

resource "kubernetes_secret" "projects-account-secrets" {
  depends_on = [kubernetes_service_account.projects-accounts]
  for_each = local.all_uniq_basename
  metadata {
    name       = "${each.key}-token"
    namespace = kubernetes_namespace.projects-accounts.metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name" = "${each.key}-sa"
    }
  }
  type = "kubernetes.io/service-account-token"
}

resource "kubernetes_role_binding" "role-binding" {
  depends_on = [kubernetes_service_account.projects-accounts]
  for_each = {
    for rb in local.role_binding_enabled:
      join("-", [regex("^[^.]*", basename("${rb}")), regex("[[:lower:]][^/]*", "${rb}")]) => rb
  }
  metadata {
    name = join("", [regex("^[^.]*", basename(each.value)), "-rb"])
    namespace = join("", [regex("^[^.]*", basename(each.value)), "-", regex("[[:lower:]][^/]*", each.value)])
  }
  lifecycle {
      ignore_changes = [
        metadata[0].annotations,
        metadata[0].labels
      ]
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "edit"
  }
  subject {
    kind      = "ServiceAccount"
    name      = join("", [regex("^[^.]*", basename(each.value)), "-sa"])
    namespace = "projects-accounts"
  }
}

resource "kubernetes_limit_range" "limit-range-for-namespaces" {  
  depends_on = [kubernetes_namespace.namespaces-releases]
  for_each = {
    for limitrange in local.limit_range_enabled:
      join("-", [regex("^[^.]*", basename("${limitrange}")), regex("[[:lower:]][^/]*", "${limitrange}")]) => limitrange
  }
  metadata {
    name      = join("", [regex("^[^.]*", basename(each.value)), "-limits"])
    namespace = join("", [regex("^[^.]*", basename(each.value)), "-", regex("[[:lower:]][^/]*", each.value)])
  }
  spec {
    limit {
      type = "Container"
      default = {
        cpu    = coalesce(yamldecode(file("${path.module}/${each.value}"))["limitrange"]["cpu"]["limit"], "100m")
        memory = coalesce(yamldecode(file("${path.module}/${each.value}"))["limitrange"]["memory"]["limit"], "128Mi")
      }
      default_request = {
        cpu    = coalesce(yamldecode(file("${path.module}/${each.value}"))["limitrange"]["cpu"]["requests"], "50m")
        memory = coalesce(yamldecode(file("${path.module}/${each.value}"))["limitrange"]["memory"]["requests"], "64Mi")
      }
    }
  }
}

resource "kubernetes_resource_quota" "resource-quota-for-namespaces" {
  depends_on = [kubernetes_namespace.namespaces-releases]
  for_each = {
    for rq in local.resource_quota_enabled:
      join("-", [regex("^[^.]*", basename("${rq}")), regex("[[:lower:]][^/]*", "${rq}")]) => rq
  }
  metadata {
    name      = join("", [regex("^[^.]*", basename(each.value)), "-quotas"])
    namespace = join("", [regex("^[^.]*", basename(each.value)), "-", regex("[[:lower:]][^/]*", each.value)])
  }
  spec {
    hard = {
      "persistentvolumeclaims" = coalesce(yamldecode(file("${path.module}/${each.value}"))["resourcequota"]["persistentvolumeclaims"], "0")
      "requests.ephemeral-storage" = coalesce(yamldecode(file("${path.module}/${each.value}"))["resourcequota"]["requests_ephemeral_storage"], "0")
      "services" = coalesce(yamldecode(file("${path.module}/${each.value}"))["resourcequota"]["services"], "10")
      "pods" = coalesce(yamldecode(file("${path.module}/${each.value}"))["resourcequota"]["pods"], "20")
      "replicationcontrollers" = coalesce(yamldecode(file("${path.module}/${each.value}"))["resourcequota"]["replicationcontrollers"], "0")
      "count/statefulsets.apps" = coalesce(yamldecode(file("${path.module}/${each.value}"))["resourcequota"]["statefulsets_apps"], "0")
      "services.loadbalancers" = coalesce(yamldecode(file("${path.module}/${each.value}"))["resourcequota"]["services_loadbalancers"], "0")
      "services.nodeports" = coalesce(yamldecode(file("${path.module}/${each.value}"))["resourcequota"]["services_nodeports"], "0") 
      "requests.cpu" = coalesce(yamldecode(file("${path.module}/${each.value}"))["resourcequota"]["cpu"], "1.0")
      "requests.memory" = coalesce(yamldecode(file("${path.module}/${each.value}"))["resourcequota"]["memory"], "1Gi")
      "limits.cpu" = coalesce(yamldecode(file("${path.module}/${each.value}"))["resourcequota"]["cpu"], "1.0")
      "limits.memory" = coalesce(yamldecode(file("${path.module}/${each.value}"))["resourcequota"]["memory"], "1Gi")
      "requests.storage" = coalesce(yamldecode(file("${path.module}/${each.value}"))["resourcequota"]["storage"], "0Gi")
      "count/jobs.batch" = coalesce(yamldecode(file("${path.module}/${each.value}"))["resourcequota"]["jobs"], "30")
      "count/cronjobs.batch" = coalesce(yamldecode(file("${path.module}/${each.value}"))["resourcequota"]["cronjobs"], "10")
    }
  }
}

resource "kubernetes_network_policy" "network-policy-for-namespaces" {
  depends_on = [kubernetes_namespace.namespaces-releases]
  for_each = {
    for np in local.network_policy_enabled:
      join("-", [regex("^[^.]*", basename("${np}")), regex("[[:lower:]][^/]*", "${np}")]) => np
  }
  metadata {
    name      = join("", [regex("^[^.]*", basename(each.value)), "-default-np"])
    namespace = join("", [regex("^[^.]*", basename(each.value)), "-", regex("[[:lower:]][^/]*", each.value)])
  }
  spec {
    policy_types = ["Ingress", "Egress"]
    pod_selector {}
    dynamic "egress" { 
      for_each = yamldecode(file("${path.module}/${each.value}"))["networkPolicy"]["egress"]
      content {
        dynamic "ports" { 
          for_each = lookup(egress.value, "ports", {})
          content {
            port = lookup(ports.value, "port", null)
            protocol = lookup(ports.value, "protocol", null)
          }
        }

        dynamic "to" { 
          for_each = lookup(egress.value, "to", {})
          content {
            dynamic "ip_block" {
              for_each = contains(keys(to.value), "ipBlock") ? {item = to.value["ipBlock"]} : {}
                content {
                  cidr = lookup(ip_block.value, "cidr", null)
                  except = lookup(ip_block.value, "except", null)
                }
              }

            dynamic "namespace_selector" {
              for_each = contains(keys(to.value), "namespaceSelector") ? {item = to.value["namespaceSelector"]} : {}
              content {
                match_labels = lookup(namespace_selector.value, "matchLabels", null)
                dynamic "match_expressions" { 
                  for_each = lookup(namespace_selector.value, "matchExpressions", {})
                  content {
                    key = lookup(match_expressions.value, "key", null)
                    operator = lookup(match_expressions.value, "operator", null)
                    values = lookup(match_expressions.value, "values", null)
                  }
                }
              }
            }

            dynamic "pod_selector" {
              for_each = contains(keys(to.value), "podSelector") ? {item = to.value["podSelector"]} : {}
              content {
                match_labels = lookup(pod_selector.value, "matchLabels", null)
                dynamic "match_expressions" { 
                  for_each = lookup(pod_selector.value, "matchExpressions", {})
                  content {
                    key = lookup(match_expressions.value, "key", null)
                    operator = lookup(match_expressions.value, "operator", null)
                    values = lookup(match_expressions.value, "values", null)
                  }
                }
              }
            }
          }
        }
      }
    }
    dynamic "ingress" { 
      for_each = yamldecode(file("${path.module}/${each.value}"))["networkPolicy"]["ingress"]
      content {
        dynamic "from" {
          for_each = lookup(ingress.value, "from", {})
          content {
            dynamic "ip_block" { 
              for_each = contains(keys(from.value), "ipBlock") ? {item = from.value["ipBlock"]} : {}
              content {
                cidr = lookup(ip_block.value, "cidr", null)
                except = lookup(ip_block.value, "except", null)
              }
            }
            dynamic "namespace_selector" {
              for_each = contains(keys(from.value), "namespaceSelector") ? {item = from.value["namespaceSelector"]} : {}
              content {
                match_labels = lookup(namespace_selector.value, "matchLabels", null)
                dynamic "match_expressions" {
                  for_each = lookup(namespace_selector.value, "matchExpressions", {})
                  content {
                    key = lookup(match_expressions.value, "key", null)
                    operator = lookup(match_expressions.value, "operator", null)
                    values = lookup(match_expressions.value, "values", null)
                  }
                }
              }
            }
            dynamic "pod_selector" {
              for_each = contains(keys(from.value), "podSelector") ? {item = from.value["podSelector"]} : {}
              content {
                match_labels = lookup(pod_selector.value, "matchLabels", null)
                dynamic "match_expressions" {
                  for_each = lookup(pod_selector.value, "matchExpressions", {})
                  content {
                    key = lookup(match_expressions.value, "key", null)
                    operator = lookup(match_expressions.value, "operator", null)
                    values = lookup(match_expressions.value, "values", null)
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}