#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# 宿主机初始化脚本 — 以 root 执行，只需执行一次
# 用途: 创建项目用户/组、目录结构、权限，配置 cicd 用户的 SSH 密钥，
#       加固 SSH 配置，安装 fail2ban 防爆破
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
UID_MANAGER=60003

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

    if ! id -u manager > /dev/null 2>&1; then
        useradd -m -s /bin/bash -u ${UID_MANAGER} -g xiaocui -G wheel manager
        log_info "  User manager (UID ${UID_MANAGER}) created (wheel: sudo)"
    else
        log_info "  User manager already exists, skip"
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

# --------------- 5. 配置 manager SSH 密钥 ---------------
setup_manager_ssh() {
    log_info "Configuring SSH for manager..."

    local SSH_DIR="/home/manager/.ssh"
    local AUTH_KEY="${SSH_DIR}/authorized_keys"

    mkdir -p "${SSH_DIR}"
    chown manager:xiaocui "${SSH_DIR}"
    chmod 700 "${SSH_DIR}"

    if [ -f "${AUTH_KEY}" ]; then
        log_info "  manager authorized_keys already exists, skip"
        return
    fi

    echo "##################################################################"
    echo "  A manager SSH key is needed (your local PC)."
    echo "  Generate one locally:"
    echo ""
    echo "    ssh-keygen -t ed25519 -C \"manager-key\" -f ~/.ssh/manager_key"
    echo ""
    echo "  Then paste the PUBLIC key content (manager_key.pub) here:"
    echo "##################################################################"
    read -rp "  > " PUBKEY
    if [ -z "${PUBKEY}" ]; then
        log_error "No public key provided, abort"
    fi
    echo "${PUBKEY}" > "${AUTH_KEY}"
    chown manager:xiaocui "${AUTH_KEY}"
    chmod 600 "${AUTH_KEY}"
    log_info "  manager authorized_keys configured"
}

# --------------- 6. 锁定 cicd SSH 权限 ---------------
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

# --------------- 7. 安全加固 ---------------
harden() {
    log_info "Applying additional security hardening..."

    # cicd 家目录
    chmod 750 /home/cicd
    chown cicd:xiaocui /home/cicd
    chown cicd:xiaocui /home/cicd/.ssh/authorized_keys 2>/dev/null || true
    chmod 400 /home/cicd/.ssh/authorized_keys 2>/dev/null || true

    # manager 家目录
    chmod 750 /home/manager
    chown manager:xiaocui /home/manager
    chown manager:xiaocui /home/manager/.ssh/authorized_keys 2>/dev/null || true
    chmod 400 /home/manager/.ssh/authorized_keys 2>/dev/null || true

    # manager sudo NOPASSWD
    local SUDOERS_D="/etc/sudoers.d/90-manager"
    if [ ! -f "${SUDOERS_D}" ]; then
        echo "manager ALL=(ALL) NOPASSWD: ALL" > "${SUDOERS_D}"
        chmod 440 "${SUDOERS_D}"
        log_info "  manager sudo NOPASSWD enabled"
    else
        log_info "  manager sudoers already configured, skip"
    fi

    log_info "  Hardening complete"
}

# --------------- 8. 加固 SSH 服务 ---------------
harden_sshd() {
    log_info "Hardening SSH daemon..."

    local SSHD_CFG="/etc/ssh/sshd_config"

    if [ ! -f "${SSHD_CFG}" ]; then
        log_info "  ${SSHD_CFG} not found, skip"
        return
    fi

    # 检查是否已加固，避免重复操作
    if grep -q "^PermitRootLogin no$" "${SSHD_CFG}" && \
       grep -q "^PasswordAuthentication no$" "${SSHD_CFG}" && \
       grep -q "^AllowUsers cicd manager$" "${SSHD_CFG}"; then
        log_info "  sshd already hardened, skip"
        return
    fi

    local SSHD_BAK="${SSHD_CFG}.bak.$(date +%s)"
    cp "${SSHD_CFG}" "${SSHD_BAK}"

    _sshd_set() {
        local key="$1" val="$2"
        if grep -q "^#\?${key}\s" "${SSHD_CFG}"; then
            sed -i "s/^#\?${key}\s.*/${key} ${val}/" "${SSHD_CFG}"
        else
            echo "${key} ${val}" >> "${SSHD_CFG}"
        fi
    }

    _sshd_set "PermitRootLogin" "no"
    _sshd_set "PasswordAuthentication" "no"
    _sshd_set "PubkeyAuthentication" "yes"
    _sshd_set "AllowUsers" "cicd manager"
    _sshd_set "MaxAuthTries" "3"
    _sshd_set "ClientAliveInterval" "60"
    _sshd_set "ClientAliveCountMax" "2"

    if sshd -t; then
        systemctl reload sshd 2>/dev/null || service sshd reload 2>/dev/null || true
        log_info "  sshd hardened and reloaded (backup: ${SSHD_BAK})"
        log_info "  Root login: OFF | Password auth: OFF | Users: cicd manager | Max tries: 3"
    else
        log_error "sshd config invalid, restoring backup"
        cp "${SSHD_BAK}" "${SSHD_CFG}"
        exit 1
    fi
}

# --------------- 9. 安装 fail2ban ---------------
setup_fail2ban() {
    log_info "Setting up fail2ban..."

    if command -v fail2ban-client &> /dev/null; then
        log_info "  fail2ban already installed"
    else
        if command -v dnf &> /dev/null; then
            dnf install -y epel-release 2>/dev/null || true
            dnf install -y fail2ban
        elif command -v yum &> /dev/null; then
            yum install -y epel-release 2>/dev/null || true
            yum install -y fail2ban
        else
            log_info "  Could not install fail2ban (unsupported package manager), skip"
            return
        fi
    fi

    local JAIL_CFG="/etc/fail2ban/jail.local"

    # 检查是否已配置，避免不必要的重启
    if [ -f "${JAIL_CFG}" ]; then
        log_info "  jail.local already exists, skip"
        systemctl enable fail2ban 2>/dev/null || true
        systemctl is-active --quiet fail2ban 2>/dev/null || systemctl restart fail2ban 2>/dev/null || service fail2ban restart 2>/dev/null || true
        return
    fi

    cat > "${JAIL_CFG}" << 'EOF'
[sshd]
enabled = true
port = 22
maxretry = 3
bantime = 3600
findtime = 600
EOF

    systemctl enable fail2ban 2>/dev/null || true
    systemctl restart fail2ban 2>/dev/null || service fail2ban restart 2>/dev/null || true

    log_info "  fail2ban enabled (3 failures in 10min = 1h ban)"
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
    setup_manager_ssh
    lockdown_sshd
    harden_sshd
    harden
    setup_fail2ban

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
