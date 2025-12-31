#!/usr/bin/env bash

# Epay 生产环境部署脚本 - 阿里云 RDS 版本
# 适用于 Ubuntu Linux

set -e

PROJECT_NAME="epay-docker"
COMPOSE_FILE="docker-compose.rds.yml"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查系统环境
check_system() {
    log_info "检查系统环境..."

    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        log_info "操作系统: $NAME $VERSION"
    fi

    log_info "系统架构: $(uname -m)"
}

# 检查 Docker 环境
check_docker() {
    log_info "检查 Docker 环境..."

    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装，请先安装 Docker:"
        echo "curl -fsSL https://get.docker.com | sh"
        echo "sudo usermod -aG docker \$USER"
        exit 1
    fi

    # 检查 docker compose (v2) 或 docker-compose (v1)
    if docker compose version &> /dev/null; then
        DOCKER_COMPOSE="docker compose"
    elif command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE="docker-compose"
    else
        log_error "Docker Compose 未安装"
        exit 1
    fi

    log_success "Docker 环境检查通过 (使用 $DOCKER_COMPOSE)"
}

# 检查配置文件
check_config() {
    log_info "检查配置文件..."

    # 检查 .env 文件
    if [[ ! -f .env ]]; then
        if [[ -f .env.rds ]]; then
            cp .env.rds .env
            log_info "已创建 .env 文件"
        else
            echo "APP_PORT=8080" > .env
        fi
    fi

    # 检查 config.php 文件
    if [[ ! -f config.php ]]; then
        if [[ -f config.php.example ]]; then
            log_error "请先配置数据库连接:"
            log_error "  cp config.php.example config.php"
            log_error "  nano config.php"
            exit 1
        fi
    fi

    # 验证 config.php 中的数据库配置
    if grep -q "rm-xxxx\|your_username\|your_password" config.php 2>/dev/null; then
        log_error "请修改 config.php 中的数据库配置！"
        exit 1
    fi

    log_success "配置文件检查通过"
}

# 检查端口
check_ports() {
    log_info "检查端口占用..."

    APP_PORT=$(grep "APP_PORT=" .env 2>/dev/null | cut -d'=' -f2 || echo "8080")

    if ss -tuln 2>/dev/null | grep -q ":$APP_PORT " || netstat -tuln 2>/dev/null | grep -q ":$APP_PORT "; then
        log_warning "端口 $APP_PORT 可能被占用，请确认或修改 .env 中的 APP_PORT"
    fi
}

# 部署应用
deploy() {
    log_info "开始部署 $PROJECT_NAME (阿里云 RDS 版本)..."

    # 设置目录权限
    log_info "设置目录权限..."
    mkdir -p ./data
    chmod -R 755 ./data ./install 2>/dev/null || true

    # 创建安装锁文件（数据库已通过 RDS 初始化）
    if [[ ! -f ./install/install.lock ]]; then
        echo "installed" > ./install/install.lock
        log_info "已创建 install.lock 文件"
    fi

    # 构建并启动服务
    log_info "构建并启动服务..."
    $DOCKER_COMPOSE -f $COMPOSE_FILE up -d --build

    # 等待服务启动
    log_info "等待服务启动..."
    sleep 10

    # 检查服务状态
    if $DOCKER_COMPOSE -f $COMPOSE_FILE ps | grep -q "Up\|running"; then
        APP_PORT=$(grep "APP_PORT=" .env 2>/dev/null | cut -d'=' -f2 || echo "8080")
        SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")

        log_success "部署成功！"
        echo ""
        echo "=========================================="
        echo "  访问地址: http://${SERVER_IP}:${APP_PORT}"
        echo "  后台地址: http://${SERVER_IP}:${APP_PORT}/admin/"
        echo "  默认密码: 123456"
        echo "=========================================="
        echo ""
        log_warning "重要提醒:"
        log_warning "1. 请立即修改后台管理员密码"
        log_warning "2. 配置 Nginx 反向代理和 SSL 证书"
        log_warning "3. 设置防火墙规则"
    else
        log_error "服务启动失败，查看日志:"
        $DOCKER_COMPOSE -f $COMPOSE_FILE logs
        exit 1
    fi
}

# 停止服务
stop() {
    log_info "停止服务..."
    $DOCKER_COMPOSE -f $COMPOSE_FILE down
    log_success "服务已停止"
}

# 重启服务
restart() {
    log_info "重启服务..."
    $DOCKER_COMPOSE -f $COMPOSE_FILE restart
    log_success "服务已重启"
}

# 查看日志
logs() {
    $DOCKER_COMPOSE -f $COMPOSE_FILE logs -f
}

# 查看状态
status() {
    $DOCKER_COMPOSE -f $COMPOSE_FILE ps
}

# 显示帮助
show_help() {
    echo "Epay 部署脚本 - 阿里云 RDS 版本"
    echo ""
    echo "用法: $0 [命令]"
    echo ""
    echo "命令:"
    echo "  deploy   部署/更新应用 (默认)"
    echo "  stop     停止服务"
    echo "  restart  重启服务"
    echo "  logs     查看日志"
    echo "  status   查看状态"
    echo "  help     显示帮助"
}

# 主函数
main() {
    echo "=========================================="
    echo "    Epay 部署工具 - 阿里云 RDS 版本"
    echo "=========================================="
    echo ""

    check_system
    check_docker
    check_config
    check_ports
    deploy
}

# 检查是否在项目目录
if [[ ! -f "$COMPOSE_FILE" ]]; then
    log_error "未找到 $COMPOSE_FILE"
    log_error "请在项目根目录运行此脚本"
    exit 1
fi

# 命令处理
case "${1:-deploy}" in
    deploy)  main ;;
    stop)    check_docker && stop ;;
    restart) check_docker && restart ;;
    logs)    check_docker && logs ;;
    status)  check_docker && status ;;
    help|--help|-h) show_help ;;
    *)
        log_error "未知命令: $1"
        show_help
        exit 1
        ;;
esac
