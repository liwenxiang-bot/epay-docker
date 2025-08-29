#!/bin/bash

# Epay Docker 数据备份脚本

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="./backups/$DATE"

echo "创建备份目录: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# 1. 备份MySQL数据
echo "备份MySQL数据..."
docker exec epay-mysql mysqldump -u root -p${MYSQL_ROOT_PASSWORD} --all-databases > "$BACKUP_DIR/mysql_dump.sql"

# 2. 备份Docker卷
echo "备份Docker数据卷..."
docker run --rm -v epay-docker_mysql_data:/source -v $(pwd)/$BACKUP_DIR:/backup alpine tar czf /backup/mysql_data.tar.gz -C /source .
docker run --rm -v epay-docker_app_data:/source -v $(pwd)/$BACKUP_DIR:/backup alpine tar czf /backup/app_data.tar.gz -C /source .

# 3. 备份应用配置
echo "备份应用配置..."
cp .env "$BACKUP_DIR/"
cp docker-compose.yml "$BACKUP_DIR/"

# 4. 备份上传文件等（如果存在）
if [ -d "./uploads" ]; then
    cp -r ./uploads "$BACKUP_DIR/"
fi

echo "备份完成！备份位置: $BACKUP_DIR"
echo ""
echo "迁移时请备份以下内容："
echo "1. $BACKUP_DIR/mysql_dump.sql - 数据库数据"
echo "2. $BACKUP_DIR/mysql_data.tar.gz - MySQL数据卷"
echo "3. $BACKUP_DIR/app_data.tar.gz - 应用数据卷"
echo "4. $BACKUP_DIR/.env - 环境配置"
echo "5. 整个项目目录 - 应用代码和配置"