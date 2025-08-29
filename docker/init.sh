#!/bin/bash

echo "Starting Epay initialization..."

# 等待 MySQL 服务启动
echo "Waiting for MySQL to be ready..."
until nc -z mysql 3306 2>/dev/null; do
  echo "MySQL is unavailable - sleeping"
  sleep 2
done
echo "MySQL is ready!"

# 设置默认环境变量
DB_HOST=${DB_HOST:-mysql}
DB_PORT=${DB_PORT:-3306}
DB_NAME=${DB_NAME:-epay}
DB_USER=${DB_USER:-epay_user}
DB_PASSWORD=${DB_PASSWORD:-epay_pass}
DB_PREFIX=${DB_PREFIX:-pay}

# 检查 config.php 文件是否存在
if [ ! -f /var/www/html/config.php ]; then
    echo "Warning: config.php not found! Please create it manually."
    echo "Database configuration should be:"
    echo "  Host: ${DB_HOST}"
    echo "  Port: ${DB_PORT}"
    echo "  Database: ${DB_NAME}"
    echo "  Username: ${DB_USER}"
    echo "  Password: ${DB_PASSWORD}"
    echo "  Prefix: ${DB_PREFIX}"
else
    echo "Config.php found, using existing configuration."
fi

# 检查数据库是否已初始化
echo "Checking database initialization..."
mysql -h${DB_HOST} -P${DB_PORT} -u${DB_USER} -p${DB_PASSWORD} ${DB_NAME} -e "SELECT 1 FROM ${DB_PREFIX}_config LIMIT 1;" 2>/dev/null

if [ $? -ne 0 ]; then
    echo "Database not initialized. Running initialization..."
    
    # 生成随机密钥
    SYSKEY=$(openssl rand -hex 16)
    CRONKEY=$(shuf -i 111111-999999 -n 1)
    BUILD_DATE=$(date +%Y-%m-%d)
    
    # 执行 SQL 初始化
    mysql -h${DB_HOST} -P${DB_PORT} -u${DB_USER} -p${DB_PASSWORD} ${DB_NAME} << EOF
$(sed "s/pre_/${DB_PREFIX}_/g" /var/www/html/install/install.sql)
INSERT INTO ${DB_PREFIX}_config VALUES ('syskey', '${SYSKEY}');
INSERT INTO ${DB_PREFIX}_config VALUES ('build', '${BUILD_DATE}');
INSERT INTO ${DB_PREFIX}_config VALUES ('cronkey', '${CRONKEY}');
EOF
    
    if [ $? -eq 0 ]; then
        echo "Database initialized successfully!"
        # 创建安装锁文件
        touch /var/www/html/install/install.lock
    else
        echo "Database initialization failed!"
        exit 1
    fi
else
    echo "Database already initialized."
fi

# 设置权限
echo "Setting file permissions..."
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html
find /var/www/html -type f -name "*.php" -exec chmod 644 {} \;

echo "Epay initialization completed!"

# 启动 php-fpm
echo "Starting PHP-FPM..."
exec php-fpm