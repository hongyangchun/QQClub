# QQClub 性能优化部署指南

## 🚀 快速开始

### 1. 环境准备
确保生产环境已配置以下组件：
- Redis (用于缓存)
- PostgreSQL (支持全文搜索索引)
- 足够的内存 (建议 >= 2GB)

### 2. 数据库迁移
```bash
# 备份当前数据库
rails db:backup:create

# 运行性能优化迁移
rails db:migrate

# 验证迁移结果
rails db:schema:dump
```

### 3. 配置Redis缓存
```ruby
# config/environments/production.rb
config.cache_store = :redis_cache_store, {
  url: ENV.fetch('REDIS_URL') { 'redis://localhost:6379/0' },
  namespace: 'qqclub_cache',
  expires_in: 30.minutes,
  compress: true,
  race_condition_ttl: 30.seconds
}
```

### 4. 启用性能监控
```ruby
# config/environments/production.rb
config.log_level = :info
config.log_tags = [:request_id]

# 启用查询日志（仅在需要时）
# config.active_record.logger = Logger.new(STDOUT)
```

## 📊 性能配置参数

### 缓存配置
```ruby
# config/initializers/cache_settings.rb
Rails.application.configure do
  # 缓存层级配置
  config.x.cache = {
    # 内存缓存配置
    memory: {
      enabled: true,
      max_size: 1000,  # 最大缓存项数
      ttl: 5.minutes    # 默认过期时间
    },

    # Redis缓存配置
    redis: {
      enabled: true,
      default_ttl: 30.minutes,
      stats_ttl: 1.hour,
      user_stats_ttl: 1.hour
    }
  }
end
```

### 数据库连接池优化
```ruby
# config/database.yml
production:
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  timeout: 5000
  reconnect: true
  variables:
    # MySQL优化参数
    max_allowed_packet: 256M
    innodb_buffer_pool_size: 1G
    query_cache_size: 128M

    # PostgreSQL优化参数
    shared_buffers: 256MB
    effective_cache_size: 1GB
    work_mem: 16MB
```

## 🔧 性能调优建议

### 1. 应用服务器配置
```ruby
# config/puma.rb
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
threads threads_count, threads_count

port ENV.fetch("PORT") { 3000 }
environment ENV.fetch("RAILS_ENV") { "development" }

# 性能优化配置
preload_app!

# 请求超时设置
max_threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
ram = ENV.fetch("RAILS_MAX_THREADS") { 5 }.to_i
if ram >= 6
  threads_count = ENV.fetch("RAILS_MAX_THREADS") { 6 }
end

# 工作进程数
workers ENV.fetch("WEB_CONCURRENCY") { 2 }

# 预热应用
on_worker_boot do
  # 预热缓存
  require_relative '../lib/cache_warmer'
  CacheWarmer.warmup
end
```

### 2. Nginx配置（可选）
```nginx
# /etc/nginx/sites-available/qqclub
upstream qqclub {
  server unix:///var/www/qqclub/tmp/pids/unicorn.sock fail_timeout=0;
}

server {
  listen 80;
  server_name your-domain.com;
  root /var/www/qqclub/public;

  # Gzip压缩
  gzip on;
  gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

  # 静态文件缓存
  location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
  }

  # 动态内容不缓存
  location /api/ {
    expires -1;
    add_header Cache-Control "no-cache, no-store, must-revalidate";
    add_header Pragma "no-cache";
    add_header Expires "0";
  }

  location / {
    try_files $uri @unicorn;
  }

  location @unicorn {
    proxy_pass http://qqclub;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $http_host;
    proxy_set_header X-Real-IP $remote_addr;
  }
}
```

## 📈 监控和告警

### 1. 性能监控脚本
```ruby
# lib/performance_monitor.rb
class PerformanceMonitor
  def self.log_slow_queries
    threshold = 500  # 500ms阈值

    ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      duration = event.duration

      if duration > threshold
        Rails.logger.warn "慢查询检测: #{duration}ms - #{event.payload[:sql]}"
      end
    end
  end

  def self.log_memory_usage
    if defined?(GC)
      GC.stat.tap do |stats|
        Rails.logger.info "内存使用 - GC Count: #{stats[:count]}, Heap Size: #{stats[:heap_used_pages]}"
      end
    end
  end
end

# config/initializers/performance_monitor.rb
Rails.application.configure do
  # 启用慢查询监控
  PerformanceMonitor.log_slow_queries

  # 定期记录内存使用
  if Rails.env.production?
    Thread.new do
      loop do
        sleep(5.minutes)
        PerformanceMonitor.log_memory_usage
      end
    end
  end
end
```

### 2. 健康检查端点
```ruby
# app/controllers/api/health_controller.rb
class Api::HealthController < ActionController::Base
  def show
    health_data = {
      status: 'ok',
      timestamp: Time.current.iso8601,
      version: Rails.version,
      environment: Rails.env,
      database: check_database_connection,
      cache: check_cache_connection,
      performance: check_performance_metrics
    }

    render json: health_data
  rescue => e
    render json: {
      status: 'error',
      message: e.message,
      timestamp: Time.current.iso8601
    }, status: :service_unavailable
  end

  private

  def check_database_connection
    ActiveRecord::Base.connection.execute('SELECT 1')
    { status: 'connected', response_time: benchmark_database_query }
  rescue => e
    { status: 'error', message: e.message }
  end

  def check_cache_connection
    Rails.cache.write('health_check', 'ok', expires_in: 1.minute)
    { status: 'connected', response_time: benchmark_cache_query }
  rescue => e
    { status: 'error', message: e.message }
  end

  def check_performance_metrics
    {
      memory_usage: `ps -o pid,vsz,rss -p #{Process.pid}`.strip.split.last.to_i,
      cpu_usage: `ps -p #{Process.pid} -o %cpu`.strip.to_f,
      uptime: Time.current - Rails.application.config.booted_at
    }
  end

  def benchmark_database_query
    start_time = Time.current
    ActiveRecord::Base.connection.execute('SELECT 1')
    ((Time.current - start_time) * 1000).round(2)
  end

  def benchmark_cache_query
    start_time = Time.current
    Rails.cache.read('health_check')
    ((Time.current - start_time) * 1000).round(2)
  end
end
```

## 🔄 缓存管理

### 1. 缓存预热脚本
```ruby
# lib/cache_warmer.rb
class CacheWarmer
  def self.warmup
    Rails.logger.info "开始缓存预热..."

    # 预热热门帖子
    warm_popular_posts

    # 预热活动统计
    warm_event_stats

    # 预热用户统计
    warm_user_stats

    Rails.logger.info "缓存预热完成"
  end

  private

  def self.warm_popular_posts
    popular_posts = Post.visible.order(likes_count: :desc).limit(20)
    popular_posts.each do |post|
      QueryCacheService.fetch_post(post.id)
    end
  end

  def self.warm_event_stats
    active_events = ReadingEvent.where(status: :active).limit(10)
    active_events.each do |event|
      QueryCacheService.fetch_event_stats(event.id)
    end
  end

  def self.warm_user_stats
    active_users = User.where('created_at > ?', 30.days.ago).limit(50)
    active_users.each do |user|
      QueryCacheService.fetch_user_stats(user.id)
    end
  end
end
```

### 2. 缓存清理脚本
```ruby
# lib/cache_manager.rb
class CacheManager
  def self.clear_expired_caches
    # 清除过期的帖子缓存
    QueryCacheService.clear_cache('posts_list:*')

    # 清除过期的统计缓存
    QueryCacheService.clear_cache('posts_stats:*')

    Rails.logger.info "已清理过期缓存"
  end

  def self.clear_all_caches
    QueryCacheService.clear_cache
    Rails.cache.clear if Rails.cache.respond_to?(:clear)

    Rails.logger.info "已清理所有缓存"
  end

  def self.warmup_critical_caches
    # 重新预热关键缓存
    CacheWarmer.warmup
  end
end

# 配置定时任务（使用Sidekiq或类似工具）
# config/initializers/sidekiq.rb
Sidekiq.configure_server do |config|
  config.on(:startup) do
    # 启动时预热缓存
    CacheWarmer.warmup
  end
end

# lib/tasks/cache_tasks.rake
namespace :cache do
  desc "清理过期缓存"
  task clear_expired: :environment do
    CacheManager.clear_expired_caches
  end

  desc "清理所有缓存"
  task clear_all: :environment do
    CacheManager.clear_all_caches
  end

  desc "预热关键缓存"
  task warmup: :environment do
    CacheManager.warmup_critical_caches
  end
end
```

## 🔍 故障排查

### 1. 性能问题诊断
```bash
# 查看慢查询日志
tail -f log/production.log | grep "慢查询检测"

# 查看内存使用情况
ps aux | grep "rails\|unicorn\|puma"

# 查看Redis状态
redis-cli info memory
redis-cli info stats
```

### 2. 缓存问题诊断
```ruby
# 控制台中检查缓存状态
rails console

# 检查缓存命中率
Rails.cache.stats

# 手动清理缓存
Rails.cache.clear

# 检查特定缓存
Rails.cache.read('cache_key_here')
```

### 3. 数据库性能诊断
```sql
-- 查看慢查询
SELECT query, mean_time, calls, total_time
FROM pg_stat_statements
WHERE mean_time > 100
ORDER BY mean_time DESC
LIMIT 10;

-- 查看索引使用情况
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC
LIMIT 10;
```

## 📋 部署检查清单

### 部署前检查
- [ ] 数据库备份已完成
- [ ] Redis服务正常运行
- [ ] 环境变量配置正确
- [ ] SSL证书配置（如需要）
- [ ] 监控工具配置完成

### 部署后验证
- [ ] 数据库迁移成功
- [ ] 应用启动正常
- [ ] 新API接口可访问
- [ ] 缓存功能正常
- [ ] 性能指标达标
- [ ] 监控告警配置

### 性能基准验证
```bash
# 运行性能测试
rails test test/performance/posts_performance_test.rb

# 检查响应时间
curl -w "@curl-format.txt" -o /dev/null -s "http://your-domain.com/api/v1/performance_posts"

# curl-format.txt内容
%{time_connect}s connect time
%{time_starttransfer}s start transfer time
%{time_total}s total time
%{http_code} response code
```

## 🎯 性能目标

### 关键指标
- **API响应时间**: 95%的请求 < 500ms
- **数据库查询**: 每个请求 < 5次查询
- **缓存命中率**: > 80%
- **系统可用性**: > 99.9%
- **并发处理**: 支持100+并发用户

### 监控告警
- **响应时间告警**: > 1秒
- **错误率告警**: > 5%
- **内存使用告警**: > 80%
- **数据库连接告警**: 连接池满载

---

*本指南提供了完整的性能优化部署流程，确保系统能够在生产环境中稳定运行并提供优异的性能表现。*