terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.40"
    }

    alicloud = {
      source  = "aliyun/alicloud"
      version = "~> 1.275"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.8"
    }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}
