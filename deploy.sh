#!/bin/bash

# Epay Docker 部署脚本
# 使用方法: ./deploy.sh [start|stop|restart|status|logs]

set -e

PROJECT_NAME="epay-docker"
COMPOSE_FILE="docker-compose.yml"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
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

# 检查 Docker 和 Docker Compose
check_requirements() {
    log_info "检查运行环境..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose 未安装，请先安装 Docker Compose"
        exit 1
    fi
    
    log_success "运行环境检查通过"
}

# 创建 .env 文件
create_env() {
    if [ ! -f .env ]; then
        log_info "创建 .env 配置文件..."
        cat > .env << EOF
# 数据库配置
DB_NAME=epay
DB_USER=epay_user
DB_PASSWORD=epay_pass_$(date +%s)
DB_PREFIX=pay

# MySQL Root 密码
MYSQL_ROOT_PASSWORD=root_pass_$(date +%s)

# 应用端口配置
APP_PORT=8080

# 开发模式 (true/false)
DEBUG_MODE=false
EOF
        log_success ".env 文件创建成功"
        log_warning "请检查并修改 .env 文件中的数据库密码"
    fi
}

# 启动服务
start_service() {
    log_info "启动 $PROJECT_NAME 服务..."
    
    check_requirements
    create_env
    
    # 构建并启动服务
    docker-compose up -d --build
    
    # 等待服务启动
    log_info "等待服务启动中..."
    sleep 10
    
    # 检查服务状态
    if docker-compose ps | grep -q "Up"; then
        log_success "服务启动成功！"
        echo ""
        log_info "访问地址:"
        log_info "  前端: http://localhost:8080"
        log_info "  后台: http://localhost:8080/admin/"
        log_info "  默认管理员账号: admin / 123456"
        echo ""
        log_warning "首次启动可能需要几分钟初始化数据库，请耐心等待"
        log_warning "建议立即修改管理员密码！"
    else
        log_error "服务启动失败，请检查日志"
        docker-compose logs
        exit 1
    fi
}

# 停止服务
stop_service() {
    log_info "停止 $PROJECT_NAME 服务..."
    docker-compose down
    log_success "服务已停止"
}

# 重启服务
restart_service() {
    log_info "重启 $PROJECT_NAME 服务..."
    docker-compose restart
    log_success "服务已重启"
}

# 查看服务状态
show_status() {
    log_info "$PROJECT_NAME 服务状态:"
    docker-compose ps
}

# 查看日志
show_logs() {
    log_info "查看 $PROJECT_NAME 服务日志:"
    docker-compose logs -f --tail=50
}

# 清理资源
cleanup() {
    log_warning "这将删除所有容器、网络和数据卷！"
    read -p "确认要清理所有资源吗？(y/N): " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "清理资源中..."
        docker-compose down -v --rmi all
        docker system prune -f
        log_success "资源清理完成"
    else
        log_info "取消清理操作"
    fi
}

# 备份数据库
backup_database() {
    log_info "备份数据库中..."
    backup_file="epay_backup_$(date +%Y%m%d_%H%M%S).sql"
    
    if docker-compose exec -T mysql mysqldump -u"${DB_USER:-epay_user}" -p"${DB_PASSWORD}" "${DB_NAME:-epay}" > "$backup_file"; then
        log_success "数据库备份完成: $backup_file"
    else
        log_error "数据库备份失败"
        exit 1
    fi
}

# 显示帮助信息
show_help() {
    echo "Epay Docker 部署脚本"
    echo ""
    echo "使用方法: $0 [命令]"
    echo ""
    echo "可用命令:"
    echo "  start     启动服务"
    echo "  stop      停止服务"
    echo "  restart   重启服务"
    echo "  status    查看服务状态"
    echo "  logs      查看服务日志"
    echo "  backup    备份数据库"
    echo "  cleanup   清理所有资源"
    echo "  help      显示帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 start    # 启动服务"
    echo "  $0 logs     # 查看实时日志"
    echo "  $0 backup   # 备份数据库"
}

# 主函数
main() {
    case "${1:-start}" in
        "start")
            start_service
            ;;
        "stop")
            stop_service
            ;;
        "restart")
            restart_service
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs
            ;;
        "backup")
            backup_database
            ;;
        "cleanup")
            cleanup
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_error "未知命令: $1"
            show_help
            exit 1
            ;;
    esac
}

# 确保脚本在正确的目录中运行
if [ ! -f "$COMPOSE_FILE" ]; then
    log_error "未找到 $COMPOSE_FILE 文件，请在项目根目录中运行此脚本"
    exit 1
fi

# 运行主函数
main "$@"