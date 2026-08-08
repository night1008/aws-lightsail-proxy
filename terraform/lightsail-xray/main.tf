locals {
  output_oss_object_key  = "outputs/xray-configs/${var.config.region}/${var.config.instance_name}.json"
  local_output_file_name = "outputs/xray-configs/${var.config.region}-${var.config.instance_name}.json"

  ip_address = (
    var.config.create_static_ip
    ? aws_lightsail_static_ip.instance[0].ip_address
    : aws_lightsail_instance.instance.public_ip_address
  )

  # 从 https://bing.com[/...] 解析出主机名，用于 dest 与 serverNames
  proxy_host_with_path = replace(replace(var.config.xray_proxy_url, "https://", ""), "http://", "")
  dest_host            = split("/", local.proxy_host_with_path)[0]
  dest                 = "${local.dest_host}:443"

  # VLESS+REALITY 分享链接
  # vless://<uuid>@<host>:<port>?encryption=none&flow=xtls-rprx-vision&type=tcp
  #        &security=reality&sni=<sni>&fp=chrome&pbk=<publicKey>&sid=<shortId>#<tag>
  xray_url = format(
    "vless://%s@%s:%d?encryption=none&flow=xtls-rprx-vision&type=tcp&security=reality&sni=%s&fp=chrome&pbk=%s#%s",
    random_uuid.user_id.result,
    local.ip_address,
    var.config.xray_port,
    local.dest_host,
    var.config.xray_public_key,
    format("%s-%s", var.config.region, var.config.instance_name),
  )
}

resource "random_uuid" "user_id" {}

resource "random_uuid" "static_ip_name" {}

resource "aws_lightsail_static_ip" "instance" {
  count = var.config.create_static_ip ? 1 : 0
  name  = format("%s-%s", "static-ip", random_uuid.static_ip_name.result)

  depends_on = [
    random_uuid.static_ip_name
  ]
}

resource "aws_lightsail_static_ip_attachment" "instance" {
  count          = var.config.create_static_ip ? 1 : 0
  static_ip_name = aws_lightsail_static_ip.instance[count.index].id
  instance_name  = aws_lightsail_instance.instance.id
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

  user_data = <<-EOT
#!/bin/bash
set -eux

apt update
apt install -y curl

# 关闭 Ubuntu 自带防火墙（Lightsail 云防火墙已控制端口）
ufw disable || true

# 安装 Xray（官方脚本，自动创建 /usr/local/etc/xray/ 与 xray.service）
curl -fsSL https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh -o /tmp/xray2_install.sh
bash /tmp/xray2_install.sh

# 写入服务端配置
cat > /usr/local/etc/xray/config.json <<'EOF'
{
  "inbounds": [
    {
      "port": ${var.config.xray_port},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${random_uuid.user_id.result}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "${local.dest}",
          "xver": 0,
          "serverNames": ["${local.dest_host}"],
          "privateKey": "${var.config.xray_private_key}",
          "shortIds": [""]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF

systemctl enable xray
systemctl restart xray
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
    "xray_config" = {
      "port"       = var.config.xray_port,
      "uuid"       = random_uuid.user_id.result,
      "public_key" = var.config.xray_public_key,
      "sni"        = local.dest_host,
      "proxy_url"  = var.config.xray_proxy_url,
    },
    "xray_url" = local.xray_url,
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
