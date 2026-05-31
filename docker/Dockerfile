# ===== Stage 1: Build =====
FROM maven:3.9-eclipse-temurin-21-alpine AS builder
WORKDIR /build
COPY pom.xml .
RUN mvn dependency:go-offline -B
COPY src ./src
RUN mvn clean package -DskipTests -B

# ===== Stage 2: Extract layers =====
FROM eclipse-temurin:21-jre-jammy AS extractor
WORKDIR /extract
COPY --from=builder /build/target/*.jar app.jar
RUN java -Djarmode=layertools -jar app.jar extract

# ===== Stage 3: Runtime =====
FROM eclipse-temurin:21-jre-jammy
RUN groupadd -g 60000 xiaocui && \
    useradd -s /usr/sbin/nologin -m -u 60001 blog -g xiaocui

WORKDIR /opt/xiaocui/blogs
RUN mkdir -p data logs && chown -R blog:xiaocui /opt/xiaocui/blogs
COPY --from=extractor /extract/dependencies/ ./
COPY --from=extractor /extract/spring-boot-loader/ ./
COPY --from=extractor /extract/snapshot-dependencies/ ./
COPY --from=extractor /extract/application/ ./

USER blog:xiaocui
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=5s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
