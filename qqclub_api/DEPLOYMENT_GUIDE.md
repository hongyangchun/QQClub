# QQClub API 部署指南

## 🚀 快速开始

### 环境要求
- Ruby 3.2.0+
- Rails 7.1+
- PostgreSQL 13+
- Redis 6.0+
- Node.js 16+ (用于资产编译)
- Nginx (生产环境推荐)

### 一键部署脚本
```bash
#!/bin/bash
# scripts/deploy.sh

echo "🚀 开始部署 QQClub API..."

# 1. 环境检查
echo "📋 检查环境依赖..."
ruby -v
rails -v
psql --version
redis-server --version

# 2. 安装依赖
echo "📦 安装依赖..."
bundle install
yarn install

# 3. 数据库设置
echo "🗄️ 设置数据库..."
rails db:create
rails db:migrate
rails db:seed

# 4. 编译资产
echo "🎨 编译资产..."
rails assets:precompile

# 5. 启动服务
echo "🔄 启动服务..."
rails server -e production

echo "✅ 部署完成！"
echo "🌐 API地址: http://localhost:3000"
echo "📚 API文档: http://localhost:3000/api/docs"
```

## 🔧 详细部署步骤

### 1. 环境准备

#### 系统依赖安装
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y build-essential libpq-dev redis-server nginx

# CentOS/RHEL
sudo yum groupinstall -y "Development Tools"
sudo yum install -y postgresql-devel redis nginx
```

#### Ruby环境配置
```bash
# 使用 rbenv 安装 Ruby
rbenv install 3.2.0
rbenv global 3.2.0

# 验证安装
ruby -v  # 应该显示 ruby 3.2.0
```

#### 数据库配置
```bash
# PostgreSQL 安装和配置
sudo -u postgres createuser qqclub
sudo -u postgres createdb qqclub_production
sudo -u postgres psql -c "ALTER USER qqclub PASSWORD 'your_password';"

# Redis 配置
sudo systemctl start redis
sudo systemctl enable redis
```

### 2. 应用部署

#### 代码部署
```bash
# 克隆代码仓库
git clone https://github.com/your-org/qqclub_api.git
cd qqclub_api

# 切换到生产分支
git checkout main
git pull origin main

# 安装依赖
bundle install --deployment --without development test
yarn install --production
```

#### 环境变量配置
```bash
# 复制环境变量模板
cp .env.example .env.production

# 编辑环境变量
vim .env.production
```

**.env.production 配置示例**:
```bash
# 应用配置
RAILS_ENV=production
RAILS_MASTER_KEY=your_rails_master_key
SECRET_KEY_BASE=your_secret_key_base

# 数据库配置
DATABASE_URL=postgresql://qqclub:password@localhost/qqclub_production

# Redis配置
REDIS_URL=redis://localhost:6379/0

# 缓存配置
CACHE_NAMESPACE=qqclub_cache_production

# 安全配置
JWT_SECRET=your_jwt_secret_key
ENCRYPTION_SECRET=your_encryption_secret

# 监控配置
SENTRY_DSN=your_sentry_dsn
LOG_LEVEL=info

# 性能配置
RAILS_MAX_THREADS=5
WEB_CONCURRENCY=2
```

### 3. 数据库初始化

#### 运行迁移
```bash
# 检查迁移状态
rails db:migrate:status

# 运行迁移
rails db:migrate RAILS_ENV=production

# 验证数据库结构
rails db:schema:dump RAILS_ENV=production
```

#### 数据初始化
```bash
# 加载种子数据
rails db:seed RAILS_ENV=production

# 创建管理员用户
rails console RAILS_ENV=production
```

```ruby
# 在 Rails Console 中执行
User.create!(
  nickname: '系统管理员',
  wx_openid: 'admin_system',
  role: :admin,
  email: 'admin@qqclub.com'
)
```

### 4. 资产编译

#### 前端资源编译
```bash
# 清理旧资产
rails assets:clobber RAILS_ENV=production

# 编译生产环境资产
rails assets:precompile RAILS_ENV=production

# 验证资产
ls -la public/assets
```

### 5. 应用服务配置

#### Puma 配置
```ruby
# config/puma.rb
environment 'production'

# 进程和线程配置
threads_count = ENV.fetch('RAILS_MAX_THREADS') { 5 }
threads threads_count, threads_count

# 工作进程数
workers ENV.fetch('WEB_CONCURRENCY') { 2 }

# 端口配置
port ENV.fetch('PORT') { 3000 }

# 启动前预热
preload_app!

# 超时配置
worker_timeout 30
worker_boot_timeout 30

# 日志配置
stdout_redirect 'log/puma.stdout.log', 'log/puma.stderr.log', true

# 进程ID文件
pidfile ENV.fetch('PIDFILE') { 'tmp/pids/server.pid' }

# 状态文件
state_path 'tmp/pids/puma.state'

# 缓存键激活
activate_control_app

# 优雅关闭
on_worker_boot do
  require 'active_support/core_ext/numeric/time'
  puts "Worker #{Process.pid} booting up..."
end

on_worker_shutdown do
  puts "Worker #{Process.pid} shutting down..."
end
```

#### Systemd 服务配置
```ini
# /etc/systemd/system/qqclub-api.service
[Unit]
Description=QQClub API
After=network.target

[Service]
Type=simple
User=deploy
Group=deploy
WorkingDirectory=/var/www/qqclub_api
Environment=RAILS_ENV=production
EnvironmentFile=/var/www/qqclub_api/.env.production
ExecStart=/home/deploy/.rbenv/shims/bundle exec puma -C config/puma.rb
ExecReload=/bin/kill -s USR2 $MAINPID
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
# 启用和启动服务
sudo systemctl daemon-reload
sudo systemctl enable qqclub-api
sudo systemctl start qqclub-api
sudo systemctl status qqclub-api
```

### 6. Web服务器配置

#### Nginx 配置
```nginx
# /etc/nginx/sites-available/qqclub
upstream qqclub_api {
    server unix:///var/www/qqclub_api/tmp/sockets/puma.sock fail_timeout=0;
}

# HTTP 重定向到 HTTPS
server {
    listen 80;
    server_name api.qqclub.com;
    return 301 https://$server_name$request_uri;
}

# HTTPS 主配置
server {
    listen 443 ssl http2;
    server_name api.qqclub.com;

    # SSL 配置
    ssl_certificate /etc/ssl/certs/qqclub_api.crt;
    ssl_certificate_key /etc/ssl/private/qqclub_api.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;

    # 安全头
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # 日志配置
    access_log /var/log/nginx/qqclub_api.access.log;
    error_log /var/log/nginx/qqclub_api.error.log;

    # 根目录
    root /var/www/qqclub_api/public;

    # 静态文件服务
    location ~ ^/(assets|packs)/ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        gzip_static on;
    }

    # API 请求代理
    location / {
        try_files $uri @qqclub_api;
    }

    location @qqclub_api {
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Host $host;
        proxy_redirect off;

        proxy_pass http://qqclub_api;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_http_version 1.1;

        # 超时配置
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }

    # 健康检查
    location /up {
        access_log off;
        proxy_pass http://qqclub_api;
    }

    # 文件上传大小限制
    client_max_body_size 100M;

    # 限制请求大小
    client_body_buffer_size 128k;
    client_header_buffer_size 1k;
    large_client_header_buffers 4 4k;
}
```

```bash
# 启用站点
sudo ln -s /etc/nginx/sites-available/qqclub /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

## 🔍 部署验证

### 健康检查
```bash
# 检查应用状态
curl -f http://localhost:3000/up || exit 1

# 检查API响应
curl -f http://localhost:3000/api/health || exit 1

# 检查数据库连接
curl -f http://localhost:3000/api/health?check_db=true || exit 1

# 检查缓存连接
curl -f http://localhost:3000/api/health?check_cache=true || exit 1
```

### 功能测试
```bash
# API 功能测试
curl -X POST http://localhost:3000/api/auth/mock_login \
  -H "Content-Type: application/json" \
  -d '{"wx_openid": "test_user", "nickname": "测试用户"}'

# 性能测试
ab -n 100 -c 10 http://localhost:3000/api/v1/performance_posts
```

### 监控检查
```bash
# 检查进程状态
ps aux | grep puma
ps aux | grep nginx

# 检查端口监听
netstat -tlnp | grep :3000
netstat -tlnp | grep :80
netstat -tlnp | grep :443

# 检查日志
tail -f /var/www/qqclub_api/log/production.log
tail -f /var/log/nginx/qqclub_api.access.log
```

## 📊 性能优化配置

### 数据库优化
```sql
-- PostgreSQL 配置优化
-- /etc/postgresql/13/main/postgresql.conf

# 内存配置
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 16MB
maintenance_work_mem = 128MB

# 连接配置
max_connections = 100
shared_preload_libraries = 'pg_stat_statements'

# 日志配置
log_min_duration_statement = 1000
log_checkpoints = on
log_connections = on
log_disconnections = on
```

### Redis 优化
```conf
# /etc/redis/redis.conf

# 内存配置
maxmemory 512mb
maxmemory-policy allkeys-lru

# 持久化配置
save 900 1
save 300 10
save 60 10000

# 网络配置
tcp-keepalive 300
timeout 0
```

### 应用服务器优化
```ruby
# config/environments/production.rb

# 缓存配置
config.cache_store = :redis_cache_store, {
  url: ENV['REDIS_URL'],
  namespace: 'qqclub_cache',
  expires_in: 30.minutes,
  compress: true,
  race_condition_ttl: 30.seconds
}

# 线程池配置
config.active_record.database_selector = { delay: 2.seconds }
config.active_record.database_resolver = ActiveRecord::Middleware::DatabaseSelector::Resolver
config.active_record.database_resolver_context = ActiveRecord::Middleware::DatabaseSelector::Resolver::Session

# 日志配置
config.log_level = :info
config.log_tags = [ :request_id ]
config.lograge.enabled = true
config.lograge.formatter = Lograge::Formatters::Json.new

# 静态文件配置
config.public_file_server.enabled = true
config.assets.compile = false
config.assets.digest = true
```

## 🔒 安全配置

### SSL/TLS 配置
```bash
# 生成自签名证书（开发环境）
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/qqclub_api.key \
  -out /etc/ssl/certs/qqclub_api.crt

# 生产环境使用 Let's Encrypt
sudo apt-get install certbot python3-certbot-nginx
sudo certbot --nginx -d api.qqclub.com
```

### 防火墙配置
```bash
# UFW 防火墙配置
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw deny 3000/tcp  # 禁止直接访问应用端口
```

### 安全扫描
```bash
# 安全头检查
curl -I https://api.qqclub.com/api/health

# SSL 配置检查
nmap --script ssl-enum-ciphers -p 443 api.qqclub.com

# 漏洞扫描
nikto -h https://api.qqclub.com
```

## 🔄 持续部署

### Capistrano 配置
```ruby
# Capfile
require 'capistrano/setup'
require 'capistrano/deploy'
require 'capistrano/rails'
require 'capistrano/rbenv'
require 'capistrano/bundler'
require 'capistrano/puma'
require 'capistrano/nginx'

install_plugin Capistrano::Puma
install_plugin Capistrano::Puma::Nginx
```

```ruby
# config/deploy.rb
lock '~> 3.17.0'

set :application, 'qqclub_api'
set :repo_url, 'git@github.com:your-org/qqclub_api.git'
set :branch, 'main'
set :deploy_to, '/var/www/qqclub_api'
set :user, 'deploy'

set :rbenv_type, :user
set :rbenv_ruby, '3.2.0'
set :rbenv_prefix, "RBENV_ROOT=#{fetch(:rbenv_path)} RBENV_VERSION=#{fetch(:rbenv_ruby)} #{fetch(:rbenv_path)}/bin/rbenv exec"
set :rbenv_map_bins, %w{rake gem bundle ruby rails puma pumactl}

set :linked_files, %w{.env.production}
set :linked_dirs, %w{log tmp/pids tmp/cache tmp/sockets vendor/bundle public/assets}

set :puma_threads, [0, 5]
set :puma_workers, 2
set :puma_bind, "unix://#{shared_path}/tmp/sockets/puma.sock"
set :puma_state, "#{shared_path}/tmp/pids/puma.state"
set :puma_pid, "#{shared_path}/tmp/pids/puma.pid"
set :puma_access_log, "#{shared_path}/log/puma_access.log"
set :puma_error_log, "#{shared_path}/log/puma_error.log"
set :puma_preload_app, true
set :puma_init_active_record, true

set :nginx_use_ssl, true
set :nginx_ssl_certificate, '/etc/ssl/certs/qqclub_api.crt'
set :nginx_ssl_certificate_key, '/etc/ssl/private/qqclub_api.key'

namespace :deploy do
  before :compile_assets, :ensure_dependencies
  after :publishing, :restart
end

task :ensure_dependencies do
  on roles(:app) do
    execute "cd #{current_path} && bundle install --deployment --without development test"
  end
end
```

### 部署命令
```bash
# 部署到生产环境
cap production deploy

# 检查部署状态
cap production deploy:check

# 回滚到上一版本
cap production deploy:rollback

# 查看部署日志
cap production deploy:log
```

## 🔧 故障排查

### 常见问题解决

#### 应用无法启动
```bash
# 检查日志
tail -f /var/www/qqclub_api/log/production.log

# 检查权限
sudo chown -R deploy:deploy /var/www/qqclub_api

# 检查环境变量
cat /var/www/qqclub_api/.env.production

# 重启服务
sudo systemctl restart qqclub-api
```

#### 数据库连接问题
```bash
# 测试数据库连接
psql -h localhost -U qqclub -d qqclub_production

# 检查连接数
SELECT count(*) FROM pg_stat_activity;

# 检查慢查询
SELECT query, mean_time, calls FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 10;
```

#### Redis 连接问题
```bash
# 测试 Redis 连接
redis-cli ping

# 检查 Redis 状态
redis-cli info server

# 清理过期键
redis-cli --scan --pattern "rate_limit:*" | xargs redis-cli del
```

#### 性能问题排查
```bash
# 检查系统负载
top
htop
iostat -x 1

# 检查网络连接
netstat -an | grep :3000
ss -tuln

# 检查进程状态
ps aux | grep puma
systemctl status qqclub-api
```

### 日志分析
```bash
# 应用日志分析
grep ERROR /var/www/qqclub_api/log/production.log
grep SLOW /var/www/qqclub_api/log/production.log

# Nginx 日志分析
tail -f /var/log/nginx/qqclub_api.access.log | grep -v "200"
tail -f /var/log/nginx/qqclub_api.error.log

# 系统日志分析
journalctl -u qqclub-api -f
```

## 📈 监控和告警

### 系统监控
```bash
# 安装监控工具
sudo apt-get install htop iotop nethogs

# 监控脚本
#!/bin/bash
# scripts/monitor.sh

echo "=== 系统监控 ==="
echo "CPU使用率:"
top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1

echo "内存使用率:"
free -m | awk 'NR==2{printf "%.2f%%\n", $3*100/$2}'

echo "磁盘使用率:"
df -h | awk '$NF=="/"{printf "%s\n", $5}'

echo "=== 应用监控 ==="
echo "Puma进程数:"
pgrep -f puma | wc -l

echo "Redis连接数:"
redis-cli info clients | grep connected_clients

echo "=== 数据库监控 ==="
echo "数据库连接数:"
psql -U qqclub -d qqclub_production -t -c "SELECT count(*) FROM pg_stat_activity;"
```

### 健康检查脚本
```bash
#!/bin/bash
# scripts/health_check.sh

API_URL="https://api.qqclub.com"
LOG_FILE="/var/log/qqclub_health_check.log"

# 检查 API 健康状态
response=$(curl -s -o /dev/null -w "%{http_code}" $API_URL/up)

if [ "$response" = "200" ]; then
    echo "$(date): API健康检查通过" >> $LOG_FILE
    exit 0
else
    echo "$(date): API健康检查失败 (HTTP $response)" >> $LOG_FILE

    # 发送告警
    curl -X POST "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK" \
      -H 'Content-type: application/json' \
      -d "{\"text\":\"🚨 QQClub API健康检查失败 (HTTP $response)\"}"

    exit 1
fi
```

## 🎯 最佳实践

### 部署清单
- [ ] 环境变量配置完成
- [ ] 数据库迁移执行成功
- [ ] 资产编译完成
- [ ] SSL证书配置正确
- [ ] 防火墙规则设置
- [ ] 监控告警配置
- [ ] 备份策略制定
- [ ] 回滚方案准备

### 维护建议
- 定期更新依赖包
- 监控磁盘空间使用
- 定期备份数据库
- 定期清理日志文件
- 监控性能指标
- 定期安全扫描

---

*本部署指南提供了完整的QQClub API部署流程，包括环境配置、应用部署、性能优化、安全配置和监控告警等各个方面，确保系统能够稳定、安全、高效地运行。*