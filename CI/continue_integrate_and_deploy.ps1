#################################################################################
# 持续集成&部署: (集成环境要求:  能拉源码; 有maven, 能通maven中心仓; 有 docker, 能通 docker hub; 能远程部署环境, 推送文件, 执行脚本)
# 执行方式: powershell -ExecutionPolicy Bypass  -Command "Set-PSDebug -Trace 2; & 'D:\playground\java\LandofC\code\backend\CI\continue_integrate_and_deploy.ps1'"
# 执行方式: powershell -ExecutionPolicy Bypass  -Command 'D:\playground\java\LandofC\code\backend\CI\continue_integrate_and_deploy.ps1'
#################################################################################

# CONSTANTS
if (-not $env:VERSION) {
    # 如果外部环境变量没有定义版本号, 则默认版本号是0.0.1
    $VERSION = "v0.0.1"
} else {
    $VERSION = $env:VERSION
}
$PROJECT_PATH = "D:\playground\java\LandofC"
$CODE_PATH = Join-Path $PROJECT_PATH "code\backend\blog-part"
$BUILD_DIR = Join-Path $PROJECT_PATH "build_dir"
$BUILD_PATH = Join-Path $PROJECT_PATH "build_dir\blog-part"
$DEPLOY_PATH = Join-Path $PROJECT_PATH "xiaocui"
$IMAGE_BUILD_PATH = Join-Path "${BUILD_DIR}" app.tar
$IMAGE_DEPLOY_PATH = Join-Path "${DEPLOY_PATH}" app.tar

## 运行配置
$DATA_DIR = "/opt/xiaocui/blogs/data"
$LOG_DIR = "/opt/xiaocui/blogs/logs"
$APP_NAME = "xcblog"

## 外部卷映射路径

$VOLUME_PATH_DATA = Join-Path "${DEPLOY_PATH}" "blogs\data"
$VOLUME_PATH_LOGS = Join-Path "${DEPLOY_PATH}" "blogs\logs"

function log_info {
    param([string]$msg)
    Write-Host "[INFO]: $msg"
}

function log_error {
    param([string]$msg)
    Write-Host "[ERROR]: $msg"
}

function clear_env {
    if (Test-Path $BUILD_PATH) {
        Remove-Item -Recurse -Force $BUILD_PATH
    }
    log_info "clear_env"
}

function prepare_folders {
    log_info "prepare basic folders"
    New-Item -ItemType Directory -Force -Path $BUILD_DIR | Out-Null
    New-Item -ItemType Directory -Force -Path $DEPLOY_PATH | Out-Null
    log_info "finish prepare basic folders"
}

function get_source_code {
    log_info "get_source_code start"
    if (Test-Path $BUILD_PATH) {
        Remove-Item -Recurse -Force $BUILD_PATH
    }
    Copy-Item -Recurse $CODE_PATH $BUILD_PATH
    log_info "get_source_code finish"
}

function build_app {
    log_info "build_app start"
    Push-Location $BUILD_PATH
    try {
        mvn clean package > $null
        if ($LASTEXITCODE -ne 0) {
            log_error "build app failed"
            exit 1
        }
    }
    finally {
        Pop-Location
    }
    log_info "build_app finish"
}

function build_image {
    log_info "build image start"
    # 开启中间层调试: $env:DOCKER_BUILDKIT = 0
    try {
        Push-Location $BUILD_PATH
        docker build --no-cache -t "xiaocui/blogs:${VERSION}" . > $null
        if ($LASTEXITCODE -ne 0) {
            throw "Build failed"
        }
    } catch {
        log_error "build image failed"
        throw
    } finally {
        Pop-Location
    }
    log_info "build image finish"

    log_info "save image start "
    docker save -o "${IMAGE_BUILD_PATH}" "xiaocui/blogs:${VERSION}"
    if ($LASTEXITCODE -ne 0) {
        log_error "save image failed"
        throw
    }
    log_info "save image finish"
}

function push_image {
    log_info "push_image start"
    Copy-Item $IMAGE_BUILD_PATH $DEPLOY_PATH
    log_info "push_image finish"
}

function load_image {
    log_info "load image start"
    docker load -i "${IMAGE_DEPLOY_PATH}"
    docker image prune -f
    log_info "load image finish"
}

function run {
    log_info "run container start"
    docker stop $APP_NAME
    docker rm $APP_NAME
    docker run --name $APP_NAME -d -p 80:8080 -v ${VOLUME_PATH_DATA}:${DATA_DIR} -v ${VOLUME_PATH_LOGS}:${LOG_DIR} xiaocui/blogs:$VERSION
    if ($LASTEXITCODE -ne 0) {
        log_error "run container failed"
        throw
    }
    docker container prune -f
    log_info "run container finish"
}

function main {
    try {
        prepare_folders

        get_source_code

        build_app

        build_image

        push_image

        load_image

        run
    } catch {
        log_error "Script execution failed: $_"
        exit 1
    } finally {
        clear_env
    }
}

main