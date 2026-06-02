#!/bin/bash

# 自签名证书生成脚本
# 适用于CentOS系统，依赖openssl
# 生成CA证书和Nginx服务器证书，有效期50年

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 证书输出目录
CERTS_DIR="certs"

# 证书配置变量
DAYS=18250  # 50年 ≈ 18250天
KEY_BITS=2048
HASH_ALGO="sha256"

# 证书主题信息
CA_COUNTRY="CN"
CA_STATE="Sichuan"
CA_CITY="Sichuan"
CA_ORG="Self-Signed CA"
CA_OU="IT Department"
CA_CN="Self-Signed Root CA"

SERVER_COUNTRY="CN"
SERVER_STATE="Sichuan"
SERVER_CITY="Sichuan"
SERVER_ORG="Weave Inc"
SERVER_OU="Blog"
SERVER_CN="localhost"

# 可选：添加SAN（Subject Alternative Name）支持
SAN_DNS="DNS.1 = weave.com"
SAN_IP="IP.1 = 你的公网IP"

# 检查openssl是否安装
check_openssl() {
    if ! command -v openssl &> /dev/null; then
        echo -e "${RED}错误: openssl 未安装${NC}"
        echo "请执行: sudo yum install openssl -y"
        exit 1
    fi
    echo -e "${GREEN}✓ openssl 已安装: $(openssl version)${NC}"
}

# 检查文件是否已存在
check_existing_files() {
    local files=("ca.key" "ca.crt" "nginx.key" "nginx.crt")
    local existing=()

    for file in "${files[@]}"; do
        if [ -f "$CERTS_DIR/$file" ]; then
            existing+=("$file")
        fi
    done

    if [ ${#existing[@]} -gt 0 ]; then
        echo -e "${YELLOW}警告: 以下文件已存在:${NC}"
        printf '%s\n' "${existing[@]}"
        read -p "是否覆盖? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "操作已取消"
            exit 0
        fi
    fi
}

# 生成CA私钥
generate_ca_key() {
    echo -e "${GREEN}[1/6] 生成CA私钥...${NC}"
    openssl genrsa -out "$CERTS_DIR/ca.key" $KEY_BITS
    chmod 600 "$CERTS_DIR/ca.key"
    echo -e "${GREEN}✓ ca.key 已生成${NC}"
}

# 生成CA证书
generate_ca_cert() {
    echo -e "${GREEN}[2/6] 生成CA根证书...${NC}"
    openssl req -new -x509 \
        -days $DAYS \
        -key "$CERTS_DIR/ca.key" \
        -out "$CERTS_DIR/ca.crt" \
        -$HASH_ALGO \
        -subj "/C=$CA_COUNTRY/ST=$CA_STATE/L=$CA_CITY/O=$CA_ORG/OU=$CA_OU/CN=$CA_CN"
    chmod 644 "$CERTS_DIR/ca.crt"
    echo -e "${GREEN}✓ ca.crt 已生成${NC}"
}

# 生成Nginx服务器私钥
generate_nginx_key() {
    echo -e "${GREEN}[3/6] 生成Nginx服务器私钥...${NC}"
    openssl genrsa -out "$CERTS_DIR/nginx.key" $KEY_BITS
    chmod 600 "$CERTS_DIR/nginx.key"
    echo -e "${GREEN}✓ nginx.key 已生成${NC}"
}

# 生成证书签名请求(CSR)
generate_csr() {
    echo -e "${GREEN}[4/6] 生成证书签名请求(CSR)...${NC}"

    # 创建openssl配置文件以支持SAN
    cat > "$CERTS_DIR/nginx_san.cnf" << EOF
[req]
default_bits = $KEY_BITS
prompt = no
default_md = $HASH_ALGO
distinguished_name = dn
req_extensions = req_ext

[dn]
C=$SERVER_COUNTRY
ST=$SERVER_STATE
L=$SERVER_CITY
O=$SERVER_ORG
OU=$SERVER_OU
CN=$SERVER_CN

[req_ext]
subjectAltName = @alt_names

[alt_names]
$SAN_DNS
$SAN_IP
EOF

    openssl req -new \
        -key "$CERTS_DIR/nginx.key" \
        -out "$CERTS_DIR/nginx.csr" \
        -$HASH_ALGO \
        -config "$CERTS_DIR/nginx_san.cnf"

    echo -e "${GREEN}✓ nginx.csr 已生成${NC}"
}

# 使用CA签发证书
sign_certificate() {
    echo -e "${GREEN}[5/6] 使用CA签发Nginx证书...${NC}"

    # 创建CA配置文件用于签发
    cat > "$CERTS_DIR/ca_signing.cnf" << EOF
[ca]
default_ca = CA_default

[CA_default]
database = $CERTS_DIR/index.txt
serial = $CERTS_DIR/serial.txt
new_certs_dir = $CERTS_DIR
default_md = $HASH_ALGO
policy = policy_loose

[policy_loose]
countryName = optional
stateOrProvinceName = optional
localityName = optional
organizationName = optional
organizationalUnitName = optional
commonName = supplied

[req]
distinguished_name = req_distinguished_name

[req_distinguished_name]

[v3_ca]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
$SAN_DNS
$SAN_IP
EOF

    # 创建必要的文件
    touch "$CERTS_DIR/index.txt"
    echo 01 > "$CERTS_DIR/serial.txt"

    openssl x509 -req \
        -in "$CERTS_DIR/nginx.csr" \
        -CA "$CERTS_DIR/ca.crt" \
        -CAkey "$CERTS_DIR/ca.key" \
        -CAcreateserial \
        -out "$CERTS_DIR/nginx.crt" \
        -days $DAYS \
        -$HASH_ALGO \
        -extfile "$CERTS_DIR/ca_signing.cnf" \
        -extensions v3_ca

    chmod 644 "$CERTS_DIR/nginx.crt"
    echo -e "${GREEN}✓ nginx.crt 已生成${NC}"
}

# 清理临时文件
cleanup() {
    echo -e "${GREEN}[6/6] 清理临时文件...${NC}"
    rm -f "$CERTS_DIR/nginx.csr" "$CERTS_DIR/nginx_san.cnf" "$CERTS_DIR/ca_signing.cnf" \
          "$CERTS_DIR/index.txt" "$CERTS_DIR/serial.txt" \
          "$CERTS_DIR/serial.txt.old" "$CERTS_DIR/index.txt.old" \
          "$CERTS_DIR/ca.srl"
    echo -e "${GREEN}✓ 临时文件已清理${NC}"
}

# 显示证书信息
display_info() {
    echo
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}证书生成成功！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "CA证书: ${YELLOW}$CERTS_DIR/ca.crt${NC} (根证书)"
    echo -e "CA私钥: ${YELLOW}$CERTS_DIR/ca.key${NC} (请妥善保管)"
    echo -e "服务器证书: ${YELLOW}$CERTS_DIR/nginx.crt${NC}"
    echo -e "服务器私钥: ${YELLOW}$CERTS_DIR/nginx.key${NC}"
    echo
    echo -e "${GREEN}证书有效期: 50年 (${DAYS}天)${NC}"
    echo
    echo -e "${YELLOW}Nginx配置示例:${NC}"
    cat << EOF
server {
    listen 443 ssl http2;
    server_name localhost;

    ssl_certificate /path/to/nginx.crt;
    ssl_certificate_key /path/to/nginx.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # 可选：客户端CA验证
    # ssl_client_certificate /path/to/ca.crt;
    # ssl_verify_client optional;

    location / {
        root /usr/share/nginx/html;
        index index.html;
    }
}
EOF
    echo
    echo -e "${YELLOW}验证证书信息:${NC}"
    echo "CA证书信息:"
    openssl x509 -in "$CERTS_DIR/ca.crt" -noout -subject -dates
    echo
    echo "服务器证书信息:"
    openssl x509 -in "$CERTS_DIR/nginx.crt" -noout -subject -dates
    echo
    echo -e "${GREEN}========================================${NC}"
}

# 主函数
main() {
    echo -e "${GREEN}=== Nginx自签名证书生成工具 ===${NC}"
    echo

    mkdir -p "$CERTS_DIR"

    check_openssl
    check_existing_files
    generate_ca_key
    generate_ca_cert
    generate_nginx_key
    generate_csr
    sign_certificate
    cleanup
    display_info
}

# 执行主函数
main