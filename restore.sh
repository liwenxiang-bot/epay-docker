#!/bin/bash

# Epay Docker 数据恢复脚本

if [ $# -eq 0 ]; then
    echo "用法: $0 <备份目录>"
    echo "示例: $0 ./backups/20241201_143022"
    exit 1
fi

BACKUP_DIR=$1

if [ ! -d "$BACKUP_DIR" ]; then
    echo "错误: 备份目录 $BACKUP_DIR 不存在"
    exit 1
fi

echo "从 $BACKUP_DIR 恢复数据..."

# 1. 停止服务
echo "停止Docker服务..."
docker-compose down

# 2. 恢复环境配置
echo "恢复环境配置..."
if [ -f "$BACKUP_DIR/.env" ]; then
    cp "$BACKUP_DIR/.env" ./
fi

# 3. 恢复Docker卷
echo "恢复数据卷..."
docker volume create epay-docker_mysql_data
docker volume create epay-docker_app_data

if [ -f "$BACKUP_DIR/mysql_data.tar.gz" ]; then
    docker run --rm -v epay-docker_mysql_data:/target -v $(pwd)/$BACKUP_DIR:/backup alpine sh -c "cd /target && tar xzf /backup/mysql_data.tar.gz"
fi

if [ -f "$BACKUP_DIR/app_data.tar.gz" ]; then
    docker run --rm -v epay-docker_app_data:/target -v $(pwd)/$BACKUP_DIR:/backup alpine sh -c "cd /target && tar xzf /backup/app_data.tar.gz"
fi

# 4. 启动服务
echo "启动Docker服务..."
docker-compose up -d

# 5. 恢复数据库（可选，如果需要从SQL文件恢复）
if [ -f "$BACKUP_DIR/mysql_dump.sql" ]; then
    echo "等待MySQL启动..."
    sleep 30
    echo "恢复数据库数据..."
    docker exec -i epay-mysql mysql -u root -p${MYSQL_ROOT_PASSWORD} < "$BACKUP_DIR/mysql_dump.sql"
fi

echo "恢复完成！"