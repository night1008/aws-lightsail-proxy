# aws-lightsail-shadowsocks-tf
使用 Terraform 在 AWS Lightsail 上管理代理节点，支持以下协议：

| 模块 | 协议 | 端口 |
| --- | --- | --- |
| `lightsail-shadowsocks` | Shadowsocks-libev | 8388（可配置） |
| `lightsail-hysteria` | Hysteria2 | 443（可配置） |
| `lightsail-xray` | VLESS + REALITY | 443（可配置） |
| `lightsail-combined` | 以上三种协议按需组合 | — |

---

### 准备工作
1. AWS Access Key（用于创建 Lightsail 实例）
2. 阿里云 OSS Access Key（用于写出配置文件）
3. 创建一个 OSS Bucket（**最好选择海外 Region**，如新加坡 `oss-ap-southeast-1`）

### 注意点
1. OSS backend 与 `output_oss_bucket` 变量需指定同一个 Bucket
2. 可在任意 AWS Region 内创建多个实例

### 执行命令

```bash
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

### 输出结果

每个实例的 IP 与协议配置会同时写入 OSS 和本地 `outputs/` 目录，实例销毁时对应文件自动删除。

```
outputs/
  shadowsocks-configs/
    <region>-<instance_name>.json
  hysteria-configs/
    <region>-<instance_name>.json
  xray-configs/
    <region>-<instance_name>.json
  combined-configs/
    <region>-<instance_name>.json
```

各输出文件包含实例 IP、协议配置详情以及可直接导入客户端的分享链接：

| 模块 | 分享链接字段 | 格式 |
| --- | --- | --- |
| shadowsocks | `shadowsocks_url` | `ss://BASE64@host:port#tag` |
| hysteria | `hysteria_url` | `hysteria2://pass@host:443?sni=...&insecure=1#tag` |
| xray | `xray_url` | `vless://uuid@host:443?security=reality&...#tag` |
| combined | 以上字段按启用协议包含 | — |

`shadowsocks_url`、`hysteria_url`、`xray_url` 均可直接在 **Shadowrocket / Clash / Clash Verge** 中通过 URL 导入，无需手动填写配置。

### 下载 OSS 配置文件

```bash
chmod +x scripts/download-oss-file.sh
./scripts/download-oss-file.sh outputs/xray-configs/ap-northeast-1/xray-1.json ./local.json
```

### 测试工具

通过 [TCP port check](http://port.ping.pe) 测试实例连通性。

### TODO
- [ ] 输出 OSS config file URL
- [x] 一次开启多个地区实例
- [x] 支持 Shadowsocks
- [x] 支持 Hysteria2
- [x] 支持 Xray VLESS+REALITY
- [x] 一个实例同时开启多协议（combined 模块）
