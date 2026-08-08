locals {
  output_oss_object_key  = "outputs/hysteria-configs/${var.config.region}/${var.config.instance_name}.json"
  local_output_file_name = "outputs/hysteria-configs/${var.config.region}-${var.config.instance_name}.json"

  # 从 https://bing.com[/...] 中解析出主机段，用作自签证书 CN 与客户端 SNI
  proxy_host_with_path = replace(replace(var.config.hysteria_proxy_url, "https://", ""), "http://", "")
  sni                  = split("/", local.proxy_host_with_path)[0]

  hysteria_port = var.config.hysteria_port

  ip_address = (
    var.config.create_static_ip
    ? aws_lightsail_static_ip.instance[0].ip_address
    : aws_lightsail_instance.instance.public_ip_address
  )

  # hysteria2://<password>@<host>:<port>?sni=<sni>&insecure=1&udp=true#<tag>
  # 自签证书需要 insecure=1；udp=true 显式开启 UDP 转发（Hysteria2 默认已支持 UDP）；password 中可能含 @/% 等字符，URL 编码后再拼接
  hysteria_url = format(
    "hysteria2://%s@%s:%d?sni=%s&insecure=1&udp=1#%s",
    urlencode(random_password.password.result),
    local.ip_address,
    local.hysteria_port,
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

resource "random_password" "password" {
  length           = var.config.hysteria_password_length
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

  user_data = <<-EOT
#!/bin/bash

apt update
apt install -y curl openssl ca-certificates

# 安装 hysteria2（脚本会自动创建 /etc/hysteria 目录与 hysteria-server.service）
curl -fsSL https://get.hy2.sh/ -o /tmp/hy2_install.sh
bash /tmp/hy2_install.sh

# 生成自签证书
openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:P-256 \
  -keyout /etc/hysteria/server.key \
  -out /etc/hysteria/server.crt \
  -subj "/CN=${local.sni}" -days 36500

chmod 644 /etc/hysteria/server.key
chmod 644 /etc/hysteria/server.crt

# 写入服务端配置
cat > /etc/hysteria/config.yaml <<'EOF'
listen: :${local.hysteria_port}

tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key

auth:
  type: password
  password: '${random_password.password.result}'

masquerade:
  type: proxy
  proxy:
    url: '${var.config.hysteria_proxy_url}'
    rewriteHost: true
EOF

# 关闭 Ubuntu 自带防火墙（Lightsail 云防火墙已控制端口），否则 UDP/443 被阻导致 QUIC 超时
ufw disable || true

systemctl enable hysteria-server
systemctl restart hysteria-server
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
    "hysteria_config" = {
      "listen"    = local.hysteria_port,
      "password"  = random_password.password.result,
      "sni"       = local.sni,
      "proxy_url" = var.config.hysteria_proxy_url,
    },
    "hysteria_url" = local.hysteria_url,
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