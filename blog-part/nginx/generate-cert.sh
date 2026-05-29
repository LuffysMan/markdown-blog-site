#!/usr/bin/env bash

####################################################################################
# 为 Nginx 生成自签名证书
# 依赖: openssl
# 产物: nginx/ssl/nginx.crt + nginx/ssl/nginx.key
# 有效: 10 年
####################################################################################

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SSL_DIR="${SCRIPT_DIR}/ssl"

mkdir -p "${SSL_DIR}"

openssl req -x509 -nodes -newkey rsa:2048 \
    -keyout "${SSL_DIR}/nginx.key" \
    -out    "${SSL_DIR}/nginx.crt" \
    -days   3650 \
    -subj   "/CN=localhost/O=LandofC/OU=Blog" \
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"

chmod 600 "${SSL_DIR}/nginx.key"
chmod 644 "${SSL_DIR}/nginx.crt"

echo "Certificates generated:"
echo "  CRT: ${SSL_DIR}/nginx.crt"
echo "  KEY: ${SSL_DIR}/nginx.key"
