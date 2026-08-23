locals {
  output_oss_object_key  = "outputs/tuic-configs/${var.config.region}/${var.config.instance_name}.json"
  local_output_file_name = "outputs/tuic-configs/${var.config.region}-${var.config.instance_name}.json"

  proxy_host_with_path = replace(replace(var.config.tuic_proxy_url, "https://", ""), "http://", "")
  sni                  = split("/", local.proxy_host_with_path)[0]

  tuic_port = var.config.tuic_port != null ? var.config.tuic_port : 8445

  ip_address = (
    var.config.create_static_ip
    ? aws_lightsail_static_ip.instance[0].ip_address
    : aws_lightsail_instance.instance.public_ip_address
  )

  # tuic://<uuid>:<password>@<host>:<port>?sni=<sni>&congestion_control=bbr&insecure=1#<tag>
  tuic_url = format(
    "tuic://%s:%s@%s:%d?sni=%s&congestion_control=bbr&insecure=1#%s",
    random_uuid.user_uuid.result,
    urlencode(random_password.password.result),
    local.ip_address,
    local.tuic_port,
    local.sni,
    format("%s-%s", var.config.region, var.config.instance_name),
  )
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

resource "random_uuid" "user_uuid" {}

resource "random_password" "password" {
  length           = var.config.tuic_password_length
  special          = true
  override_special = "_"
}

resource "aws_lightsail_instance" "instance" {
  name              = format("%s-%s", "instance", var.config.instance_name)
  availability_zone = var.config.availability_zone
  blueprint_id      = "ubuntu_24_04"
  bundle_id         = "nano_2_0"

  depends_on = [
    aws_lightsail_static_ip.instance
  ]

  user_data = <<-EOT
#!/bin/bash
set -eux

apt update
apt install -y curl openssl ca-certificates

# 安装 sing-box
curl -fsSL https://sing-box.app/deb-install.sh | bash

mkdir -p /etc/sing-box

# 生成自签证书
openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:P-256 \
  -keyout /etc/sing-box/server.key \
  -out /etc/sing-box/server.crt \
  -subj "/CN=${local.sni}" -days 36500

chmod 644 /etc/sing-box/server.key
chmod 644 /etc/sing-box/server.crt

# 写入服务端配置
cat > /etc/sing-box/config.json <<'EOF'
{
  "inbounds": [
    {
      "type": "tuic",
      "tag": "tuic-in",
      "listen": "::",
      "listen_port": ${local.tuic_port},
      "users": [
        {
          "uuid": "${random_uuid.user_uuid.result}",
          "password": "${random_password.password.result}"
        }
      ],
      "congestion_control": "bbr",
      "tls": {
        "enabled": true,
        "certificate_path": "/etc/sing-box/server.crt",
        "key_path": "/etc/sing-box/server.key"
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct"
    }
  ]
}
EOF

# 关闭 Ubuntu 自带防火墙
ufw disable || true

systemctl enable sing-box
systemctl restart sing-box
EOT
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
    "instance_name"     = format("%s-%s", var.config.region, var.config.instance_name),
    "public_ip_address" = aws_lightsail_instance.instance.public_ip_address,
    "static_ip"         = var.config.create_static_ip ? aws_lightsail_static_ip.instance[0].ip_address : ""
    "tuic_config" = {
      "listen"    = local.tuic_port,
      "uuid"      = random_uuid.user_uuid.result,
      "password"  = random_password.password.result,
      "sni"       = local.sni,
      "proxy_url" = var.config.tuic_proxy_url,
    },
    "tuic_url" = local.tuic_url,
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
