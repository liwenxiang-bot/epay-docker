FROM php:8.1-fpm

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libzip-dev \
    libcurl4-openssl-dev \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# 安装 PHP 扩展
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    gd \
    pdo \
    pdo_mysql \
    mysqli \
    zip \
    curl \
    && docker-php-ext-enable opcache

# 配置 PHP
RUN echo "memory_limit = 256M" > /usr/local/etc/php/conf.d/memory-limit.ini \
    && echo "upload_max_filesize = 50M" > /usr/local/etc/php/conf.d/upload.ini \
    && echo "post_max_size = 50M" >> /usr/local/etc/php/conf.d/upload.ini \
    && echo "max_execution_time = 300" > /usr/local/etc/php/conf.d/execution-time.ini

# 设置工作目录
WORKDIR /var/www/html

# 复制应用代码
COPY . /var/www/html/

# 设置权限
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html \
    && chmod -R 777 /var/www/html/install

# 安装 netcat 用于检测 MySQL
RUN apt-get update && apt-get install -y netcat-openbsd mariadb-client && rm -rf /var/lib/apt/lists/*

# 创建初始化脚本
COPY docker/init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh

EXPOSE 9000

CMD ["sh", "-c", "echo 'Starting PHP-FPM directly for testing...' && php-fpm"]