variable "output_oss_bucket" {
  type    = string
  default = "aws-lightsail-terraform"
}

variable "config" {
  type = object({
    region               = string # aws lightsail region
    instance_name        = string # aws lightsail instance name
    availability_zone    = string # aws lightsail instance availability zone
    create_static_ip     = bool   # create lightsail static ip
    xray_port            = number # xray listen port，建议使用 443
    xray_proxy_url       = string # REALITY 伪装目标 URL，如 https://bing.com
    xray_private_key     = string # x25519 私钥（base64url，无填充），服务端使用
    xray_public_key      = string # x25519 公钥（base64url，无填充），客户端使用
  })
  default = {
    region               = "ap-northeast-1"
    instance_name        = "test1"
    availability_zone    = "ap-northeast-1a"
    create_static_ip     = true
    xray_port            = 443
    xray_proxy_url       = "https://bing.com"
    xray_private_key     = ""
    xray_public_key      = ""
  }

  validation {
    condition     = var.config.region == substr(var.config.availability_zone, 0, length(var.config.availability_zone) - 1)
    error_message = "The instance availability_zone must be in the same region."
  }

  validation {
    condition     = can(regex("^https?://[^/]+", var.config.xray_proxy_url))
    error_message = "xray_proxy_url must be a valid http(s) URL."
  }

  validation {
    condition     = length(var.config.xray_private_key) > 0 && length(var.config.xray_public_key) > 0
    error_message = "xray_private_key and xray_public_key must be provided (generate with: xray x25519)."
  }
}
