terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # Backend wird von FluxCD / Terraform Controller konfiguriert
    # oder manuell via backend_overwrite.tf_
  }
}
