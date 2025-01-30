terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.83.1"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~>4.0.0"
    }
  }
}