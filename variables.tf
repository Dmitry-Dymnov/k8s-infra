variable "prometheus_repo" {
  default = "https://prometheus-community.github.io/helm-charts"
}

variable "descheduler_repo" {
  default = "https://kubernetes-sigs.github.io/descheduler"
}

variable "splunk_repo" {
  default = "https://splunk.github.io/splunk-connect-for-kubernetes"
}

variable "vcluster_repo" {
  default = "https://charts.loft.sh"
}

variable "storage_class" {
  default = "longhorn"
}

variable "SPLUNK_TOKEN" {
  default = {}
}
