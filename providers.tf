terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.20.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.9.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.4.0"
    }
    template = {
      source  = "hashicorp/template"
      version = "2.2.0"
    }
  }
  required_version = ">= 0.15"
}

provider "kubernetes" {
  insecure         = true
}
provider "helm" {
  kubernetes {
    insecure         = true
  }
}

module "infra_releases" {
  source = "./INFRA_RELEASES"
}