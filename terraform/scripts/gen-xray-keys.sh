#!/usr/bin/env bash
# 生成 Xray REALITY 所需的 x25519 密钥对（base64url，无填充）
# 优先使用 xray x25519，fallback 使用 openssl + python3
set -euo pipefail

if command -v xray &>/dev/null; then
  OUTPUT=$(xray x25519)
  PRIVATE_KEY=$(echo "$OUTPUT" | grep "Private key:" | awk '{print $3}')
  PUBLIC_KEY=$(echo "$OUTPUT"  | grep "Public key:"  | awk '{print $3}')
else
  command -v openssl &>/dev/null || { echo "ERROR: openssl not found" >&2; exit 1; }
  command -v python3  &>/dev/null || { echo "ERROR: python3 not found" >&2; exit 1; }

  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT

  openssl genpkey -algorithm X25519 -out "$TMP/priv.pem" 2>/dev/null
  openssl pkey -in "$TMP/priv.pem"         -outform DER 2>/dev/null | tail -c 32 > "$TMP/priv.raw"
  openssl pkey -in "$TMP/priv.pem" -pubout -outform DER 2>/dev/null | tail -c 32 > "$TMP/pub.raw"

  PRIVATE_KEY=$(python3 -c "
import base64, sys
d = open('$TMP/priv.raw', 'rb').read()
print(base64.urlsafe_b64encode(d).decode().rstrip('='))
")
  PUBLIC_KEY=$(python3 -c "
import base64, sys
d = open('$TMP/pub.raw', 'rb').read()
print(base64.urlsafe_b64encode(d).decode().rstrip('='))
")
fi

echo "Private key: $PRIVATE_KEY"
echo "Public key:  $PUBLIC_KEY"
echo ""
echo "# 将以下内容填入 terraform.tfvars.json 对应的 xray_instances 条目："
echo "\"xray_private_key\": \"$PRIVATE_KEY\","
echo "\"xray_public_key\":  \"$PUBLIC_KEY\""
