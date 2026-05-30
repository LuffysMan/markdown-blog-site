#!/usr/bin/env bash

####################################################################################
# 做安装工作: 创建用户, 创建目录, 拷贝jar包到程序安装位置等
####################################################################################
current_dir=$(cd "$(dirname "$0")" || exit; pwd)

# CONSTANTS
PACKAGE_DIR=$(dirname "${current_dir}")
INSTALL_DIR="/opt/xiaocui/blogs"

function delete_basic_dir() {
    rm -rf "${INSTALL_DIR:?}"/bin
    rm -rf "${INSTALL_DIR}"/conf
    rm -rf "${INSTALL_DIR}"/data
    rm -rf "${INSTALL_DIR}"/log
}

function delete_user() {
    userdel -r tomcat
    groupdel xiaocui
}

function main() {
    delete_basic_dir
    delete_user
}

main
