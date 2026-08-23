variable "config" {
  description = "aws lightsail anytls instance config"
  type = object({
    region                 = string # aws lightsail region
    instance_name          = string # aws lightsail instance name
    availability_zone      = string # aws lightsail instance availability zone
    create_static_ip      = bool   # create lightsail static ip
    anytls_port            = optional(number, 8444) # anytls listen port，默认 8444
    anytls_password_length = number # anytls password length
    anytls_proxy_url       = string # masquerade proxy url, e.g. https://bing.com
  })
}

variable "output_oss_bucket" {
  description = "alicloud bucket name for config output"
  type        = string
  default     = "aws-lightsail-terraform"
}
