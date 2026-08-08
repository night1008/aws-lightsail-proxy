variable "output_oss_bucket" {
  type    = string
  default = "aws-lightsail-terraform"
}

variable "config" {
  type = object({
    region                            = string # aws lightsail region
    instance_name                     = string # aws lightsail instance name
    availability_zone                 = string # aws lightsail instance availability zone
    create_static_ip                  = bool   # create lightsail static ip
    # 协议开关
    shadowsocks_enable                = bool # 是否启用 shadowsocks-libev
    hysteria_enable                   = bool # 是否启用 hysteria2
    xray_enable                       = bool # 是否启用 xray (VLESS+REALITY)
    # shadowsocks-libev（shadowsocks_enable = true 时生效）
    shadowsocks_libev_port            = number # shadowsocks-libev listen port
    shadowsocks_libev_password_length = number # shadowsocks-libev password length
    shadowsocks_libev_method          = string # shadowsocks-libev cipher method
    # hysteria2（hysteria_enable = true 时生效）
    hysteria_port                    = optional(number, 443) # hysteria2 listen port，默认 443
    hysteria_password_length          = number # hysteria2 password length
    hysteria_proxy_url                = string # masquerade proxy url, e.g. https://bing.com
    # xray VLESS+REALITY（xray_enable = true 时生效）
    xray_port                         = number # xray listen port，建议使用 443
    xray_proxy_url                    = string # REALITY 伪装目标 URL，如 https://bing.com
    xray_private_key                  = string # x25519 私钥（base64url，无填充），服务端使用
    xray_public_key                   = string # x25519 公钥（base64url，无填充），客户端使用
  })
  default = {
    region                            = "ap-northeast-1"
    instance_name                     = "test1"
    availability_zone                 = "ap-northeast-1a"
    create_static_ip                  = true
    shadowsocks_enable                = false
    hysteria_enable                   = false
    xray_enable                       = false
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
  }

  validation {
    condition     = var.config.region == substr(var.config.availability_zone, 0, length(var.config.availability_zone) - 1)
    error_message = "The instance availability_zone must be in the same region."
  }

  validation {
    condition     = var.config.shadowsocks_enable || var.config.hysteria_enable || var.config.xray_enable
    error_message = "At least one protocol must be enabled (shadowsocks_enable, hysteria_enable, or xray_enable)."
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
    condition     = !var.config.xray_enable || (length(var.config.xray_private_key) > 0 && length(var.config.xray_public_key) > 0)
    error_message = "xray_private_key and xray_public_key must be provided when xray_enable is true (generate with: scripts/gen-xray-keys.sh)."
  }

  # 端口冲突检查
  # hysteria_port 与 xray_port 不能相同
  validation {
    condition     = !(var.config.hysteria_enable && var.config.xray_enable) || var.config.hysteria_port != var.config.xray_port
    error_message = "Port conflict: hysteria_port and xray_port must differ when both are enabled."
  }

  # shadowsocks 端口不能与 hysteria_port 冲突
  validation {
    condition     = !(var.config.shadowsocks_enable && var.config.hysteria_enable) || var.config.shadowsocks_libev_port != var.config.hysteria_port
    error_message = "Port conflict: shadowsocks_libev_port and hysteria_port must differ when both are enabled."
  }

  # shadowsocks 端口不能与 xray_port 冲突
  validation {
    condition     = !(var.config.shadowsocks_enable && var.config.xray_enable) || var.config.shadowsocks_libev_port != var.config.xray_port
    error_message = "Port conflict: shadowsocks_libev_port and xray_port must not be the same when both protocols are enabled."
  }
}
