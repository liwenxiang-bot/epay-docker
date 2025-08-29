#!/usr/bin/env bash

# Epay 生产环境部署脚本
# 适用于 Ubuntu Linux x86_64

set -e

PROJECT_NAME="epay-docker"
COMPOSE_FILE="docker-compose.yml"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查系统环境
check_system() {
    log_info "检查系统环境..."
    
    # 检查操作系统
    if [[ ! -f /etc/os-release ]]; then
        log_error "无法检测操作系统版本"
        exit 1
    fi
    
    . /etc/os-release
    log_info "操作系统: $NAME $VERSION"
    
    # 检查架构
    ARCH=$(uname -m)
    log_info "系统架构: $ARCH"
    
    if [[ "$ARCH" != "x86_64" ]]; then
        log_warning "检测到非 x86_64 架构: $ARCH"
        log_warning "请确保 Docker 镜像支持此架构"
    fi
}

# 检查 Docker 环境
check_docker() {
    log_info "检查 Docker 环境..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装"
        log_info "Ubuntu 安装 Docker 命令:"
        echo "curl -fsSL https://get.docker.com -o get-docker.sh"
        echo "sudo sh get-docker.sh"
        echo "sudo usermod -aG docker \$USER"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose 未安装"
        log_info "安装 Docker Compose 命令:"
        echo "sudo curl -L \"https://github.com/docker/compose/releases/latest/download/docker-compose-\$(uname -s)-\$(uname -m)\" -o /usr/local/bin/docker-compose"
        echo "sudo chmod +x /usr/local/bin/docker-compose"
        exit 1
    fi
    
    # 检查 Docker 服务状态
    if ! sudo systemctl is-active --quiet docker; then
        log_info "启动 Docker 服务..."
        sudo systemctl start docker
        sudo systemctl enable docker
    fi
    
    log_success "Docker 环境检查通过"
}

# 检查环境配置
check_env() {
    if [[ ! -f .env ]]; then
        if [[ -f .env.production ]]; then
            log_warning "未找到 .env 文件，将复制 .env.production 模板"
            cp .env.production .env
            log_error "请编辑 .env 文件，设置安全的数据库密码！"
            echo "nano .env"
            exit 1
        else
            log_error "未找到环境配置文件"
            exit 1
        fi
    fi
    
    # 检查是否使用默认密码
    if grep -q "your_very_secure" .env; then
        log_error "检测到默认密码，请修改 .env 文件中的密码设置"
        exit 1
    fi
    
    log_success "环境配置检查通过"
    log_info "数据库将通过Web安装程序进行初始化"
}

# 检查端口占用
check_ports() {
    log_info "检查端口占用..."
    
    APP_PORT=$(grep "APP_PORT=" .env | cut -d'=' -f2)
    APP_PORT=${APP_PORT:-8080}
    
    if netstat -tuln | grep -q ":$APP_PORT "; then
        log_error "端口 $APP_PORT 已被占用"
        log_info "请修改 .env 文件中的 APP_PORT 设置"
        exit 1
    fi
    
    log_success "端口检查通过"
}

# 部署应用
deploy() {
    log_info "开始部署 $PROJECT_NAME..."
    
    # 创建数据目录并设置权限
    log_info "创建数据目录并设置权限..."
    mkdir -p ./data
    sudo chown -R 1000:1000 ./data
    chmod -R 755 ./data
    
    # 确保应用目录权限正确
    log_info "设置应用目录权限..."
    sudo chown -R 1000:1000 .
    
    # 拉取镜像
    log_info "拉取 Docker 镜像..."
    docker-compose pull
    
    # 构建并启动服务
    log_info "构建并启动服务..."
    docker-compose up -d --build
    
    # 等待服务启动
    log_info "等待服务启动..."
    sleep 15
    
    # 检查服务状态
    if docker-compose ps | grep -q "Up"; then
        APP_PORT=$(grep "APP_PORT=" .env | cut -d'=' -f2)
        APP_PORT=${APP_PORT:-8080}
        
        log_success "部署成功！"
        echo ""
        log_info "访问信息:"
        log_info "  应用地址: http://$(hostname -I | awk '{print $1}'):$APP_PORT"
        log_info "  安装页面: http://$(hostname -I | awk '{print $1}'):$APP_PORT/install/"
        echo ""
        log_warning "下一步操作:"
        log_warning "1. 访问安装页面完成初始化"
        log_warning "2. 使用以下数据库信息进行安装:"
        MYSQL_DATABASE=$(grep "MYSQL_DATABASE=" .env | cut -d'=' -f2)
        MYSQL_USER=$(grep "MYSQL_USER=" .env | cut -d'=' -f2)
        MYSQL_PASSWORD=$(grep "MYSQL_PASSWORD=" .env | cut -d'=' -f2)
        log_warning "   主机: mysql"
        log_warning "   端口: 3306"
        log_warning "   数据库: ${MYSQL_DATABASE:-epay}"
        log_warning "   用户名: ${MYSQL_USER:-epay_user}"
        log_warning "   密码: ${MYSQL_PASSWORD:-epay_pass}"
        log_warning "   前缀: pay"
        echo ""
        log_warning "安装完成后请:"
        log_warning "1. 立即修改管理员密码"
        log_warning "2. 配置宿主机 nginx 反向代理和 SSL"
        log_warning "3. 设置防火墙规则"
        log_warning "4. 配置定期备份"
        
    else
        log_error "服务启动失败"
        docker-compose logs
        exit 1
    fi
}

# 显示防火墙配置建议
show_firewall_config() {
    echo ""
    log_info "Ubuntu 防火墙配置建议:"
    echo "sudo ufw allow ssh"
    echo "sudo ufw allow 80/tcp"
    echo "sudo ufw allow 443/tcp"
    echo "sudo ufw --force enable"
    echo ""
    log_info "如果需要直接访问应用端口："
    APP_PORT=$(grep "APP_PORT=" .env | cut -d'=' -f2 || echo "8080")
    echo "sudo ufw allow $APP_PORT/tcp"
}

# 主函数
main() {
    echo "=========================================="
    echo "         Epay 生产环境部署工具"
    echo "         适用于 Ubuntu Linux x86_64"
    echo "=========================================="
    echo ""
    
    check_system
    check_docker
    check_env
    check_ports
    deploy
    show_firewall_config
    
    echo ""
    log_success "部署完成！"
}

# 检查是否在正确的目录
if [[ ! -f "$COMPOSE_FILE" ]]; then
    log_error "未找到 $COMPOSE_FILE 文件"
    log_error "请在项目根目录中运行此脚本"
    exit 1
fi

# 确保脚本有可执行权限
if [[ ! -x "$0" ]]; then
    chmod +x "$0"
fi

# 运行主函数
main "$@"