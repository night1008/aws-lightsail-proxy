variable "config" {
  description = "aws lightsail tuic v5 instance config"
  type = object({
    region               = string # aws lightsail region
    instance_name        = string # aws lightsail instance name
    availability_zone    = string # aws lightsail instance availability zone
    create_static_ip    = bool   # create lightsail static ip
    tuic_port            = optional(number, 8445) # tuic listen port，默认 8445
    tuic_password_length = number # tuic password length
    tuic_proxy_url       = string # masquerade proxy url, e.g. https://bing.com
  })
}

variable "output_oss_bucket" {
  description = "alicloud bucket name for config output"
  type        = string
  default     = "aws-lightsail-terraform"
}
