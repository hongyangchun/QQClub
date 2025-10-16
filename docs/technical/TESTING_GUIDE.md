# QQClub 测试指南

本指南详细介绍 QQClub 项目的测试策略、工具使用和最佳实践，确保代码质量和系统稳定性。

## 📋 目录

1. [测试策略概览](#测试策略概览)
2. [测试工具介绍](#测试工具介绍)
3. [测试环境设置](#测试环境设置)
4. [测试类型详解](#测试类型详解)
5. [API测试指南](#api测试指南)
6. [性能测试](#性能测试)
7. [权限测试](#权限测试)
8. [测试数据管理](#测试数据管理)
9. [故障排除](#故障排除)
10. [最佳实践](#最佳实践)

## 测试策略概览

QQClub 采用多层测试策略，确保系统各个层面的质量：

```
测试金字塔
    ┌─────────────────┐
    │   E2E 测试      │  ← 少量、关键业务流程
    └─────────────────┘
    ┌─────────────────┐
    │  集成测试       │  ← 中等数量、组件交互
    └─────────────────┘
    ┌─────────────────┐
    │   单元测试       │  ← 大量、快速反馈
    └─────────────────┘
```

### 测试覆盖率目标
- **单元测试**: 90%+
- **集成测试**: 80%+
- **API测试**: 100%
- **权限测试**: 100%

## 测试工具介绍

### 1. qq-test.sh - 统一测试入口点 🎯
项目的主要测试执行工具，提供完整的测试功能：

```bash
# 基本用法 - 统一入口点
./scripts/qq-test.sh                    # 运行所有测试 (默认)
./scripts/qq-test.sh unit              # 仅运行单元测试
./scripts/qq-test.sh integration       # 集成测试
./scripts/qq-test.sh models            # 模型测试
./scripts/qq-test.sh controllers       # 控制器测试
./scripts/qq-test.sh api               # API集成测试
./scripts/qq-test.sh permissions       # 权限系统测试
./scripts/qq-test.sh coverage          # 覆盖率测试

# 高级选项
./scripts/qq-test.sh all --coverage --performance  # 完整测试
./scripts/qq-test.sh models --verbose              # 详细模型测试
./scripts/qq-test.sh --api-url https://api.qqclub.com  # 测试生产环境
./scripts/qq-test.sh --help                        # 查看帮助信息
```

**主要功能**:
- ✅ **统一入口点**: 所有测试通过单一命令访问
- ✅ **参数化控制**: 灵活的测试类型和选项控制
- ✅ **环境检查**: 自动Ruby版本、数据库连接、依赖验证
- ✅ **测试隔离**: DatabaseCleaner确保测试数据独立
- ✅ **覆盖率报告**: SimpleCov集成，生成详细覆盖率报告
- ✅ **并行执行**: 支持并行测试提高执行效率
- ✅ **详细报告**: 结构化的测试结果和问题清单

### 1.1 测试结果示例
```bash
🧪 QQClub Test - 项目测试执行工具
==================================================
项目根目录: /Users/hongyangchun/Codebase/QQClub
API根目录: /Users/hongyangchun/Codebase/QQClub/qqclub_api
测试类型: models

[STEP] 检查测试环境...
[INFO] Ruby 版本: ruby 3.3.0
[SUCCESS] 数据库连接正常

[STEP] 运行模型测试...
Running 106 tests in parallel using 8 processes

✅ User模型测试: 25 tests, 96 assertions, 0 failures
✅ Post模型测试: 41 tests, 120 assertions, 3 failures
⚠️  ReadingEvent模型测试: 40 tests, 85 assertions, 11 errors

==================================
🧪 测试统计
==================================
总测试数: 106
通过测试: 95
失败测试: 3
错误测试: 8
成功率: 89.6%
==================================
```

### 1.2 测试类型说明
- **models**: 模型测试 - 核心业务逻辑验证
- **api**: API功能测试 - 端到端功能验证
- **permissions**: 权限系统测试 - 3层权限架构验证
- **controllers**: 控制器测试 - 详细的API端点测试
- **all**: 完整测试 - 运行所有核心测试类型

### 1.3 测试使用建议
- **日常开发**: 使用 `models` 和 `api` 进行快速验证
- **安全检查**: 定期运行 `permissions` 确保权限系统正常
- **完整回归**: 使用 `all` 进行全面的回归测试
- **问题调试**: 使用 `controllers` 进行详细的控制器测试

### 2. api_test_framework.rb - API测试框架
专业的API端点测试工具：

```bash
# 运行完整API测试套件
./scripts/api_test_framework.rb

# 测试单个端点
./scripts/api_test_framework.rb -e /api/posts -m POST -d '{"post":{"title":"测试"}}'
```

**主要功能**:
- 完整的API端点覆盖
- 自动用户认证
- 错误处理测试
- 性能指标收集
- 详细测试报告

### 3. test_data_manager.rb - 测试数据管理
测试数据的创建、管理和清理：

```bash
# 创建完整测试数据集
./scripts/test_data_manager.rb --create

# 清理测试数据
./scripts/test_data_manager.rb --cleanup

# 查看数据统计
./scripts/test_data_manager.rb --stats
```

**主要功能**:
- 自动创建测试用户
- 测试活动生成
- 数据关系维护
- 清理和重置功能

### 4. test_debugger.rb - 测试调试工具
测试环境诊断和问题解决：

```bash
# 运行完整诊断
./scripts/test_debugger.rb

# 自动修复问题
./scripts/test_debugger.rb --fix
```

**主要功能**:
- 环境配置检查
- 依赖项验证
- 权限系统诊断
- 自动问题修复

## 测试环境设置

### 1. 基础环境要求

```bash
# Ruby环境
ruby --version  # 3.3.0+

# Rails环境
cd qqclub_api
bundle exec rails --version  # 8.0.0+

# 数据库
bundle exec rails db:migrate
bundle exec rails db:test:prepare
```

### 2. 环境变量配置

```bash
# config/environments/test.rb
Rails.application.configure do
  # 测试数据库配置
  config.database_url = 'sqlite3:db/test.sqlite3'

  # 缓存配置
  config.cache_store = :null_store

  # 邮件配置
  config.action_mailer.delivery_method = :test
  config.action_mailer.perform_deliveries = false

  # 日志配置
  config.log_level = :debug
  config.active_support.deprecation = :log
end
```

### 3. 测试配置文件

```yaml
# .test.yml (可选)
test:
  parallel_workers: 4
  coverage_minimum: 80
  timeout_seconds: 300
  retry_count: 3
```

## 测试类型详解

### 1. 单元测试 (Unit Tests)

#### 模型测试
```ruby
# test/models/user_test.rb
class UserTest < ActiveSupport::TestCase
  test "should validate user attributes" do
    user = User.new
    assert_not user.valid?

    user.wx_openid = "test_openid"
    user.nickname = "测试用户"
    assert user.valid?
  end

  test "should generate JWT token" do
    user = users(:one)
    token = user.generate_jwt_token
    assert_not_nil token
  end

  test "should check admin permissions" do
    admin = users(:admin)
    assert admin.any_admin?
    assert_not admin.root?
  end
end
```

#### Service Object测试
```ruby
# test/services/event_creation_service_test.rb
class EventCreationServiceTest < ActiveSupport::TestCase
  test "should create event with valid data" do
    user = users(:regular)
    service = EventCreationService.new(user, valid_event_params)

    result = service.create
    assert result.success?
    assert_not_nil result.event
  end

  test "should handle invalid data" do
    user = users(:regular)
    service = EventCreationService.new(user, invalid_event_params)

    result = service.create
    assert_not result.success?
    assert result.errors.any?
  end
end
```

### 2. 集成测试 (Integration Tests)

#### 控制器测试
```ruby
# test/controllers/api/posts_controller_test.rb
class Api::PostsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:regular)
    @token = @user.generate_jwt_token
  end

  test "should create post with valid data" do
    post api_posts_path, params: {
      post: {
        title: "测试帖子",
        content: "这是一个测试帖子内容，确保长度满足要求。"
      }
    }, headers: {
      'Authorization' => "Bearer #{@token}"
    }

    assert_response :created
    assert json_response['id']
    assert_equal "测试帖子", json_response['title']
  end

  test "should require authentication" do
    post api_posts_path, params: {
      post: { title: "未授权帖子", content: "内容" }
    }

    assert_response :unauthorized
  end
end
```

#### 系统集成测试
```ruby
# test/integration/complete_event_flow_test.rb
class CompleteEventFlowTest < ActionDispatch::IntegrationTest
  test "complete event workflow" do
    # 1. 创建活动
    create_event_as_leader
    event_id = json_response['id']

    # 2. 管理员审批
    approve_event_as_admin(event_id)

    # 3. 用户报名
    enroll_in_event(event_id)

    # 4. 创建阅读计划
    create_reading_schedule(event_id)

    # 5. 用户打卡
    check_in_to_schedule(event_id)

    # 6. 验证流程完整性
    assert Event.find(event_id).enrollments.any?
    assert CheckIn.any?
  end
end
```

### 3. API测试

#### 使用API测试框架
```bash
# 运行完整API测试
./scripts/api_test_framework.rb

# 自定义API测试
./scripts/api_test_framework.rb \
  -e /api/posts \
  -m POST \
  -d '{"post":{"title":"自定义测试","content":"测试内容"}}' \
  -t "$USER_TOKEN"
```

#### 手动API测试
```bash
# 认证测试
TOKEN=$(curl -s -X POST http://localhost:3000/api/auth/mock_login \
  -H "Content-Type: application/json" \
  -d '{"user":{"nickname":"API测试用户","wx_openid":"api_test_001"}}' | jq -r '.token')

# 创建帖子
curl -X POST http://localhost:3000/api/posts \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"post":{"title":"手动测试帖子","content":"手动创建的测试帖子内容"}}'

# 获取帖子列表
curl -X GET http://localhost:3000/api/posts \
  -H "Authorization: Bearer $TOKEN"
```

### 4. 性能测试

#### 响应时间测试
```bash
# 内置性能测试
./scripts/qq-test.sh --performance

# 自定义性能测试
ab -n 100 -c 10 http://localhost:3000/api/posts
```

#### 负载测试
```ruby
# test/performance/load_test.rb
class LoadTest
  def self.run_concurrent_requests(endpoint, concurrent_users, total_requests)
    threads = []
    results = []
    mutex = Mutex.new

    concurrent_users.times do
      threads << Thread.new do
        (total_requests / concurrent_users).times do
          start_time = Time.now
          response = Net::HTTP.get_response(URI(endpoint))
          end_time = Time.now

          mutex.synchronize do
            results << end_time - start_time
          end
        end
      end
    end

    threads.each(&:join)
    results
  end
end
```

### 5. 权限测试

#### 使用权限检查工具
```bash
# 完整权限测试
./scripts/qq-permissions.sh

# 权限架构测试
./scripts/qq-permissions.sh --check-architecture

# 角色权限测试
./scripts/qq-permissions.sh --check-roles
```

#### 手动权限测试
```ruby
# test/integration/permission_boundary_test.rb
class PermissionBoundaryTest < ActionDispatch::IntegrationTest
  test "regular user cannot access admin panel" do
    user = users(:regular)
    token = user.generate_jwt_token

    get api_admin_dashboard_path, headers: {
      'Authorization' => "Bearer #{token}"
    }

    assert_response :forbidden
  end

  test "admin can manage posts" do
    admin = users(:admin)
    token = admin.generate_jwt_token

    # 创建帖子
    post api_posts_path, params: {
      post: { title: "管理员帖子", content: "内容" }
    }, headers: {
      'Authorization' => "Bearer #{token}"
    }
    post_id = json_response['id']

    # 置顶帖子
    post pin_api_post_path(post_id), headers: {
      'Authorization' => "Bearer #{token}"
    }

    assert_response :success
  end
end
```

## API测试指南

### 1. 认证测试

#### 用户注册和登录
```bash
# 测试模拟登录
curl -X POST http://localhost:3000/api/auth/mock_login \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "nickname": "认证测试用户",
      "wx_openid": "auth_test_001"
    }
  }'
```

#### Token验证
```bash
# 获取用户信息
TOKEN="your_jwt_token_here"
curl -X GET http://localhost:3000/api/auth/me \
  -H "Authorization: Bearer $TOKEN"

# 更新用户资料
curl -X PUT http://localhost:3000/api/auth/profile \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "nickname": "更新后的昵称",
      "avatar_url": "https://example.com/avatar.jpg"
    }
  }'
```

### 2. 论坛功能测试

#### 帖子管理
```bash
# 创建帖子
curl -X POST http://localhost:3000/api/posts \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "post": {
      "title": "API测试帖子",
      "content": "这是一个通过API创建的测试帖子，确保内容长度满足系统要求。帖子应该包含足够的信息来验证功能的完整性。"
    }
  }'

# 获取帖子列表
curl -X GET http://localhost:3000/api/posts \
  -H "Authorization: Bearer $TOKEN"

# 获取帖子详情
POST_ID=1
curl -X GET http://localhost:3000/api/posts/$POST_ID \
  -H "Authorization: Bearer $TOKEN"

# 更新帖子
curl -X PUT http://localhost:3000/api/posts/$POST_ID \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "post": {
      "title": "更新后的标题"
    }
  }'

# 删除帖子
curl -X DELETE http://localhost:3000/api/posts/$POST_ID \
  -H "Authorization: Bearer $TOKEN"
```

#### 帖子管理功能
```bash
# 置顶帖子
curl -X POST http://localhost:3000/api/posts/$POST_ID/pin \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 取消置顶
curl -X POST http://localhost:3000/api/posts/$POST_ID/unpin \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 隐藏帖子
curl -X POST http://localhost:3000/api/posts/$POST_ID/hide \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 显示帖子
curl -X POST http://localhost:3000/api/posts/$POST_ID/unhide \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

### 3. 活动管理测试

#### 活动CRUD操作
```bash
# 创建活动
curl -X POST http://localhost:3000/api/events \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "event": {
      "title": "API测试读书活动",
      "book_name": "测试书籍",
      "description": "这是一个通过API创建的测试读书活动",
      "start_date": "2025-10-20",
      "end_date": "2025-10-27",
      "max_participants": 20,
      "enrollment_fee": 100.00
    }
  }'

# 获取活动列表
curl -X GET http://localhost:3000/api/events \
  -H "Authorization: Bearer $TOKEN"

# 获取活动详情
EVENT_ID=1
curl -X GET http://localhost:3000/api/events/$EVENT_ID \
  -H "Authorization: Bearer $TOKEN"

# 更新活动
curl -X PUT http://localhost:3000/api/events/$EVENT_ID \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "event": {
      "description": "更新后的活动描述"
    }
  }'

# 删除活动
curl -X DELETE http://localhost:3000/api/events/$EVENT_ID \
  -H "Authorization: Bearer $TOKEN"
```

#### 活动报名流程
```bash
# 报名活动
curl -X POST http://localhost:3000/api/events/$EVENT_ID/enroll \
  -H "Authorization: Bearer $TOKEN"

# 检查报名状态
curl -X GET http://localhost:3000/api/events/$EVENT_ID/participants \
  -H "Authorization: Bearer $TOKEN"
```

## 性能测试

### 1. 响应时间基准

#### API端点响应时间要求
- 健康检查: < 100ms
- 认证端点: < 200ms
- 数据查询: < 500ms
- 数据创建: < 300ms

#### 性能测试脚本
```bash
#!/bin/bash
# performance_test.sh

API_URL="http://localhost:3000"
ENDPOINTS=(
  "/api/health"
  "/api/auth/me"
  "/api/posts"
  "/api/events"
)

echo "性能测试开始..."

for endpoint in "${ENDPOINTS[@]}"; do
  echo "测试: $endpoint"

  # 预热
  curl -s "$API_URL$endpoint" > /dev/null

  # 实际测试
  start_time=$(date +%s.%N)
  response=$(curl -s "$API_URL$endpoint")
  end_time=$(date +%s.%N)

  duration=$(echo "$end_time - $start_time" | bc)

  if (( $(echo "$duration < 0.5" | bc -l) )); then
    echo "  ✅ $duration 秒 (< 500ms)"
  else
    echo "  ❌ $duration 秒 (>= 500ms)"
  fi
done

echo "性能测试完成"
```

### 2. 并发测试

#### 并发用户测试
```bash
#!/bin/bash
# concurrent_test.sh

API_URL="http://localhost:3000/api/posts"
CONCURRENT_USERS=10
REQUESTS_PER_USER=10

echo "并发测试: $CONCURRENT_USERS 用户, 每用户 $REQUESTS_PER_USER 请求"

# 创建测试函数
test_user() {
  local user_id=$1
  local token=$(curl -s -X POST "$API_URL/../api/auth/mock_login" \
    -H "Content-Type: application/json" \
    -d "{\"user\":{\"nickname\":\"用户$user_id\",\"wx_openid\":\"test_user_$user_id\"}}" | jq -r '.token')

  for ((i=1; i<=REQUESTS_PER_USER; i++)); do
    curl -s "$API_URL" -H "Authorization: Bearer $token" > /dev/null
  done
}

# 启动并发测试
for ((i=1; i<=CONCURRENT_USERS; i++)); do
  test_user $i &
done

# 等待所有测试完成
wait

echo "并发测试完成"
```

## 权限测试

### 1. 角色权限矩阵

| 权限类型 | Root | Admin | Group Leader | Daily Leader | User |
|---------|------|-------|--------------|--------------|------|
| 系统管理 | ✅ | 部分 | ❌ | ❌ | ❌ |
| 用户管理 | ✅ | 有限 | ❌ | ❌ | ❌ |
| 活动审批 | ✅ | ✅ | ❌ | ❌ | ❌ |
| 活动管理 | ✅ | ✅ | 自己的 | ❌ | ❌ |
| 领读内容 | ✅ | ✅ | 全程 | 时间窗口 | ❌ |
| 论坛管理 | ✅ | ✅ | ❌ | ❌ | 自己的 |
| 小红花评选 | ✅ | ✅ | 全程 | 时间窗口 | ❌ |

### 2. 权限边界测试

#### 权限越界测试
```bash
# 测试普通用户访问管理员功能
USER_TOKEN=$(get_user_token "regular")

curl -X GET http://localhost:3000/api/admin/dashboard \
  -H "Authorization: Bearer $USER_TOKEN"  # 应该返回403

# 测试用户编辑他人帖子
OTHER_USER_TOKEN=$(get_user_token "other_user")
curl -X PUT http://localhost:3000/api/posts/1 \
  -H "Authorization: Bearer $USER_TOKEN"  # 应该返回403
```

#### 时间窗口权限测试
```ruby
# test/models/user_time_window_test.rb
class UserTimeWindowTest < ActiveSupport::TestCase
  test "daily leader has permission within time window" do
    leader = users(:daily_leader)
    event = reading_events(:active)

    # 昨天的计划
    yesterday_schedule = event.reading_schedules.where(date: Date.yesterday).first
    assert leader.can_manage_event_content?(event, yesterday_schedule)

    # 今天的计划
    today_schedule = event.reading_schedules.where(date: Date.today).first
    assert leader.can_manage_event_content?(event, today_schedule)

    # 明天的计划
    tomorrow_schedule = event.reading_schedules.where(date: Date.tomorrow).first
    assert leader.can_manage_event_content?(event, tomorrow_schedule)

    # 超出时间窗口
    old_schedule = event.reading_schedules.where(date: Date.today - 2).first
    assert_not leader.can_manage_event_content?(event, old_schedule)
  end
end
```

## 测试数据管理

### 1. 测试数据策略

#### 数据隔离
- 每个测试使用独立的数据
- 测试之间不共享状态
- 测试后自动清理

#### 数据一致性
- 使用Factory Bot创建测试数据
- 保持数据的真实性和完整性
- 满足业务规则要求

### 2. 测试数据创建

#### 使用Factory Bot
```ruby
# test/factories/users.rb
FactoryBot.define do
  factory :user do
    wx_openid { "test_openid_#{SecureRandom.hex(8)}" }
    nickname { "测试用户_#{SecureRandom.hex(4)}" }
    role { :user }
  end

  factory :admin do
    role { :admin }
  end

  factory :root do
    role { :root }
  end
end
```

#### 使用Fixtures
```yaml
# test/fixtures/users.yml
root:
  wx_openid: root_test_001
  nickname: Root测试用户
  role: 0

admin:
  wx_openid: admin_test_001
  nickname: Admin测试用户
  role: 1

user:
  wx_openid: user_test_001
  nickname: 普通测试用户
  role: 0
```

### 3. 测试数据清理

#### 自动清理机制
```ruby
# test/test_helper.rb
class ActiveSupport::TestCase
  setup do
    # 清理数据库
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.start
  end

  teardown do
    DatabaseCleaner.clean
  end
end
```

#### 手动清理工具
```bash
# 清理测试数据
./scripts/test_data_manager.rb --cleanup

# 重新创建测试数据
./scripts/test_data_manager.rb --create
```

## 故障排除

### 1. 常见测试问题

#### 测试环境问题
```bash
# 检查Rails环境
cd qqclub_api
bundle exec rails runner "puts Rails.env"
bundle exec rails runner "puts ActiveRecord::Base.connection.adapter_name"

# 检查数据库状态
bundle exec rails db:migrate:status
bundle exec rails db:test:prepare

# 重置测试数据库
bundle exec rails db:test:reset
```

#### 依赖问题
```bash
# 检查Bundle状态
bundle check

# 重新安装依赖
bundle clean --force
bundle install

# 更新依赖
bundle update
```

#### 认证问题
```bash
# 检查JWT密钥
bundle exec rails runner "puts Rails.application.credentials.jwt_secret_key"

# 测试Token生成
bundle exec rails runner "
  user = User.first
  puts user.generate_jwt_token
"
```

### 2. 调试技巧

#### 启用详细日志
```ruby
# config/environments/test.rb
Rails.application.configure do
  config.log_level = :debug

  # 输出到控制台
  config.logger = Logger.new(STDOUT)
end
```

#### 使用调试工具
```ruby
# 在测试中添加调试输出
test "debug example" do
  puts "Current user: #{current_user.inspect}"
  puts "Response: #{response.inspect}"

  # 使用byebug进行断点调试
  # byebug if response.status == 500
end
```

#### SQL查询调试
```ruby
# 在测试中启用SQL日志
ActiveRecord::Base.logger = Logger.new(STDOUT)

test "with sql logging" do
  # 所有SQL查询都会输出到控制台
  posts = Post.all
  assert posts.any?
end
```

### 3. 性能问题诊断

#### 查询优化
```bash
# 查找N+1查询
bundle exec rails log:find_n_plus_one

# 生成查询计划
bundle exec rails runner "
  posts = Post.includes(:user).limit(10)
  puts posts.to_sql
"
```

#### 内存使用监控
```bash
# 监控内存使用
bundle exec rails runner "
  puts '内存使用:', `ps -o rss= -p #{Process.pid}`.to_i
"
```

## 最佳实践

### 1. 测试编写原则

#### AAA原则
- **Arrange**: 设置测试数据和状态
- **Act**: 执行被测试的操作
- **Assert**: 验证结果是否符合预期

#### 单一职责
- 每个测试只验证一个功能点
- 测试名称应该清晰描述测试目的
- 避免复杂的测试逻辑

#### 可读性
- 使用描述性的测试名称
- 添加必要的注释说明
- 保持测试代码简洁明了

### 2. 测试组织

#### 目录结构
```
test/
├── fixtures/          # 静态测试数据
├── factories/          # 动态数据生成
├── support/           # 测试辅助工具
├── models/           # 模型测试
├── controllers/      # 控制器测试
├── integration/      # 集成测试
├── system/           # 系统测试
└── performance/      # 性能测试
```

#### 命名规范
```ruby
# 好的测试名称
test "should validate user with valid attributes"
test "should reject login with invalid credentials"
test "should create post with valid data"

# 避免的测试名称
test "test user"
test "post test"
test "check something"
```

### 3. 持续集成

#### 自动化测试
```yaml
# .github/workflows/test.yml
name: Run Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v2

    - name: Setup Ruby
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: '3.3'

    - name: Install dependencies
      run: |
        cd qqclub_api
        bundle install

    - name: Run tests
      run: |
        cd qqclub_api
        bundle exec rails test

    - name: Run API tests
      run: |
        ./scripts/qq-test.sh api
```

#### 测试报告
```yaml
# 测试覆盖率报告
coverage:
  enabled: true
  minimum_coverage: 80

# 测试报告格式
formatters:
  - progress
  - documentation
  - html
```

### 4. 测试维护

#### 定期审查
- 定期检查测试覆盖率
- 更新过时的测试用例
- 重构复杂的测试逻辑
- 添加缺失的测试用例

#### 测试文档
- 记录测试策略和规范
- 维护测试用例说明
- 更新故障排除指南

---

## 总结

QQClub 的测试体系采用多层策略，结合自动化工具和手动测试，确保系统的质量和稳定性。通过遵循最佳实践和使用提供的测试工具，可以有效地发现和预防问题，提升代码质量和用户体验。

**关键要点**:
1. 保持高测试覆盖率（90%+）
2. 定期运行权限检查
3. 关注性能测试结果
4. 及时更新测试用例
5. 保持测试数据的独立性

通过本指南和相应的测试工具，开发团队可以构建和维护高质量的 QQClub 应用程序。