#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# 宿主机初始化脚本 — 以 root 执行，只需执行一次
# 用途: 创建项目用户/组、目录结构、权限，配置 cicd 用户的 SSH 密钥
###############################################################################

PROJECT_DIR="/opt/xiaocui/blogs"
GID_XIAOCUI=60000
UID_BLOG=60001
UID_CICD=60002

log_info()  { echo "[INFO]  $*"; }
log_error() { echo "[ERROR] $*"; exit 1; }

# --------------- 1. 创建用户和组 ---------------
create_users() {
    log_info "Creating users and groups..."

    # 项目组
    if ! getent group xiaocui > /dev/null 2>&1; then
        groupadd -g ${GID_XIAOCUI} xiaocui
        log_info "  Group xiaocui (GID ${GID_XIAOCUI}) created"
    else
        log_info "  Group xiaocui already exists, skip"
    fi

    # blog 用户 — 数据/日志目录所有者，禁止 shell 登录
    if ! id -u blog > /dev/null 2>&1; then
        useradd -s /usr/sbin/nologin -M -u ${UID_BLOG} -g xiaocui blog
        log_info "  User blog (UID ${UID_BLOG}) created"
    else
        log_info "  User blog already exists, skip"
    fi

    # cicd 用户 — 部署专用
    if ! id -u cicd > /dev/null 2>&1; then
        useradd -m -s /bin/bash -u ${UID_CICD} -g xiaocui cicd
        log_info "  User cicd (UID ${UID_CICD}) created"
    else
        log_info "  User cicd already exists, skip"
    fi

    # cicd 加入 docker 组
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

    mkdir -p "${PROJECT_DIR}"/data
    mkdir -p "${PROJECT_DIR}"/logs
    mkdir -p "${PROJECT_DIR}"/docker/nginx
    mkdir -p "${PROJECT_DIR}"/scripts

    log_info "  Directory tree created under ${PROJECT_DIR}"
}

# --------------- 3. 设置权限 ---------------
set_permissions() {
    log_info "Setting permissions..."

    # 项目根目录: cicd 拥有，xiaocui 组可读可进入 (setgid)
    chown   cicd:xiaocui "${PROJECT_DIR}"
    chmod   2750 "${PROJECT_DIR}"

    # data/ logs/: blog 拥有，xiaocui 组可读写，sgid 保证子文件自动继承组
    chown -R blog:xiaocui "${PROJECT_DIR}"/data
    chmod   2770 "${PROJECT_DIR}"/data
    chown -R blog:xiaocui "${PROJECT_DIR}"/logs
    chmod   2770 "${PROJECT_DIR}"/logs

    # scripts/: cicd 拥有，xiaocui 组可读可执行
    chown -R cicd:xiaocui "${PROJECT_DIR}"/scripts
    chmod 0750 "${PROJECT_DIR}"/scripts
    find "${PROJECT_DIR}"/scripts -type f -name "*.sh" -exec chmod 0740 {} \;

    # docker/: cicd 拥有，xiaocui 组可读
    chown -R cicd:xiaocui "${PROJECT_DIR}"/docker
    chmod   2750 "${PROJECT_DIR}"/docker
    find "${PROJECT_DIR}"/docker -type f -name "*.yml" -exec chmod 0640 {} \;
    find "${PROJECT_DIR}"/docker -type f -name "*.conf" -exec chmod 0640 {} \;

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
    else
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
    fi
}

# --------------- 5. 配置 SSH 安全选项 ---------------
lockdown_sshd() {
    log_info "Locking down cicd SSH access..."
    local AUTH_KEY="/home/cicd/.ssh/authorized_keys"

    if grep -q 'no-port-forwarding' "${AUTH_KEY}" 2>/dev/null; then
        log_info "  SSH restrictions already in place, skip"
        return
    fi

    # 在已存在的公钥行前加上安全限制选项
    sed -i 's/^ssh-/no-port-forwarding,no-agent-forwarding,no-X11-forwarding,no-pty,no-user-rc ssh-/' "${AUTH_KEY}"
    log_info "  SSH restrictions applied to cicd authorized_keys"
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

    echo ""
    log_info "Setup complete."
    echo ""
    echo "Next steps:"
    echo "  1. Upload docker-compose.yml to ${PROJECT_DIR}/docker/"
    echo "  2. Upload nginx.conf      to ${PROJECT_DIR}/docker/nginx/"
    echo "  3. Upload deploy.sh       to ${PROJECT_DIR}/scripts/"
    echo "  4. Put the CICD private key in GitHub Secrets (SSH_KEY)"
    echo "  5. Run: scp ... cicd@<host>:${PROJECT_DIR}/..."
}

main
