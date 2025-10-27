#!/usr/bin/env bash

#################################################################################
# 持续集成&部署: (集成环境要求:  能拉源码; 有maven, 能通maven中心仓; 有 docker, 能通 docker hub; 能远程部署环境, 推送文件, 执行脚本)
# 执行方式: bash continue_integrate_and_deploy.sh
#################################################################################

# CONSTANTS
if [ -z "${VERSION}" ]; then
    # 如果外部环境变量没有定义版本好, 则默认版本号是0.1
    VERSION="v0.0.1"
fi
PROJECT_PATH="D:/playground/java/LandofC"
CODE_PATH="${PROJECT_PATH}/code/backend/blog-part"
BUILD_DIR="${PROJECT_PATH}/build_dir"
BUILD_PATH="${PROJECT_PATH}/build_dir/blog-part"
DEPLOY_PATH="${PROJECT_PATH}/xiaocui"
IMAGE_BUILD_PATH="${BUILD_DIR}"/app.tar
IMAGE_DEPLOY_PATH="${DEPLOY_PATH}"/app.tar

## 运行配置
INSTALL_DIR="/opt/xiaocui/blogs"
DATA_DIR="${INSTALL_DIR}"/data
LOG_DIR="${INSTALL_DIR}"/logs

## 外部卷映射路径
VOLUME_PATH_DATA="${DEPLOY_PATH}"/blogs/data
VOLUME_PATH_LOGS="${DEPLOY_PATH}"/blogs/logs


alias log_info="echo [INFO]: "
alias log_error="echo [ERROR]: "

function clear_env() {
    rm -rf "${BUILD_PATH:?}"
    echo "清理残留"
}

function prepare_folders() {
    log_info "prepare basic folders"
    mkdir -p BUILD_DIR
    mkdir -p DEPLOY_PATH
    log_info "finish prepare basic folders"
}

function get_source_code() {
    log_info "get_source_code start"
    rm -rf "${BUILD_PATH:?}"
    cp -r "${CODE_PATH}" "${BUILD_PATH}"
    log_info "get_source_code finish"
}

function build_app() {
    log_info "build_app start"
    pushd "${BUILD_PATH}" || exit 1
    if ! mvn clean package; then
        log_error "build app failed"
        exit 1
    fi
    popd || exit 1
    log_info "build_app finish"
}

function build_image() {
    log_info "build image start"
    pushd "${BUILD_PATH}" || exit 1
    if ! DOCKER_BUILDKIT=0 docker build --no-cache -t xiaocui/blogs:"${VERSION}" .; then
        log_error "build image failed"
        exit 1
    fi
    popd || exit 1
    log_info "build image finish"

    log_info "start to save image to ${BUILD_DIR}"
    docker save -o "${IMAGE_BUILD_PATH}" xiaocui/blogs:"${VERSION}"
    log_info "finish saving image to ${BUILD_DIR}"
}

function push_image() {
    log_info "load image start"
    cp "${IMAGE_BUILD_PATH}" "${DEPLOY_PATH}"
    log_info "push_image finish"
}

function load_image() {
    log_info "load image start"
    docker image prune -f
    docker load -i "${IMAGE_DEPLOY_PATH}"
    log_info "load image finish"
}

function run() {
    log_info "run container start"
    if ! docker run -d -p 80:8080 -v "${VOLUME_PATH_DATA}":"${DATA_DIR}" -v "${VOLUME_PATH_LOGS}":"${LOG_DIR}" xiaocui/blogs:"${VERSION}"; then
        log_error "run container failed"
        exit 1
    fi
    log_info "run container finish"
}

function main() {
    # 准备目录
    prepare_folders

    # 下载源码
    get_source_code

    # 构建源码
    build_app

    # 构建镜像
    build_image

    # 推送镜像
    push_image

    # 加载镜像
    load_image

    # 启动容器实例
    run
}

trap clear_env EXIT
main