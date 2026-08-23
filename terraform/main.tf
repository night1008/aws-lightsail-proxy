provider "alicloud" {}

provider "aws" {
  region = "ap-northeast-1"
  alias  = "ap-northeast-1"
}

provider "aws" {
  region = "ap-northeast-2"
  alias  = "ap-northeast-2"
}

provider "aws" {
  region = "ap-south-1"
  alias  = "ap-south-1"
}

provider "aws" {
  region = "ap-southeast-1"
  alias  = "ap-southeast-1"
}

provider "aws" {
  region = "ap-southeast-2"
  alias  = "ap-southeast-2"
}

provider "aws" {
  region = "ca-central-1"
  alias  = "ca-central-1"
}

provider "aws" {
  region = "eu-central-1"
  alias  = "eu-central-1"
}

provider "aws" {
  region = "eu-west-1"
  alias  = "eu-west-1"
}

provider "aws" {
  region = "eu-west-2"
  alias  = "eu-west-2"
}

provider "aws" {
  region = "eu-west-3"
  alias  = "eu-west-3"
}

provider "aws" {
  region = "us-east-1"
  alias  = "us-east-1"
}

provider "aws" {
  region = "us-east-2"
  alias  = "us-east-2"
}

provider "aws" {
  region = "us-west-2"
  alias  = "us-west-2"
}

locals {
  # 归一化单协议配置，未启用的协议自动使用组合模块的默认值
  normalized_shadowsocks = [for s in var.shadowsocks_instances : {
    region                            = s.region
    instance_name                     = s.instance_name
    availability_zone                 = s.availability_zone
    create_static_ip                  = s.create_static_ip
    shadowsocks_enable                = true
    shadowsocks_libev_port            = s.shadowsocks_libev_port
    shadowsocks_libev_password_length = s.shadowsocks_libev_password_length
    shadowsocks_libev_method          = s.shadowsocks_libev_method
  }]

  normalized_hysteria = [for s in var.hysteria_instances : {
    region                   = s.region
    instance_name            = s.instance_name
    availability_zone        = s.availability_zone
    create_static_ip         = s.create_static_ip
    hysteria_enable          = true
    hysteria_port            = s.hysteria_port
    hysteria_password_length = s.hysteria_password_length
    hysteria_proxy_url       = s.hysteria_proxy_url
  }]

  normalized_xray = [for s in var.xray_instances : {
    region            = s.region
    instance_name     = s.instance_name
    availability_zone = s.availability_zone
    create_static_ip  = s.create_static_ip
    xray_enable       = true
    xray_port         = s.xray_port
    xray_proxy_url    = s.xray_proxy_url
    xray_private_key  = s.xray_private_key
    xray_public_key   = s.xray_public_key
  }]

  normalized_anytls = [for s in var.anytls_instances : {
    region                 = s.region
    instance_name          = s.instance_name
    availability_zone      = s.availability_zone
    create_static_ip       = s.create_static_ip
    anytls_enable          = true
    anytls_port            = s.anytls_port
    anytls_password_length = s.anytls_password_length
    anytls_proxy_url       = s.anytls_proxy_url
  }]

  normalized_tuic = [for s in var.tuic_instances : {
    region               = s.region
    instance_name        = s.instance_name
    availability_zone    = s.availability_zone
    create_static_ip     = s.create_static_ip
    tuic_enable          = true
    tuic_port            = s.tuic_port
    tuic_password_length = s.tuic_password_length
    tuic_proxy_url       = s.tuic_proxy_url
  }]

  all_combined_instances = concat(
    local.normalized_shadowsocks,
    local.normalized_hysteria,
    local.normalized_xray,
    local.normalized_anytls,
    local.normalized_tuic,
    var.combined_instances
  )

  region_instances = {
    for region, instances in { for ins in local.all_combined_instances : ins.region => ins... } :
    region => { for ins in instances : format("%s-%s", ins.region, ins.instance_name) => ins }
  }
}

module "lightsail-ap-northeast-1" {
  source            = "./lightsail-combined"
  for_each          = lookup(local.region_instances, "ap-northeast-1", {})
  config            = each.value
  output_oss_bucket = var.output_oss_bucket
  providers         = { aws = aws.ap-northeast-1 }
}

module "lightsail-ap-northeast-2" {
  source            = "./lightsail-combined"
  for_each          = lookup(local.region_instances, "ap-northeast-2", {})
  config            = each.value
  output_oss_bucket = var.output_oss_bucket
  providers         = { aws = aws.ap-northeast-2 }
}

module "lightsail-ap-south-1" {
  source            = "./lightsail-combined"
  for_each          = lookup(local.region_instances, "ap-south-1", {})
  config            = each.value
  output_oss_bucket = var.output_oss_bucket
  providers         = { aws = aws.ap-south-1 }
}

module "lightsail-ap-southeast-1" {
  source            = "./lightsail-combined"
  for_each          = lookup(local.region_instances, "ap-southeast-1", {})
  config            = each.value
  output_oss_bucket = var.output_oss_bucket
  providers         = { aws = aws.ap-southeast-1 }
}

module "lightsail-ap-southeast-2" {
  source            = "./lightsail-combined"
  for_each          = lookup(local.region_instances, "ap-southeast-2", {})
  config            = each.value
  output_oss_bucket = var.output_oss_bucket
  providers         = { aws = aws.ap-southeast-2 }
}

module "lightsail-ca-central-1" {
  source            = "./lightsail-combined"
  for_each          = lookup(local.region_instances, "ca-central-1", {})
  config            = each.value
  output_oss_bucket = var.output_oss_bucket
  providers         = { aws = aws.ca-central-1 }
}

module "lightsail-eu-central-1" {
  source            = "./lightsail-combined"
  for_each          = lookup(local.region_instances, "eu-central-1", {})
  config            = each.value
  output_oss_bucket = var.output_oss_bucket
  providers         = { aws = aws.eu-central-1 }
}

module "lightsail-eu-west-1" {
  source            = "./lightsail-combined"
  for_each          = lookup(local.region_instances, "eu-west-1", {})
  config            = each.value
  output_oss_bucket = var.output_oss_bucket
  providers         = { aws = aws.eu-west-1 }
}

module "lightsail-eu-west-2" {
  source            = "./lightsail-combined"
  for_each          = lookup(local.region_instances, "eu-west-2", {})
  config            = each.value
  output_oss_bucket = var.output_oss_bucket
  providers         = { aws = aws.eu-west-2 }
}

module "lightsail-eu-west-3" {
  source            = "./lightsail-combined"
  for_each          = lookup(local.region_instances, "eu-west-3", {})
  config            = each.value
  output_oss_bucket = var.output_oss_bucket
  providers         = { aws = aws.eu-west-3 }
}

module "lightsail-us-east-1" {
  source            = "./lightsail-combined"
  for_each          = lookup(local.region_instances, "us-east-1", {})
  config            = each.value
  output_oss_bucket = var.output_oss_bucket
  providers         = { aws = aws.us-east-1 }
}

module "lightsail-us-east-2" {
  source            = "./lightsail-combined"
  for_each          = lookup(local.region_instances, "us-east-2", {})
  config            = each.value
  output_oss_bucket = var.output_oss_bucket
  providers         = { aws = aws.us-east-2 }
}

module "lightsail-us-west-2" {
  source            = "./lightsail-combined"
  for_each          = lookup(local.region_instances, "us-west-2", {})
  config            = each.value
  output_oss_bucket = var.output_oss_bucket
  providers         = { aws = aws.us-west-2 }
}