# Epay Docker 部署指南

这是彩虹易支付系统的 Docker 化版本，提供简洁的部署方案。

## 快速开始

### 1. 环境要求

- Docker >= 20.10
- Docker Compose >= 1.29

### 2. 配置环境变量

复制并编辑环境配置文件：

```bash
cp .env.example .env
```

编辑 `.env` 文件中的配置：

```env
# 数据库配置
DB_NAME=epay
DB_USER=epay_user
DB_PASSWORD=your_secure_password
DB_PREFIX=pay

# MySQL Root 密码
MYSQL_ROOT_PASSWORD=your_root_password

# 应用端口
APP_PORT=8080
```

### 3. 启动服务

```bash
# 构建并启动所有服务
docker-compose up -d

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f app
```

### 4. 访问应用

- **前端访问**: http://localhost:8080
- **后台管理**: http://localhost:8080/admin/
  - 默认账号: admin
  - 默认密码: 123456

### 5. SSL 配置 (生产环境)

在宿主机配置 nginx 反向代理处理 SSL：

```nginx
server {
    listen 443 ssl http2;
    server_name your-domain.com;
    
    ssl_certificate /path/to/your/cert.pem;
    ssl_certificate_key /path/to/your/key.pem;
    
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}
```

## 目录结构

```
epay-docker/
├── docker/                 # Docker 配置文件
│   ├── init.sh             # 初始化脚本
│   ├── nginx.conf          # Nginx 主配置
│   ├── default.conf        # Nginx 虚拟主机配置
│   ├── php.ini             # PHP 配置
│   └── mysql.cnf           # MySQL 配置
├── Dockerfile              # PHP 应用镜像
├── docker-compose.yml      # 服务编排配置
├── .env                    # 环境变量配置
└── README-DOCKER.md        # 部署文档
```

## 常用命令

```bash
# 启动服务
docker-compose up -d

# 停止服务
docker-compose down

# 重启服务
docker-compose restart

# 查看日志
docker-compose logs -f app

# 进入容器
docker-compose exec app bash

# 重建应用镜像
docker-compose build --no-cache app

# 数据库备份
docker-compose exec mysql mysqldump -uepay_user -p epay > backup.sql

# 数据库恢复
docker-compose exec -T mysql mysql -uepay_user -p epay < backup.sql
```

## 数据持久化

- MySQL 数据存储在 Docker 卷 `mysql_data` 中
- 应用代码通过绑定挂载与宿主机同步

## 安全建议

1. **修改默认密码**: 首次部署后立即修改管理员密码
2. **数据库密码**: 使用强密码并定期更换
3. **防火墙配置**: 只开放必要的端口 (80, 443)
4. **SSL 证书**: 生产环境必须使用 HTTPS
5. **定期备份**: 设置自动备份计划

## 故障排除

### 1. 容器启动失败

```bash
# 查看详细日志
docker-compose logs app
docker-compose logs mysql

# 检查端口占用
netstat -tulnp | grep :8080
```

### 2. 数据库连接失败

```bash
# 检查 MySQL 容器状态
docker-compose exec mysql mysql -uroot -p -e "SHOW DATABASES;"

# 重新初始化数据库
docker-compose down -v
docker-compose up -d
```

### 3. 权限问题

```bash
# 修复文件权限
docker-compose exec app chown -R www-data:www-data /var/www/html
```

## 开发环境

开发时可以实时编辑代码，容器会自动同步：

```bash
# 启用开发模式
echo "DEBUG_MODE=true" >> .env
docker-compose up -d
```

## 更新应用

```bash
# 拉取最新代码
git pull origin main

# 重建并重启
docker-compose build --no-cache
docker-compose up -d
```