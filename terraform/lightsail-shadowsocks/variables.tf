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
    shadowsocks_libev_port            = number # shadowsocks-libev config port
    shadowsocks_libev_password_length = number # shadowsocks-libev password length
    shadowsocks_libev_method          = string # shadowsocks-libev config method
  })
  default = {
    region                            = "ap-northeast-1"
    instance_name                     = "test1"
    availability_zone                 = "ap-northeast-1a"
    create_static_ip                  = true
    shadowsocks_libev_port            = 8388
    shadowsocks_libev_password_length = 10
    shadowsocks_libev_method          = "chacha20-ietf-poly1305"
  }

  validation {
    condition     = var.config.region == substr(var.config.availability_zone, 0, length(var.config.availability_zone) - 1)
    error_message = "The instance availability_zone must be in the same region."
  }
}