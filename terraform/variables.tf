variable "output_oss_bucket" {
  description = "alicloud bucket name for config output"
  type        = string
  default     = "aws-lightsail-terraform"
}

variable "shadowsocks_instances" {
  description = "aws lightsail instance config"
  type = list(object({
    region                            = string # aws lightsail region
    instance_name                     = string # aws lightsail instance name
    availability_zone                 = string # aws lightsail instance availability zone
    create_static_ip                  = bool   # create lightsail static ip
    shadowsocks_libev_port            = number # shadowsocks-libev config port
    shadowsocks_libev_password_length = number # shadowsocks-libev password length
    shadowsocks_libev_method          = string # shadowsocks-libev config method
  }))
  default = []
  validation {
    condition     = length(var.shadowsocks_instances) == length(toset([for s in var.shadowsocks_instances : format("%s-%s", s.region, s.instance_name)]))
    error_message = "The shadowsocks_instances instance_name must be unique on a region."
  }
}

variable "hysteria_instances" {
  description = "aws lightsail hysteria2 instance config"
  type = list(object({
    region            = string # aws lightsail region
    instance_name     = string # aws lightsail instance name
    availability_zone = string # aws lightsail instance availability zone
    create_static_ip         = bool   # create lightsail static ip
    hysteria_port            = optional(number, 8443) # hysteria2 listen port，默认 8443
    hysteria_password_length = number # hysteria2 password length
    hysteria_proxy_url       = string # masquerade proxy url, e.g. https://bing.com
  }))
  default = []
  validation {
    condition     = length(var.hysteria_instances) == length(toset([for s in var.hysteria_instances : format("%s-%s", s.region, s.instance_name)]))
    error_message = "The hysteria_instances instance_name must be unique on a region."
  }
}

variable "combined_instances" {
  description = "aws lightsail combined (shadowsocks + hysteria2 + xray + anytls + tuic) instance config"
  type = list(object({
    region                            = string # aws lightsail region
    instance_name                     = string # aws lightsail instance name
    availability_zone                 = string # aws lightsail instance availability zone
    create_static_ip                  = bool   # create lightsail static ip
    shadowsocks_enable                = bool   # 是否启用 shadowsocks-libev
    shadowsocks_libev_port            = number # shadowsocks-libev config port
    shadowsocks_libev_password_length = number # shadowsocks-libev password length
    shadowsocks_libev_method          = string # shadowsocks-libev config method
    hysteria_enable                   = bool   # 是否启用 hysteria2
    hysteria_port                     = optional(number, 8443) # hysteria2 listen port，默认 8443
    hysteria_password_length          = number # hysteria2 password length
    hysteria_proxy_url                = string # masquerade proxy url, e.g. https://bing.com
    xray_enable                       = bool   # 是否启用 xray (VLESS+REALITY)
    xray_port                         = number # xray listen port，建议使用 443
    xray_proxy_url                    = string # REALITY 伪装目标 URL，如 https://bing.com
    xray_private_key                  = string # x25519 私钥（base64url，无填充）
    xray_public_key                   = string # x25519 公钥（base64url，无填充）
    anytls_enable                     = bool   # 是否启用 anytls (sing-box)
    anytls_port                       = optional(number, 8444) # anytls listen port，默认 8444
    anytls_password_length            = number # anytls password length
    anytls_proxy_url                  = string # masquerade proxy url, e.g. https://bing.com
    tuic_enable                       = bool   # 是否启用 tuic v5 (sing-box)
    tuic_port                         = optional(number, 8445) # tuic listen port，默认 8445
    tuic_password_length              = number # tuic password length
    tuic_proxy_url                    = string # masquerade proxy url, e.g. https://bing.com
  }))
  default = []
  validation {
    condition     = length(var.combined_instances) == length(toset([for s in var.combined_instances : format("%s-%s", s.region, s.instance_name)]))
    error_message = "The combined_instances instance_name must be unique on a region."
  }
}

variable "xray_instances" {
  description = "aws lightsail xray (VLESS+REALITY) instance config"
  type = list(object({
    region               = string # aws lightsail region
    instance_name        = string # aws lightsail instance name
    availability_zone    = string # aws lightsail instance availability zone
    create_static_ip     = bool   # create lightsail static ip
    xray_port            = number # xray listen port，建议使用 443
    xray_proxy_url       = string # REALITY 伪装目标 URL，如 https://bing.com
    xray_private_key     = string # x25519 私钥（base64url，无填充），服务端使用
    xray_public_key      = string # x25519 公钥（base64url，无填充），客户端使用
  }))
  default = []
  validation {
    condition     = length(var.xray_instances) == length(toset([for s in var.xray_instances : format("%s-%s", s.region, s.instance_name)]))
    error_message = "The xray_instances instance_name must be unique within a region."
  }
}

variable "anytls_instances" {
  description = "aws lightsail anytls (sing-box) instance config"
  type = list(object({
    region                 = string # aws lightsail region
    instance_name          = string # aws lightsail instance name
    availability_zone      = string # aws lightsail instance availability zone
    create_static_ip      = bool   # create lightsail static ip
    anytls_port            = optional(number, 8444) # anytls listen port，默认 8444
    anytls_password_length = number # anytls password length
    anytls_proxy_url       = string # masquerade proxy url, e.g. https://bing.com
  }))
  default = []
  validation {
    condition     = length(var.anytls_instances) == length(toset([for s in var.anytls_instances : format("%s-%s", s.region, s.instance_name)]))
    error_message = "The anytls_instances instance_name must be unique within a region."
  }
}

variable "tuic_instances" {
  description = "aws lightsail tuic v5 (sing-box) instance config"
  type = list(object({
    region               = string # aws lightsail region
    instance_name        = string # aws lightsail instance name
    availability_zone    = string # aws lightsail instance availability zone
    create_static_ip    = bool   # create lightsail static ip
    tuic_port            = optional(number, 8445) # tuic listen port，默认 8445
    tuic_password_length = number # tuic password length
    tuic_proxy_url       = string # masquerade proxy url, e.g. https://bing.com
  }))
  default = []
  validation {
    condition     = length(var.tuic_instances) == length(toset([for s in var.tuic_instances : format("%s-%s", s.region, s.instance_name)]))
    error_message = "The tuic_instances instance_name must be unique within a region."
  }
}