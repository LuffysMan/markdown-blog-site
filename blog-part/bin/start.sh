#!/usr/bin/env bash

####################################################################################
# 启动程序: 解析参数, 检查参数, 启动程序
####################################################################################

# CONSTANTS
INSTALL_DIR="/opt/xiaocui/blogs"
BLOG_DIR="${INSTALL_DIR}"/data
LOG_DIR="${INSTALL_DIR}"/log
BIN_DIR="${INSTALL_DIR}"/bin

function start_service() {
    java -Dblogs.baseDir="${BLOG_DIR}" -Dlogging.level.root=INFO -Dlogging.file.name="${LOG_DIR}"/app.log -jar "${BIN_DIR}"/app.jar
}

function main() {
    start_service
}

main