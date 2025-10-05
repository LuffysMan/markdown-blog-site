#!/usr/bin/env bash

####################################################################################
# 做安装工作: 创建用户, 创建目录, 拷贝jar包到程序安装位置等
####################################################################################
current_dir=$(dirname "$0")

# CONSTANTS
PACKAGE_DIR=$(dirname "${current_dir}")
INSTALL_DIR="/opt/xiaocui/blogs"

# 创建用户,用户组
function create_user() {
    groupadd -g 60000 tomcat
    useradd -s /usr/sbin/nologin -m -u 60001 tomcat -g xiaocui
}

function delete_user() {
    userdel -r tomcat
    groupdel xiaocui
}

function create_basic_dir() {
    mkdir -p "${INSTALL_DIR}"/bin
    mkdir -p "${INSTALL_DIR}"/conf
    mkdir -p "${INSTALL_DIR}"/data
    mkdir -p "${INSTALL_DIR}"/log
}

function delete_basic_dir() {
    rm -rf "${INSTALL_DIR:?}"/bin
    rm -rf "${INSTALL_DIR}"/conf
    rm -rf "${INSTALL_DIR}"/data
    rm -rf "${INSTALL_DIR}"/log
}

function copy_program_files() {
    cp -fH --remove-destination "${PACKAGE_DIR}"/target/blog-part-1.0-SNAPSHOT.jar "${INSTALL_DIR}"/bin/app.jar
    cp -fH --remove-destination "${PACKAGE_DIR}"/bin/start.sh "${INSTALL_DIR}"/bin/
}

function set_permission() {
    chown -hR tomcat:xiaocui /opt/xiaocui/blogs
    find "${INSTALL_DIR}" -type d -exec chmod 750 {} +
    find "${INSTALL_DIR}" -type f -exec chmod 500 {} +

}

function uninstall() {
    delete_basic_dir
    delete_user
}

function main() {
    uninstall
    create_user
    create_basic_dir
    copy_program_files
    set_permission
}