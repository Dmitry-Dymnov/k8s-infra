// terraform state backend
terraform {
  backend "s3" {
    endpoint                    = "https://storage.yandexcloud.net"
    bucket                      = "hot-dog007"
    key                         = "k3s-test-infra/terraform.tfstate"
    region                      = "us-east-1"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    force_path_style            = true
  }
}