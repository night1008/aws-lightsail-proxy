locals {
  output_oss_object_key  = "outputs/shadowsocks-configs/${var.config.region}/${var.config.instance_name}.json"
  local_output_file_name = "outputs/shadowsocks-configs/${var.config.region}-${var.config.instance_name}.json"

  shadowsocks_libev_config = {
    "server"      = ["0.0.0.0"],
    "mode"        = "tcp_and_udp",
    "server_port" = var.config.shadowsocks_libev_port,
    "local_port"  = 1080,
    "password"    = random_password.password.result,
    "timeout"     = 60,
    "method"      = var.config.shadowsocks_libev_method
  }
}

resource "aws_lightsail_static_ip_attachment" "instance" {
  count          = var.config.create_static_ip ? 1 : 0
  static_ip_name = aws_lightsail_static_ip.instance[count.index].id
  instance_name  = aws_lightsail_instance.instance.id
}

resource "random_uuid" "static_ip_name" {}

resource "aws_lightsail_static_ip" "instance" {
  count = var.config.create_static_ip ? 1 : 0
  name  = format("%s-%s", "static-ip", random_uuid.static_ip_name.result)

  depends_on = [
    random_uuid.static_ip_name
  ]
}

resource "random_password" "password" {
  length           = var.config.shadowsocks_libev_password_length
  special          = true
  override_special = "_"
}

resource "aws_lightsail_instance" "instance" {
  name              = format("%s-%s", "instance", var.config.instance_name)
  availability_zone = var.config.availability_zone
  blueprint_id      = "ubuntu_24_04"
  bundle_id         = "nano_2_0"
  # key_pair_name     = "some_key_name"

  depends_on = [
    aws_lightsail_static_ip.instance
  ]

  user_data = <<-EOF
  #!/bin/bash
  apt update
  apt install shadowsocks-libev -y
  sudo sh -c 'echo "{
    \"server\":[\"0.0.0.0\"],
    \"mode\":\"tcp_and_udp\",
    \"server_port\":${var.config.shadowsocks_libev_port},
    \"local_port\":1080,
    \"password\":\"${random_password.password.result}\",
    \"timeout\":60,
    \"method\":\"${var.config.shadowsocks_libev_method}\"
  }" > /etc/shadowsocks-libev/config.json'
  systemctl restart shadowsocks-libev
  EOF
}

resource "aws_lightsail_instance_public_ports" "instance" {
  instance_name = aws_lightsail_instance.instance.name

  port_info {
    protocol  = "all"
    from_port = 0
    to_port   = 65535
    cidrs = [
      "0.0.0.0/0"
    ]
  }

  depends_on = [
    aws_lightsail_instance.instance
  ]
}

resource "alicloud_oss_bucket_object" "object" {
  bucket = var.output_oss_bucket
  key    = local.output_oss_object_key
  content = jsonencode({
    "instance_name"      = format("%s-%s", var.config.region, var.config.instance_name),
    "shadowsocks_config" = local.shadowsocks_libev_config,
    "public_ip_address"  = aws_lightsail_instance.instance.public_ip_address,
    "static_ip"          = var.config.create_static_ip ? aws_lightsail_static_ip.instance[0].ip_address : ""
    "shadowsocks_url" = format(
      "ss://%s@%s:%d#%s",
      base64encode(format("%s:%s", var.config.shadowsocks_libev_method, random_password.password.result)),
      var.config.create_static_ip ? aws_lightsail_static_ip.instance[0].ip_address : aws_lightsail_instance.instance.public_ip_address,
      var.config.shadowsocks_libev_port,
      format("%s-%s", var.config.region, var.config.instance_name)
    )
  })

  depends_on = [
    aws_lightsail_instance_public_ports.instance
  ]
}

resource "local_file" "object" {
  filename = local.local_output_file_name
  content  = alicloud_oss_bucket_object.object.content

  depends_on = [
    alicloud_oss_bucket_object.object
  ]
}
