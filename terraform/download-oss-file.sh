#!/bin/bash

accessKey="$ALICLOUD_ACCESS_KEY"
accessSecret="$ALICLOUD_SECRET_KEY"
host="oss-${ALICLOUD_REGION}.aliyuncs.com"
bucket="${ALICLOUD_BUCKET}"

source="$1"
dest="$2"

osshost=$bucket.$host
resource="/${bucket}/${source}"
contentType=""
dateValue="`TZ=GMT env LANG=en_US.UTF-8 date +'%a, %d %b %Y %H:%M:%S GMT'`"
stringToSign="GET\n\n${contentType}\n${dateValue}\n${resource}"
signature=`echo -en $stringToSign | openssl sha1 -hmac ${accessSecret} -binary | base64`

url=http://${osshost}/${source}
echo "download ${url} to ${dest}"

curl --create-dirs \
    -H "Host: ${osshost}" \
    -H "Date: ${dateValue}" \
    -H "Content-Type: ${contentType}" \
    -H "Authorization: OSS ${accessKey}:${signature}" \
    ${url} -o ${dest}
