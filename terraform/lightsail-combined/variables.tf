variable "output_oss_bucket" {
  type    = string
  default = "aws-lightsail-terraform"
}

variable "config" {
  type = object({
    region            = string               # aws lightsail region
    instance_name     = string               # aws lightsail instance name
    availability_zone = string               # aws lightsail instance availability zone
    create_static_ip  = optional(bool, true) # create lightsail static ip
    # 协议开关
    shadowsocks_enable = optional(bool, false) # 是否启用 shadowsocks-libev
    hysteria_enable    = optional(bool, false) # 是否启用 hysteria2
    xray_enable        = optional(bool, false) # 是否启用 xray (VLESS+REALITY)
    anytls_enable      = optional(bool, false) # 是否启用 anytls (sing-box)
    tuic_enable        = optional(bool, false) # 是否启用 tuic v5 (sing-box)
    # shadowsocks-libev（shadowsocks_enable = true 时生效）
    shadowsocks_libev_port            = optional(number, 8388)                     # shadowsocks-libev listen port
    shadowsocks_libev_password_length = optional(number, 10)                       # shadowsocks-libev password length
    shadowsocks_libev_method          = optional(string, "chacha20-ietf-poly1305") # shadowsocks-libev cipher method
    # hysteria2（hysteria_enable = true 时生效）
    hysteria_port            = optional(number, 8443)               # hysteria2 listen port，默认 8443
    hysteria_password_length = optional(number, 10)                 # hysteria2 password length
    hysteria_proxy_url       = optional(string, "https://bing.com") # masquerade proxy url
    # xray VLESS+REALITY（xray_enable = true 时生效）
    xray_port        = optional(number, 443)                # xray listen port，建议使用 443
    xray_proxy_url   = optional(string, "https://bing.com") # REALITY 伪装目标 URL
    xray_private_key = optional(string, "")                 # x25519 私钥（base64url，无填充），服务端使用
    xray_public_key  = optional(string, "")                 # x25519 公钥（base64url，无填充），客户端使用
    # anytls（anytls_enable = true 时生效）
    anytls_port            = optional(number, 8444)               # anytls listen port，默认 8444
    anytls_password_length = optional(number, 10)                 # anytls password length
    anytls_proxy_url       = optional(string, "https://bing.com") # masquerade proxy url
    # tuic v5（tuic_enable = true 时生效）
    tuic_port            = optional(number, 8445)               # tuic listen port，默认 8445
    tuic_password_length = optional(number, 10)                 # tuic password length
    tuic_proxy_url       = optional(string, "https://bing.com") # masquerade proxy url
  })
  default = {
    region                            = "ap-northeast-1"
    instance_name                     = "test1"
    availability_zone                 = "ap-northeast-1a"
    create_static_ip                  = true
    shadowsocks_enable                = false
    hysteria_enable                   = false
    xray_enable                       = false
    anytls_enable                     = false
    tuic_enable                       = false
    shadowsocks_libev_port            = 8388
    shadowsocks_libev_password_length = 10
    shadowsocks_libev_method          = "chacha20-ietf-poly1305"
    hysteria_port                     = 8443
    hysteria_password_length          = 10
    hysteria_proxy_url                = "https://bing.com"
    xray_port                         = 443
    xray_proxy_url                    = "https://bing.com"
    xray_private_key                  = ""
    xray_public_key                   = ""
    anytls_port                       = 8444
    anytls_password_length            = 10
    anytls_proxy_url                  = "https://bing.com"
    tuic_port                         = 8445
    tuic_password_length              = 10
    tuic_proxy_url                    = "https://bing.com"
  }

  validation {
    condition     = var.config.region == substr(var.config.availability_zone, 0, length(var.config.availability_zone) - 1)
    error_message = "The instance availability_zone must be in the same region."
  }

  validation {
    condition     = var.config.shadowsocks_enable || var.config.hysteria_enable || var.config.xray_enable || var.config.anytls_enable || var.config.tuic_enable
    error_message = "At least one protocol must be enabled (shadowsocks_enable, hysteria_enable, xray_enable, anytls_enable, or tuic_enable)."
  }

  validation {
    condition     = !var.config.hysteria_enable || can(regex("^https?://[^/]+", var.config.hysteria_proxy_url))
    error_message = "hysteria_proxy_url must be a valid http(s) url when hysteria_enable is true."
  }

  validation {
    condition     = !var.config.xray_enable || can(regex("^https?://[^/]+", var.config.xray_proxy_url))
    error_message = "xray_proxy_url must be a valid http(s) URL when xray_enable is true."
  }

  validation {
    condition     = !var.config.anytls_enable || can(regex("^https?://[^/]+", var.config.anytls_proxy_url))
    error_message = "anytls_proxy_url must be a valid http(s) URL when anytls_enable is true."
  }

  validation {
    condition     = !var.config.tuic_enable || can(regex("^https?://[^/]+", var.config.tuic_proxy_url))
    error_message = "tuic_proxy_url must be a valid http(s) URL when tuic_enable is true."
  }

  validation {
    condition     = !var.config.xray_enable || (length(var.config.xray_private_key) > 0 && length(var.config.xray_public_key) > 0)
    error_message = "xray_private_key and xray_public_key must be provided when xray_enable is true (generate with: scripts/gen-xray-keys.sh)."
  }

  # 端口冲突检查
  validation {
    condition     = !(var.config.hysteria_enable && var.config.xray_enable) || var.config.hysteria_port != var.config.xray_port
    error_message = "Port conflict: hysteria_port and xray_port must differ when both are enabled."
  }

  validation {
    condition     = !(var.config.shadowsocks_enable && var.config.hysteria_enable) || var.config.shadowsocks_libev_port != var.config.hysteria_port
    error_message = "Port conflict: shadowsocks_libev_port and hysteria_port must differ when both are enabled."
  }

  validation {
    condition     = !(var.config.shadowsocks_enable && var.config.xray_enable) || var.config.shadowsocks_libev_port != var.config.xray_port
    error_message = "Port conflict: shadowsocks_libev_port and xray_port must not be the same when both protocols are enabled."
  }

  validation {
    condition     = !(var.config.anytls_enable && var.config.shadowsocks_enable) || var.config.anytls_port != var.config.shadowsocks_libev_port
    error_message = "Port conflict: anytls_port and shadowsocks_libev_port must differ when both are enabled."
  }

  validation {
    condition     = !(var.config.anytls_enable && var.config.hysteria_enable) || var.config.anytls_port != var.config.hysteria_port
    error_message = "Port conflict: anytls_port and hysteria_port must differ when both are enabled."
  }

  validation {
    condition     = !(var.config.anytls_enable && var.config.xray_enable) || var.config.anytls_port != var.config.xray_port
    error_message = "Port conflict: anytls_port and xray_port must differ when both are enabled."
  }

  validation {
    condition     = !(var.config.tuic_enable && var.config.shadowsocks_enable) || var.config.tuic_port != var.config.shadowsocks_libev_port
    error_message = "Port conflict: tuic_port and shadowsocks_libev_port must differ when both are enabled."
  }

  validation {
    condition     = !(var.config.tuic_enable && var.config.hysteria_enable) || var.config.tuic_port != var.config.hysteria_port
    error_message = "Port conflict: tuic_port and hysteria_port must differ when both are enabled."
  }

  validation {
    condition     = !(var.config.tuic_enable && var.config.xray_enable) || var.config.tuic_port != var.config.xray_port
    error_message = "Port conflict: tuic_port and xray_port must differ when both are enabled."
  }

  validation {
    condition     = !(var.config.tuic_enable && var.config.anytls_enable) || var.config.tuic_port != var.config.anytls_port
    error_message = "Port conflict: tuic_port and anytls_port must differ when both are enabled."
  }
}
