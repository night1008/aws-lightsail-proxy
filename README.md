# aws-lightsail-proxy

使用 Terraform 在 AWS Lightsail 上管理代理节点，配套 Next.js 可视化配置页面。

## 整体架构

```
                            ┌────────────────────┐
                            │                    │
                            │     Aliyun OSS     │
       ┌────────────────────│                    │◀───────────────────┐
       │                    │                    │                    │
       │                    └────────────────────┘                    │
       │                               │                              │
       │                               │                              │
       │                               │                              │
       │                               │                              │
       ▼                               ▼                              │
┌─────────────┐                ┌──────────────┐               ┌───────────────┐
│             │                │              │               │               │
│   Vercel    │                │    Github    │               │   Terraform   │
│  (Nextjs)   │───────────────▶│    Action    │──────────────▶│               │
│             │                │              │               │               │
└─────────────┘                └──────────────┘               └───────────────┘
```

## 项目结构
├── terraform/         # Terraform 配置（部署 Lightsail 实例）
│   ├── lightsail-combined/     # 多协议合一模块
│   ├── lightsail-hysteria/     # Hysteria2 独立模块
│   ├── lightsail-shadowsocks/  # Shadowsocks 独立模块
│   ├── lightsail-xray/         # Xray VLESS+REALITY 独立模块
│   └── scripts/                # 工具脚本
├── web/               # Next.js 可视化配置页面（部署到 Vercel）
└── .github/workflows/ # GitHub Actions CI（触发 Terraform）
```

## 支持协议

| 模块 | 协议 | 端口 |
| --- | --- | --- |
| `lightsail-shadowsocks` | Shadowsocks-libev | 8388（可配置） |
| `lightsail-hysteria` | Hysteria2 | 8443（可配置） |
| `lightsail-xray` | VLESS + REALITY | 443（可配置） |
| `lightsail-combined` | 以上三种协议按需组合 | — |

---

### 准备工作
1. AWS Access Key（用于创建 Lightsail 实例）
2. 阿里云 OSS Access Key（用于写出配置文件）
3. 创建一个 OSS Bucket（**最好选择海外 Region**，如新加坡 `oss-ap-southeast-1`）

### Terraform 执行命令

```bash
cd terraform

export AWS_ACCESS_KEY_ID=xxx AWS_SECRET_ACCESS_KEY=xxx

export ALICLOUD_ACCESS_KEY=xxx ALICLOUD_SECRET_KEY=xxx ALICLOUD_REGION=oss-ap-southeast-1 ALICLOUD_BUCKET=aws-lightsail-terraform

cp terraform.tfvars.json.example terraform.tfvars.json
# 编辑 terraform.tfvars.json，填入所需实例配置

terraform init -backend-config="bucket=aws-lightsail-terraform"

terraform apply
```

#### 使用 Xray VLESS+REALITY 时，需先生成 x25519 密钥对

```bash
chmod +x scripts/gen-xray-keys.sh
./scripts/gen-xray-keys.sh
# 将输出的 Private key / Public key 填入 terraform.tfvars.json
```

### Web 配置页面

```bash
cd web
npm install
npm run dev
# 访问 http://localhost:3000
```

部署到 Vercel 时，Root Directory 设置为 `web`。

### 输出结果

每个实例的 IP 与协议配置会同时写入 OSS 和本地 `outputs/` 目录。

```
terraform/outputs/
  shadowsocks-configs/
  hysteria-configs/
  xray-configs/
  combined-configs/
    <region>-<instance_name>.json
```

| 模块 | 分享链接字段 | 格式 |
| --- | --- | --- |
| shadowsocks | `shadowsocks_url` | `ss://BASE64@host:port#tag` |
| hysteria | `hysteria_url` | `hysteria2://pass@host:port?sni=...&insecure=1#tag` |
| xray | `xray_url` | `vless://uuid@host:443?security=reality&...#tag` |
| combined | 以上字段按启用协议包含 | — |

### 下载 OSS 配置文件

```bash
cd terraform
chmod +x scripts/download-oss-file.sh
./scripts/download-oss-file.sh outputs/xray-configs/ap-northeast-1/xray-1.json ./local.json
```
