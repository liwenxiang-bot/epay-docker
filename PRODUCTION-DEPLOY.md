# Epay 生产环境部署指南

本指南适用于在 Ubuntu Linux x86_64 服务器上部署 Epay Docker 版本。

## 🔧 部署前准备

### 1. 系统要求

- **操作系统**: Ubuntu 18.04+ 或其他支持 Docker 的 Linux 发行版
- **架构**: x86_64 (AMD64)
- **内存**: 建议 2GB+
- **存储**: 建议 20GB+ 可用空间
- **网络**: 稳定的互联网连接

### 2. 安装 Docker 和 Docker Compose

```bash
# 安装 Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# 将用户添加到 docker 组
sudo usermod -aG docker $USER

# 安装 Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 启动 Docker 服务
sudo systemctl start docker
sudo systemctl enable docker

# 重新登录或执行以下命令使组权限生效
newgrp docker
```

## 🚀 快速部署

### 1. 下载项目

```bash
git clone https://github.com/your-username/epay-docker.git
cd epay-docker
```

### 2. 配置环境变量

```bash
# 复制生产环境配置模板
cp .env.production .env

# 编辑配置文件，设置安全密码
nano .env
```

**重要配置项说明：**

```env
# 数据库配置 - 必须修改默认密码
DB_NAME=epay_prod
DB_USER=epay_user
DB_PASSWORD=your_very_secure_password_here  # 请修改
DB_PREFIX=pre

# MySQL Root 密码 - 必须修改
MYSQL_ROOT_PASSWORD=your_very_secure_root_password_here  # 请修改

# 应用端口
APP_PORT=8080

# 生产模式
DEBUG_MODE=false
```

### 3. 运行部署脚本

```bash
# 使用自动化部署脚本（推荐）
./deploy-production.sh

# 或手动部署
docker-compose up -d --build
```

### 4. 完成Web安装

部署完成后，需要通过浏览器完成安装：

1. **访问安装页面**: http://your-server-ip:8080/install/
2. **填写数据库信息**:
   - 主机: `mysql`
   - 端口: `3306`  
   - 数据库名: 在.env文件中配置的DB_NAME
   - 用户名: 在.env文件中配置的DB_USER
   - 密码: 在.env文件中配置的DB_PASSWORD
   - 表前缀: 在.env文件中配置的DB_PREFIX
3. **设置管理员账号**: 按提示设置管理员用户名和密码
4. **完成安装**: 删除install目录或重命名以确保安全

**安装完成后立即执行：**
- 修改默认管理员密码
- 删除或重命名install目录
- 配置SSL证书和反向代理

## 🔒 安全配置

### 1. 防火墙设置

```bash
# 安装并配置 UFW 防火墙
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

# 如果需要直接访问应用端口（不推荐）
sudo ufw allow 8080/tcp
```

### 2. SSL 配置（推荐）

在宿主机配置 Nginx 反向代理和 SSL：

```bash
# 安装 Nginx
sudo apt update
sudo apt install nginx

# 安装 Certbot（Let's Encrypt）
sudo apt install certbot python3-certbot-nginx
```

**Nginx 配置示例** (`/etc/nginx/sites-available/epay`):

```nginx
server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;

    # SSL 配置（通过 certbot 自动生成）
    
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

```bash
# 启用站点
sudo ln -s /etc/nginx/sites-available/epay /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

# 申请 SSL 证书
sudo certbot --nginx -d your-domain.com
```

## 📊 部署后检查

### 1. 检查服务状态

```bash
# 检查容器状态
docker-compose ps

# 查看日志
docker-compose logs -f
```

### 2. 访问应用

- **通过域名**: https://your-domain.com
- **通过IP**: http://服务器IP:8080
- **管理后台**: /admin/
- **默认账号**: admin / 123456

### 3. 必做安全检查

- [ ] 修改管理员密码
- [ ] 检查数据库连接
- [ ] 测试支付功能
- [ ] 配置系统监控
- [ ] 设置数据库备份

## 🔄 维护操作

### 数据库备份

```bash
# 手动备份
docker-compose exec mysql mysqldump -u epay_user -p epay_prod > backup_$(date +%Y%m%d_%H%M%S).sql

# 设置定时备份（crontab）
0 2 * * * cd /path/to/epay-docker && docker-compose exec -T mysql mysqldump -u epay_user -p${DB_PASSWORD} ${DB_NAME} > /backup/epay_$(date +\%Y\%m\%d).sql
```

### 更新应用

```bash
# 拉取最新代码
git pull origin main

# 重新构建和部署
docker-compose build --no-cache
docker-compose up -d
```

### 查看日志

```bash
# 实时查看所有日志
docker-compose logs -f

# 查看特定服务日志
docker-compose logs -f app
docker-compose logs -f mysql
docker-compose logs -f nginx
```

## ⚠️ 故障排除

### 常见问题

1. **端口被占用**
   ```bash
   # 检查端口占用
   sudo netstat -tulnp | grep :8080
   
   # 修改 .env 中的 APP_PORT
   ```

2. **权限问题**
   ```bash
   # 检查 Docker 权限
   docker ps
   
   # 如果提示权限错误
   sudo usermod -aG docker $USER
   newgrp docker
   ```

3. **MySQL 连接失败**
   ```bash
   # 检查 MySQL 容器日志
   docker-compose logs mysql
   
   # 重置数据库
   docker-compose down -v
   docker-compose up -d
   ```

## 📈 性能优化

### 1. 资源限制

在 `docker-compose.yml` 中添加资源限制：

```yaml
services:
  app:
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M
  mysql:
    deploy:
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 512M
```

### 2. 系统监控

```bash
# 安装系统监控工具
sudo apt install htop iotop

# 监控 Docker 资源使用
docker stats
```

## 🆘 支持

如遇问题，请：

1. 检查日志：`docker-compose logs`
2. 查看系统资源：`htop`, `df -h`
3. 检查网络连接：`netstat -tulnp`
4. 确认防火墙规则：`sudo ufw status`

---

**安全提醒**: 
- 定期更新系统和 Docker
- 使用强密码
- 定期备份数据
- 监控系统日志
- 及时更新应用版本