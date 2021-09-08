terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.45.0"
    }
    rancher2 = {
      source  = "rancher/rancher2"
      version = "1.15.1"
    }
  }
}
