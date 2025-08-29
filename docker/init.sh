#!/bin/bash

echo "Starting Epay container..."

# 等待 MySQL 服务启动
echo "Waiting for MySQL to be ready..."
until nc -z mysql 3306 2>/dev/null; do
  echo "MySQL is unavailable - sleeping"
  sleep 2
done
echo "MySQL is ready!"

# 设置文件权限
echo "Setting file permissions..."
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html
find /var/www/html -type f -name "*.php" -exec chmod 644 {} \;

# 确保安装目录可写
chmod 777 /var/www/html/install

echo "Epay container initialization completed!"
echo ""
echo "Please visit http://your-server:port/install/ to complete the installation"
echo "Database connection info:"
echo "  Host: mysql"
echo "  Port: 3306"
echo "  Database: $MYSQL_DATABASE"
echo "  Username: $MYSQL_USER"  
echo "  Password: $MYSQL_PASSWORD"
echo ""
echo "IMPORTANT: Please manually delete the install directory after installation!"
echo ""

# 启动 php-fpm
echo "Starting PHP-FPM..."
exec php-fpm