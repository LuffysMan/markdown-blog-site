#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# 宿主机初始化脚本 — 以 root 执行，只需执行一次
# 用途: 创建项目用户/组、目录结构、权限，配置 cicd 用户的 SSH 密钥
#
# 服务器目录结构:
#   /opt/xiaocui/
#   ├── blogs/
#   │   ├── data/          # blog 用户独有，存放 markdown 内容
#   │   └── logs/          # blog 用户独有，应用日志
#   ├── docker/
#   │   └── docker-compose.yml
#   ├── nginx/
#   │   ├── certs/         # SSL 证书（私钥敏感，严格权限）
#   │   └── conf/
#   │       └── nginx.conf
#   └── scripts/
#       ├── deploy.sh
#       ├── gen_cert.sh
#       └── run.sh
###############################################################################

PROJECT_DIR="/opt/xiaocui"
GID_XIAOCUI=60000
UID_BLOG=60001
UID_CICD=60002

log_info()  { echo "[INFO]  $*"; }
log_error() { echo "[ERROR] $*"; exit 1; }

# --------------- 1. 创建用户和组 ---------------
create_users() {
    log_info "Creating users and groups..."

    if ! getent group xiaocui > /dev/null 2>&1; then
        groupadd -g ${GID_XIAOCUI} xiaocui
        log_info "  Group xiaocui (GID ${GID_XIAOCUI}) created"
    else
        log_info "  Group xiaocui already exists, skip"
    fi

    if ! id -u blog > /dev/null 2>&1; then
        useradd -s /usr/sbin/nologin -M -u ${UID_BLOG} -g xiaocui blog
        log_info "  User blog (UID ${UID_BLOG}) created (no shell, no home)"
    else
        log_info "  User blog already exists, skip"
    fi

    if ! id -u cicd > /dev/null 2>&1; then
        useradd -m -s /bin/bash -u ${UID_CICD} -g xiaocui cicd
        log_info "  User cicd (UID ${UID_CICD}) created"
    else
        log_info "  User cicd already exists, skip"
    fi

    if getent group docker > /dev/null 2>&1; then
        usermod -aG docker cicd
        log_info "  cicd added to docker group"
    else
        log_error "docker group not found — install docker first"
    fi
}

# --------------- 2. 创建目录结构 ---------------
create_dirs() {
    log_info "Creating directories..."

    mkdir -p "${PROJECT_DIR}"
    mkdir -p "${PROJECT_DIR}"/blogs/data
    mkdir -p "${PROJECT_DIR}"/blogs/logs
    mkdir -p "${PROJECT_DIR}"/docker
    mkdir -p "${PROJECT_DIR}"/nginx/certs
    mkdir -p "${PROJECT_DIR}"/nginx/conf
    mkdir -p "${PROJECT_DIR}"/scripts

    log_info "  Directory tree created under ${PROJECT_DIR}"
}

# --------------- 3. 设置权限 ---------------
set_permissions() {
    log_info "Setting permissions..."

    # ── 项目根目录 ──
    # cicd 管理，xiaocui 组可遍历、读取，其他人无权限
    chown   cicd:xiaocui "${PROJECT_DIR}"
    chmod   2750 "${PROJECT_DIR}"

    # ── blogs/ ──
    # blog 数据目录：只有 blog 用户需要读写
    chown -R blog:xiaocui "${PROJECT_DIR}"/blogs
    chmod   2750 "${PROJECT_DIR}"/blogs
    chmod   2770 "${PROJECT_DIR}"/blogs/data
    find "${PROJECT_DIR}"/blogs/data -type d -exec chmod 2770 {} \; 2>/dev/null || true
    find "${PROJECT_DIR}"/blogs/data -type f -exec chmod 660  {} \; 2>/dev/null || true
    chmod   2770 "${PROJECT_DIR}"/blogs/logs
    find "${PROJECT_DIR}"/blogs/logs -type d -exec chmod 2770 {} \; 2>/dev/null || true
    find "${PROJECT_DIR}"/blogs/logs -type f -exec chmod 660  {} \; 2>/dev/null || true

    # ── docker/ ──
    # cicd 管理 compose 文件，docker 守护进程以 root 运行，仅需组内可读
    chown -R cicd:xiaocui "${PROJECT_DIR}"/docker
    chmod   2750 "${PROJECT_DIR}"/docker
    find "${PROJECT_DIR}"/docker -type f -exec chmod 640 {} \;
    find "${PROJECT_DIR}"/docker -type d -exec chmod 2750 {} \;

    # ── nginx/ ──
    # certs: 私钥极为敏感，仅 cicd 可读写，xiaocui 组仅可读（nginx 容器通过 bind mount 读取）
    chown -R cicd:xiaocui "${PROJECT_DIR}"/nginx
    chmod   2750 "${PROJECT_DIR}"/nginx

    chown -R cicd:xiaocui "${PROJECT_DIR}"/nginx/certs
    chmod   2750 "${PROJECT_DIR}"/nginx/certs
    find "${PROJECT_DIR}"/nginx/certs -type f -name "*.key" -exec chmod 600 {} \;
    find "${PROJECT_DIR}"/nginx/certs -type f -name "*.crt" -exec chmod 644 {} \;
    find "${PROJECT_DIR}"/nginx/certs -type f ! -name "*.key" ! -name "*.crt" -exec chmod 640 {} \;

    # conf: cicd 管理，ngxinx 容器只读 mount
    chown -R cicd:xiaocui "${PROJECT_DIR}"/nginx/conf
    chmod   2750 "${PROJECT_DIR}"/nginx/conf
    find "${PROJECT_DIR}"/nginx/conf -type f -exec chmod 640 {} \;

    # ── scripts/ ──
    # cicd 可读写执行，xiaocui 组可读执行
    chown -R cicd:xiaocui "${PROJECT_DIR}"/scripts
    chmod   2750 "${PROJECT_DIR}"/scripts
    find "${PROJECT_DIR}"/scripts -type f -name "*.sh" -exec chmod 750 {} \;

    log_info "  Permissions set"
}

# --------------- 4. 配置 cicd SSH 密钥 ---------------
setup_ssh() {
    log_info "Configuring SSH for cicd..."

    local SSH_DIR="/home/cicd/.ssh"
    local AUTH_KEY="${SSH_DIR}/authorized_keys"

    mkdir -p "${SSH_DIR}"
    chown cicd:xiaocui "${SSH_DIR}"
    chmod 700 "${SSH_DIR}"

    if [ -f "${AUTH_KEY}" ]; then
        log_info "  authorized_keys already exists, skip"
        return
    fi

    echo "##################################################################"
    echo "  A GitHub Actions deploy key is needed."
    echo "  Generate one locally:"
    echo ""
    echo "    ssh-keygen -t ed25519 -C \"cicd-deploy-key\" -f ~/.ssh/cicd_deploy"
    echo ""
    echo "  Then paste the PUBLIC key content (cicd_deploy.pub) here:"
    echo "##################################################################"
    read -rp "  > " PUBKEY
    if [ -z "${PUBKEY}" ]; then
        log_error "No public key provided, abort"
    fi
    echo "${PUBKEY}" > "${AUTH_KEY}"
    chown cicd:xiaocui "${AUTH_KEY}"
    chmod 600 "${AUTH_KEY}"
    log_info "  authorized_keys configured — store the PRIVATE key in GitHub Secrets"
}

# --------------- 5. 锁定 cicd SSH 权限 ---------------
lockdown_sshd() {
    log_info "Locking down cicd SSH access..."

    local AUTH_KEY="/home/cicd/.ssh/authorized_keys"

    if grep -q 'no-port-forwarding' "${AUTH_KEY}" 2>/dev/null; then
        log_info "  SSH restrictions already in place, skip"
        return
    fi

    sed -i 's/^ssh-/no-port-forwarding,no-agent-forwarding,no-X11-forwarding,no-pty,no-user-rc ssh-/' "${AUTH_KEY}"
    log_info "  SSH restrictions applied (no PTY, no forwarding)"
}

# --------------- 6. 安全加固 ---------------
harden() {
    log_info "Applying additional security hardening..."

    # 确保 cicd 家目录权限
    chmod 750 /home/cicd
    chown cicd:xiaocui /home/cicd

    # 禁止 cicd 用户编辑自己的 authorized_keys
    chown root:root /home/cicd/.ssh/authorized_keys 2>/dev/null || true
    chmod 444 /home/cicd/.ssh/authorized_keys 2>/dev/null || true

    log_info "  Hardening complete"
}

# --------------- main ---------------
main() {
    echo "============================================"
    echo "  LandofC Host Setup"
    echo "============================================"

    create_users
    create_dirs
    set_permissions
    setup_ssh
    lockdown_sshd
    harden

    echo ""
    log_info "Setup complete."
    echo ""
    echo "Next steps:"
    echo "  1. Upload docker-compose.yml to ${PROJECT_DIR}/docker/"
    echo "  2. Upload nginx.conf      to ${PROJECT_DIR}/nginx/conf/"
    echo "  3. Upload deploy.sh       to ${PROJECT_DIR}/scripts/"
    echo "  4. Generate SSL certs and copy to ${PROJECT_DIR}/nginx/certs/"
    echo "  5. Put the CICD private key in GitHub Secrets (SSH_KEY)"
    echo "  6. Start services: cd ${PROJECT_DIR}/docker && docker compose up -d"
}

main
