locals {
  output_oss_object_key  = "outputs/combined-configs/${var.config.region}/${var.config.instance_name}.json"
  local_output_file_name = "outputs/combined-configs/${var.config.region}-${var.config.instance_name}.json"

  ip_address = (
    var.config.create_static_ip
    ? aws_lightsail_static_ip.instance[0].ip_address
    : aws_lightsail_instance.instance.public_ip_address
  )

  # Shadowsocks
  ss_config = var.config.shadowsocks_enable ? {
    "server"      = ["0.0.0.0"],
    "mode"        = "tcp_and_udp",
    "server_port" = var.config.shadowsocks_libev_port,
    "local_port"  = 1080,
    "password"    = random_password.ss_password[0].result,
    "timeout"     = 60,
    "method"      = var.config.shadowsocks_libev_method
  } : null

  shadowsocks_url = var.config.shadowsocks_enable ? format(
    "ss://%s#%s",
    base64encode(format("%s:%s@%s:%d", var.config.shadowsocks_libev_method, random_password.ss_password[0].result, local.ip_address, var.config.shadowsocks_libev_port)),
    format("%s-%s", var.config.region, var.config.instance_name)
  ) : null

  # Hysteria2
  hysteria_port        = var.config.hysteria_port
  proxy_host_with_path = replace(replace(var.config.hysteria_proxy_url, "https://", ""), "http://", "")
  sni                  = split("/", local.proxy_host_with_path)[0]

  hysteria_url = var.config.hysteria_enable ? format(
    "hysteria2://%s@%s:%d?sni=%s&insecure=1&udp=1#%s",
    urlencode(random_password.hy_password[0].result),
    local.ip_address,
    local.hysteria_port,
    local.sni,
    format("%s-%s", var.config.region, var.config.instance_name)
  ) : null

  # Xray VLESS+REALITY
  xray_proxy_host_with_path = replace(replace(var.config.xray_proxy_url, "https://", ""), "http://", "")
  xray_dest_host            = split("/", local.xray_proxy_host_with_path)[0]
  xray_dest                 = "${local.xray_dest_host}:443"

  xray_url = var.config.xray_enable ? format(
    "vless://%s@%s:%d?encryption=none&flow=xtls-rprx-vision&type=tcp&security=reality&sni=%s&fp=chrome&pbk=%s#%s",
    random_uuid.xray_user_id[0].result,
    local.ip_address,
    var.config.xray_port,
    local.xray_dest_host,
    var.config.xray_public_key,
    format("%s-%s", var.config.region, var.config.instance_name)
  ) : null
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

resource "random_password" "ss_password" {
  count            = var.config.shadowsocks_enable ? 1 : 0
  length           = var.config.shadowsocks_libev_password_length
  special          = true
  override_special = "_"
}

resource "random_password" "hy_password" {
  count            = var.config.hysteria_enable ? 1 : 0
  length           = var.config.hysteria_password_length
  special          = true
  override_special = "_"
}

resource "random_uuid" "xray_user_id" {
  count = var.config.xray_enable ? 1 : 0
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

ENABLE_SS=${var.config.shadowsocks_enable ? "true" : "false"}
ENABLE_HY=${var.config.hysteria_enable ? "true" : "false"}
ENABLE_XRAY=${var.config.xray_enable ? "true" : "false"}

apt update
apt install -y curl openssl ca-certificates

# 关闭 Ubuntu 自带防火墙（Lightsail 云防火墙已控制端口）
ufw disable || true

# ── Shadowsocks-libev ───────────────────────────────────────────────────────
if [ "$ENABLE_SS" = "true" ]; then
  apt install -y shadowsocks-libev
  cat > /etc/shadowsocks-libev/config.json <<'EOF'
{
  "server": ["0.0.0.0"],
  "mode": "tcp_and_udp",
  "server_port": ${var.config.shadowsocks_libev_port},
  "local_port": 1080,
  "password": "${var.config.shadowsocks_enable ? random_password.ss_password[0].result : ""}",
  "timeout": 60,
  "method": "${var.config.shadowsocks_libev_method}"
}
EOF
  systemctl enable shadowsocks-libev
  systemctl restart shadowsocks-libev
fi

# ── Hysteria2 ───────────────────────────────────────────────────────────────
if [ "$ENABLE_HY" = "true" ]; then
  curl -fsSL https://get.hy2.sh/ -o /tmp/hy2_install.sh
  bash /tmp/hy2_install.sh

  openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:P-256 \
    -keyout /etc/hysteria/server.key \
    -out /etc/hysteria/server.crt \
    -subj "/CN=${local.sni}" -days 36500
  chmod 644 /etc/hysteria/server.key /etc/hysteria/server.crt

  cat > /etc/hysteria/config.yaml <<'EOF'
listen: :${local.hysteria_port}

tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key

auth:
  type: password
  password: '${var.config.hysteria_enable ? random_password.hy_password[0].result : ""}'

masquerade:
  type: proxy
  proxy:
    url: '${var.config.hysteria_proxy_url}'
    rewriteHost: true
EOF

  systemctl enable hysteria-server
  systemctl restart hysteria-server
fi

# ── Xray VLESS+REALITY ────────────────────────────────────────────────────────
if [ "$ENABLE_XRAY" = "true" ]; then
  curl -fsSL https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh -o /tmp/xray2_install.sh
  bash /tmp/xray2_install.sh

  cat > /usr/local/etc/xray/config.json <<'EOF'
{
  "inbounds": [
    {
      "port": ${var.config.xray_port},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${var.config.xray_enable ? random_uuid.xray_user_id[0].result : ""}",
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
          "dest": "${local.xray_dest}",
          "xver": 0,
          "serverNames": ["${local.xray_dest_host}"],
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
fi
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
    "instance_name"      = format("%s-%s", var.config.region, var.config.instance_name),
    "public_ip_address"  = aws_lightsail_instance.instance.public_ip_address,
    "static_ip"          = var.config.create_static_ip ? aws_lightsail_static_ip.instance[0].ip_address : ""
    "shadowsocks_config" = var.config.shadowsocks_enable ? local.ss_config : null,
    "shadowsocks_url"     = var.config.shadowsocks_enable ? local.shadowsocks_url : null,
    "hysteria_config" = var.config.hysteria_enable ? {
      "listen"    = local.hysteria_port,
      "password"  = random_password.hy_password[0].result,
      "sni"       = local.sni,
      "proxy_url" = var.config.hysteria_proxy_url,
    } : null,
    "hysteria_url" = var.config.hysteria_enable ? local.hysteria_url : null,
    "xray_config" = var.config.xray_enable ? {
      "port"       = var.config.xray_port,
      "uuid"       = random_uuid.xray_user_id[0].result,
      "public_key" = var.config.xray_public_key,
      "sni"        = local.xray_dest_host,
      "proxy_url"  = var.config.xray_proxy_url,
    } : null,
    "xray_url" = var.config.xray_enable ? local.xray_url : null,
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
