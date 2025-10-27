FROM eclipse-temurin:21-jre-jammy

WORKDIR /tmp/work

# 拷贝安装资源
COPY bin ./bin
COPY target ./target

# 执行安装动作
RUN /tmp/work/bin/install.sh && rm -rf /tmp/work

# 指定后续命令的用户和用户组
USER tomcat:xiaocui

# 暴露端口
EXPOSE 8080

# 启动应用
ENTRYPOINT ["bash", "/opt/xiaocui/blogs/bin/start.sh"]