locals {
  custom_sa_range = fileset(path.module, "CUSTOM_PROJECTS/service_accounts/*.yaml")
  custom_ns_range = fileset(path.module, "CUSTOM_PROJECTS/namespaces/*.yaml")
  
  user_edit_sa = {
    for sa, val in local.custom_sa_range:
      regex("^[^.]*", basename("${sa}")) => try(yamldecode(file("${val}"))["userEditServiceAccounts"]["namespaces"], null) if try(yamldecode(file("${val}"))["userEditServiceAccounts"]["namespaces"], null) != null
  }
  
  user_view_sa = {
    for sa, val in local.custom_sa_range:
      regex("^[^.]*", basename("${sa}")) => try(yamldecode(file("${val}"))["userViewServiceAccounts"]["namespaces"], null) if try(yamldecode(file("${val}"))["userViewServiceAccounts"]["namespaces"], null) != null
  }
  
  user_edit_sa_list = flatten([
    for sa in keys(local.user_edit_sa) : [
      for ns in local.user_edit_sa[sa] : {
        sa   = sa
        ns   = ns
        role = "edit"
      }
    ]
  ])
  
  user_view_sa_list = flatten([
    for sa in keys(local.user_view_sa) : [
      for ns in local.user_view_sa[sa] : {
        sa   = sa
        ns   = ns
        role = "view"
      }
    ]
  ])
  
  custom_namespace_enabled = {
    for ns, val in local.custom_ns_range:
      ns => val if yamldecode(file("${val}"))["namespace"] == "enable"
  }
  
  custom_service_account_enabled = {
    for sa, val in local.custom_ns_range:
      regex("^[^.]*", basename(sa)) => sa if yamldecode(file("${val}"))["serviceAccount"] == "enable"
  }
  
  custom_limit_range_enabled = {
    for limitrange, val in local.custom_ns_range:
      limitrange => val if yamldecode(file("${val}"))["limitRange"] == "enable" && yamldecode(file("${val}"))["namespace"] == "enable"
  }
  
  custom_resource_quota_enabled = {
    for resourcequota, val in local.custom_ns_range:
      resourcequota => val if yamldecode(file("${val}"))["resourceQuota"] == "enable" && yamldecode(file("${val}"))["namespace"] == "enable"
  }
  
  custom_network_policy_enabled = {
    for networkpolicy, val in local.custom_ns_range:
      networkpolicy => val if yamldecode(file("${val}"))["NetworkPolicies"] == "enable" && yamldecode(file("${val}"))["namespace"] == "enable"
  }
  
  all_uniq_sa = concat(local.user_edit_sa_list, local.user_view_sa_list)
}

resource "kubernetes_namespace" "users-accounts" {
  metadata {
    name = "users-accounts"
  }
  lifecycle {
      ignore_changes = [
        metadata[0].annotations,
        metadata[0].labels
      ]
  }
}

resource "kubernetes_service_account" "user-accounts" {
  depends_on = [kubernetes_namespace.users-accounts]
  for_each = {
    for sa in local.custom_sa_range:
      regex("^[^.]*", basename("${sa}")) => sa
  }
  metadata {
    name       = "${each.key}-sa"
    namespace = kubernetes_namespace.users-accounts.metadata[0].name
  }
  lifecycle {
      ignore_changes = [
        metadata[0].annotations,
        metadata[0].labels
      ]
  }
}

resource "kubernetes_secret" "user-account-secrets" {
  depends_on = [kubernetes_service_account.user-accounts]
  for_each = {
    for sa in local.custom_sa_range:
      regex("^[^.]*", basename("${sa}")) => sa
  }
  metadata {
    name       = "${each.key}-token"
    namespace = kubernetes_namespace.users-accounts.metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name" = "${each.key}-sa"
    }
  }
  type = "kubernetes.io/service-account-token"
}

resource "kubernetes_role_binding" "user-account-role-bindings" {
  depends_on = [kubernetes_service_account.user-accounts]
  for_each = {
    for sa in local.all_uniq_sa: "${sa.sa}.${sa.ns}" => sa
  }
  metadata {
    name = join("", ["${each.value.sa}", "-rb"])
    namespace = each.value.ns
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
    name      = each.value.role
  }
  subject {
    kind      = "ServiceAccount"
    name      = join("", ["${each.value.ns}", "-sa"])
    namespace = kubernetes_namespace.users-accounts.metadata[0].name
  }
}

resource "kubernetes_namespace" "namespaces-custom" {
  for_each = {
    for ns in local.custom_namespace_enabled:
      regex("^[^.]*", basename("${ns}")) => ns
  }
  metadata {
    name = regex("^[^.]*", basename(each.value))
    labels = {
      "goldilocks.fairwinds.com/enabled" = "true"
      ns: regex("^[^.]*", basename(each.value))
    }
  }
  lifecycle {
      ignore_changes = [
        metadata[0].annotations,
        metadata[0].labels
      ]
  }
}

resource "kubernetes_service_account" "custom-ns-accounts" {
  depends_on = [kubernetes_namespace.namespaces-custom]
  for_each = local.custom_service_account_enabled
  metadata {
    name       = "${each.key}-sa"
    namespace = kubernetes_namespace.users-accounts.metadata[0].name
  }
  lifecycle {
      ignore_changes = [
        metadata[0].annotations,
        metadata[0].labels
      ]
  }
}

resource "kubernetes_secret" "custom-sa-secrets" {
  depends_on = [kubernetes_service_account.custom-ns-accounts]
  for_each = local.custom_service_account_enabled
  metadata {
    name       = "${each.key}-token"
    namespace = kubernetes_namespace.users-accounts.metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name" = "${each.key}-sa"
    }
  }
  type = "kubernetes.io/service-account-token"
}

resource "kubernetes_role_binding" "custom-role-binding" {
  depends_on = [kubernetes_service_account.custom-ns-accounts]
  for_each = local.custom_service_account_enabled
  metadata {
    name = join("", [regex("^[^.]*", basename(each.value)), "-rb"])
    namespace = regex("^[^.]*", basename(each.value))
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
    namespace = kubernetes_namespace.users-accounts.metadata[0].name
  }
} 

resource "kubernetes_limit_range" "limit-range-for-custom-ns" {  
  depends_on = [kubernetes_namespace.namespaces-custom]
  for_each = {
    for limitrange in local.custom_limit_range_enabled:
      regex("^[^.]*", basename("${limitrange}")) => limitrange
  }
  metadata {
    name      = join("", [regex("^[^.]*", basename(each.value)), "-limits"])
    namespace = regex("^[^.]*", basename(each.value))
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

resource "kubernetes_resource_quota" "resource-quota-for-custom-ns" {
  depends_on = [kubernetes_namespace.namespaces-custom]
  for_each = {
    for resourcequota in local.custom_resource_quota_enabled:
      regex("^[^.]*", basename("${resourcequota}")) => resourcequota
  }
  metadata {
    name      = join("", [regex("^[^.]*", basename(each.value)), "-quotas"])
    namespace = regex("^[^.]*", basename(each.value))
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

resource "kubernetes_network_policy" "network-policy-for-custom-ns" {
  depends_on = [kubernetes_namespace.namespaces-custom]
  for_each = {
    for networkpolicy in local.custom_network_policy_enabled:
      regex("^[^.]*", basename("${networkpolicy}")) => networkpolicy
  }
  metadata {
    name      = join("", [regex("^[^.]*", basename(each.value)), "-default-np"])
    namespace = regex("^[^.]*", basename(each.value))
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