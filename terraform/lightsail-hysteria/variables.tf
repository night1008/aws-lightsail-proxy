variable "output_oss_bucket" {
  type    = string
  default = "aws-lightsail-terraform"
}

variable "config" {
  type = object({
    region            = string # aws lightsail region
    instance_name     = string # aws lightsail instance name
    availability_zone = string # aws lightsail instance availability zone
    create_static_ip         = bool   # create lightsail static ip
    hysteria_port            = optional(number, 8443) # hysteria2 listen port，默认 8443
    hysteria_password_length = number # hysteria2 password length
    hysteria_proxy_url       = string # masquerade proxy url, e.g. https://bing.com
  })
  default = {
    region            = "ap-northeast-1"
    instance_name     = "test1"
    availability_zone = "ap-northeast-1a"
    create_static_ip         = true
    hysteria_port            = 8443
    hysteria_password_length = 16
    hysteria_proxy_url       = "https://bing.com"
  }

  validation {
    condition     = var.config.region == substr(var.config.availability_zone, 0, length(var.config.availability_zone) - 1)
    error_message = "The instance availability_zone must be in the same region."
  }

  validation {
    condition     = can(regex("^https?://[^/]+", var.config.hysteria_proxy_url))
    error_message = "hysteria_proxy_url must be a valid http(s) url."
  }
}
