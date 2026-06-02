#!/usr/bin/env bash
set -euo pipefail

IMAGE_TAG="${IMAGE_TAG:-latest}"
IMAGE_REGISTRY="${IMAGE_REGISTRY:-crpi-mknd11v8ns0aphs9.cn-hangzhou.personal.cr.aliyuncs.com}"
IMAGE_NAMESPACE="${IMAGE_NAMESPACE:-luffyspace}"
IMAGE_NAME="${IMAGE_NAME:-blogs}"
FULL_IMAGE="${IMAGE_REGISTRY}/${IMAGE_NAMESPACE}/${IMAGE_NAME}:${IMAGE_TAG}"
COMPOSE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="${COMPOSE_DIR}/docker/docker-compose.yml"
PREV_TAG_FILE="${COMPOSE_DIR}/docker/.previous_tag"
HEALTH_URL="http://localhost:8080/actuator/health"
MAX_RETRIES=12
RETRY_INTERVAL=5

log_info()  { echo "[INFO] $(date '+%H:%M:%S') $*"; }
log_error() { echo "[ERROR] $(date '+%H:%M:%S') $*"; }

get_current_tag() {
    docker inspect --format='{{.Config.Image}}' blogs-blog-server-1 2>/dev/null | awk -F: '{print $NF}' || echo "unknown"
}

pull_image() {
    log_info "Pulling ${FULL_IMAGE}..."
    if ! docker pull "${FULL_IMAGE}"; then
        log_error "Failed to pull image"
        exit 1
    fi
    docker tag "${FULL_IMAGE}" "${IMAGE_REGISTRY}/${IMAGE_NAMESPACE}/${IMAGE_NAME}:stable"
}

healthcheck() {
    log_info "Waiting for container to become healthy..."
    for i in $(seq 1 "${MAX_RETRIES}"); do
        if curl -sf "${HEALTH_URL}" > /dev/null 2>&1; then
            log_info "Health check passed (attempt ${i})"
            return 0
        fi
        log_info "Health check attempt ${i}/${MAX_RETRIES} failed, retrying in ${RETRY_INTERVAL}s..."
        sleep "${RETRY_INTERVAL}"
    done
    log_error "Health check failed after ${MAX_RETRIES} attempts"
    return 1
}

deploy() {
    log_info "Starting new container with tag ${IMAGE_TAG}..."
    cd "${COMPOSE_DIR}/docker"
    IMAGE_TAG="${IMAGE_TAG}" IMAGE_REGISTRY="${IMAGE_REGISTRY}" IMAGE_NAMESPACE="${IMAGE_NAMESPACE}" docker compose up -d blog-server
}

rollback() {
    local prev_tag
    prev_tag=$(cat "${PREV_TAG_FILE}" 2>/dev/null || echo "")
    if [ -z "${prev_tag}" ] || [ "${prev_tag}" = "unknown" ]; then
        log_error "No previous version to rollback to"
        exit 1
    fi
    log_error "Rolling back to ${prev_tag}..."
    cd "${COMPOSE_DIR}/docker"
    IMAGE_TAG="${prev_tag}" IMAGE_REGISTRY="${IMAGE_REGISTRY}" IMAGE_NAMESPACE="${IMAGE_NAMESPACE}" docker compose up -d blog-server

    log_info "Verifying rollback..."
    if healthcheck; then
        log_info "Rollback successful"
    else
        log_error "CRITICAL: Rollback also failed, manual intervention required"
        exit 1
    fi
}

cleanup() {
    log_info "Cleaning up old images..."
    docker image prune -af --filter "until=72h" 2>/dev/null || true
}

main() {
    local current_tag
    current_tag=$(get_current_tag)
    echo "${current_tag}" > "${PREV_TAG_FILE}"
    log_info "Current: ${current_tag}, deploying: ${IMAGE_TAG}"

    pull_image
    deploy

    if healthcheck; then
        log_info "Deploy SUCCESS: ${IMAGE_TAG}"
        cleanup
    else
        log_error "Deploy FAILED, starting rollback..."
        rollback
    fi
}

main
