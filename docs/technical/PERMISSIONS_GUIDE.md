# QQClub 权限系统指南

本指南详细介绍 QQClub 项目的 3 层权限体系，包括设计原理、实现方法、测试工具和最佳实践。

## 📋 目录

1. [权限架构概览](#权限架构概览)
2. [角色定义](#角色定义)
3. [权限实现](#权限实现)
4. [权限检查工具](#权限检查工具)
5. [测试用例](#测试用例)
6. [安全最佳实践](#安全最佳实践)
7. [故障排除](#故障排除)

## 权限架构概览

QQClub 采用 3 层权限架构，确保系统安全性和灵活性：

```
Admin Level (管理员级别)
├── Root (超级管理员) - 系统开发者
├── Admin (管理员) - 社区管理者
│   ├── 系统管理权限
│   ├── 用户管理权限
│   └── 内容审核权限
│
Event Level (活动级别)
├── Group Leader (小组长) - 活动创建者
├── Daily Leader (领读人) - 每日活动负责人
│   ├── 领读内容管理权限
│   ├── 打卡内容管理权限
│   └── 小红花评选权限
│
User Level (用户级别)
├── Forum User (论坛用户) - 基础权限
├── Participant (活动参与者) - 报名用户
│   ├── 论坛发帖评论权限
│   ├── 活动报名权限
│   └── 个人打卡权限
```

## 角色定义

### Admin Level

#### Root (超级管理员)
- **权限范围**: 系统最高权限
- **主要职责**:
  - 系统配置管理
  - 创建和管理管理员账户
  - 系统级安全设置
- **特殊权限**:
  - 可以创建其他 Root 用户
  - 可以修改系统核心配置
  - 拥有所有数据的访问权限

#### Admin (管理员)
- **权限范围**: 社区日常管理
- **主要职责**:
  - 活动审批和管理
  - 论坛内容审核
  - 用户角色管理（除 Root 外）
  - 系统统计数据查看

### Event Level

#### Group Leader (小组长)
- **权限范围**: 自己创建的活动
- **主要职责**:
  - 活动创建和设置
  - 参与者管理
  - 阅读计划制定
  - 全程权限备份
- **权限特点**:
  - 自动获得活动全程管理权限
  - 可以作为 Daily Leader 的备份
  - 可以设置随机领读安排

#### Daily Leader (领读人)
- **权限范围**: 3 天时间窗口
- **权限窗口**:
  - **前一天**: 发布领读内容权限
  - **当天**: 管理打卡和互动权限
  - **后一天**: 评选小红花权限
- **权限特点**:
  - 基于时间的动态权限
  - 需要权限窗口验证
  - 支持备份机制

### User Level

#### Forum User (论坛用户)
- **权限范围**: 基础论坛功能
- **主要权限**:
  - 发布和编辑自己的帖子
  - 评论和互动
  - 查看公开内容

#### Participant (活动参与者)
- **权限范围**: 活动相关功能
- **主要权限**:
  - 报名参加活动
  - 提交个人打卡
  - 查看活动内容
  - 给他人送小红花

## 权限实现

### 1. 数据模型设计

#### User 模型角色枚举
```ruby
class User < ApplicationRecord
  enum :role, {
    user: 0,      # 普通用户 (Forum User + Participant)
    admin: 1,     # 管理员
    root: 2       # 超级管理员
  }

  # 管理员级别权限检查
  def any_admin?
    admin? || root?
  end

  def root?
    role == 'root'
  end

  def admin?
    role == 'admin'
  end

  # 活动权限检查
  def can_manage_event_content?(event, schedule)
    return true if any_admin?  # 管理员拥有所有权限
    return true if event.leader_id == id  # 小组长权限

    # 领读人权限检查（3天窗口）
    if schedule&.daily_leader_id == id
      permission_window = 1.day  # 可配置
      schedule_date = schedule.date

      return true if Date.current >= (schedule_date - permission_window)
      return true if Date.current <= (schedule_date + permission_window)
    end

    false
  end
end
```

### 2. 权限验证 Concern

#### AdminAuthorizable
```ruby
module AdminAuthorizable
  extend ActiveSupport::Concern

  # 管理员权限验证
  def authenticate_admin!
    return render json: { error: "需要管理员权限" }, status: :forbidden unless current_user&.any_admin?
  end

  # 超级管理员权限验证
  def authenticate_root!
    return render json: { error: "需要超级管理员权限" }, status: :forbidden unless current_user&.root?
  end

  # 活动管理权限验证
  def authenticate_event_leader!(event)
    unless current_user&.can_manage_event_content?(event, @schedule)
      render json: { error: "权限不足" }, status: :forbidden
    end
  end
end
```

### 3. 控制器权限保护

#### AdminController
```ruby
class AdminController < ApplicationController
  include AdminAuthorizable

  before_action :authenticate_admin!
  before_action :authenticate_root!, only: [:init_root_user]

  # 管理员面板
  def dashboard
    render json: {
      total_users: User.count,
      total_events: ReadingEvent.count,
      pending_events: ReadingEvent.where(approval_status: 'pending').count
    }
  end

  # 用户管理
  def users
    @users = User.all
    render json: @users
  end

  # 初始化 Root 用户
  def init_root_user
    # 实现逻辑...
  end
end
```

### 4. 路由权限保护

```ruby
Rails.application.routes.draw do
  namespace :api do
    # 管理员路由（需要权限验证）
    namespace :admin do
      get "dashboard", to: "admin#dashboard"
      get "users", to: "admin#users"
      post "init_root", to: "admin#init_root_user"
    end

    # 公开路由（需要用户认证）
    resources :posts do
      member do
        post :pin    # 需要管理员权限
        post :hide   # 需要管理员权限
      end
    end
  end
end
```

## 权限检查工具

### 1. qq-permissions.sh

完整权限检查脚本，提供全面的权限系统验证：

```bash
# 完整权限检查
./scripts/qq-permissions.sh

# 详细调试模式
./scripts/qq-permissions.sh --debug --verbose

# 仅检查架构
./scripts/qq-permissions.sh --check-architecture

# 检查生产环境
./scripts/qq-permissions.sh --api-url https://api.qqclub.com

# 生成详细报告
./scripts/qq-permissions.sh --report-file custom_report.md
```

**主要功能**:
- 权限架构验证
- 角色权限测试
- 时间窗口权限验证
- 安全性测试
- 备份机制测试
- 自动报告生成

### 2. permission_analyzer.rb

深度权限分析工具，提供静态代码分析：

```bash
# 运行完整分析
./scripts/permission_analyzer.rb

# 输出详细报告
./scripts/permission_analyzer.rb --output permissions_analysis.json

# 查看帮助
./scripts/permission_analyzer.rb --help
```

**主要功能**:
- 静态代码分析
- 权限矩阵生成
- 测试覆盖分析
- 数据库权限检查
- 改进建议生成

## 测试用例

### 1. 权限架构测试

```ruby
# test/models/user_test.rb
class UserTest < ActiveSupport::TestCase
  test "should validate admin permissions" do
    admin = users(:admin)
    assert admin.any_admin?
    assert_not admin.root?
  end

  test "should validate root permissions" do
    root = users(:root)
    assert root.any_admin?
    assert root.root?
  end

  test "should validate time window permissions" do
    leader = users(:daily_leader)
    event = reading_events(:active_event)
    schedule = event.reading_schedules.today.first

    # 测试权限窗口
    assert leader.can_manage_event_content?(event, schedule)
  end
end
```

### 2. 控制器权限测试

```ruby
# test/controllers/admin_controller_test.rb
class AdminControllerTest < ActionDispatch::IntegrationTest
  test "should require admin authentication" do
    get api_admin_dashboard_url
    assert_response :unauthorized
  end

  test "should allow admin access" do
    admin = users(:admin)
    token = admin.generate_jwt_token

    get api_admin_dashboard_url, headers: {
      'Authorization' => "Bearer #{token}"
    }
    assert_response :success
  end

  test "should deny user access to admin panel" do
    user = users(:regular)
    token = user.generate_jwt_token

    get api_admin_dashboard_url, headers: {
      'Authorization' => "Bearer #{token}"
    }
    assert_response :forbidden
  end
end
```

### 3. 集成测试

```ruby
# test/integration/permissions_test.rb
class PermissionsTest < ActionDispatch::IntegrationTest
  test "complete permission workflow" do
    # 创建测试用户
    user = create_user(:user)
    admin = create_user(:admin)

    # 测试用户权限
    user_token = user.generate_jwt_token
    assert_cannot_access_admin_panel(user_token)

    # 测试管理员权限
    admin_token = admin.generate_jwt_token
    assert_can_access_admin_panel(admin_token)
  end

  private

  def assert_cannot_access_admin_panel(token)
    get api_admin_dashboard_url, headers: {
      'Authorization' => "Bearer #{token}"
    }
    assert_response :forbidden
  end

  def assert_can_access_admin_panel(token)
    get api_admin_dashboard_url, headers: {
      'Authorization' => "Bearer #{token}"
    }
    assert_response :success
  end
end
```

## 安全最佳实践

### 1. 权限设计原则

#### 最小权限原则
- 每个角色只拥有完成任务所需的最低权限
- 避免过度授权
- 定期审查和调整权限

#### 职责分离
- 不同类型的权限分离管理
- 关键操作需要多重验证
- 避免权限集中

#### 可审计性
- 记录所有权限相关操作
- 提供权限变更日志
- 支持安全审计

### 2. 实现安全措施

#### Token 安全
```ruby
# JWT Token 安全配置
class User < ApplicationRecord
  def generate_jwt_token
    payload = {
      user_id: id,
      role: role,
      exp: 24.hours.from_now.to_i,  # 短期有效期
      iat: Time.current.to_i         # 签发时间
    }

    JWT.encode(payload, Rails.application.credentials.jwt_secret_key)
  end

  def self.decode_jwt_token(token)
    decoded = JWT.decode(
      token,
      Rails.application.credentials.jwt_secret_key,
      true,
      { algorithm: 'HS256' }
    )

    decoded.first
  rescue JWT::ExpiredSignature
    nil  # Token 过期
  rescue JWT::DecodeError
    nil  # Token 无效
  end
end
```

#### API 安全
```ruby
class ApplicationController < ActionController::API
  include Authenticable

  # 速率限制
  rate_limit = Rails.env.production? ? 100 : 1000

  before_action :check_rate_limit, unless: -> { Rails.env.test? }

  private

  def check_rate_limit
    client_ip = request.remote_ip
    key = "rate_limit:#{client_ip}"

    count = Rails.cache.increment(key, 1, expires_in: 1.hour)

    if count > rate_limit
      render json: { error: "请求过于频繁" }, status: :too_many_requests
    end
  end
end
```

#### 权限检查加强
```ruby
module AdminAuthorizable
  extend ActiveSupport::Concern

  private

  def authenticate_admin!
    unless current_user&.any_admin?
      log_security_attempt("admin_access_denied")
      render json: { error: "需要管理员权限" }, status: :forbidden
    end
  end

  def log_security_attempt(action)
    Rails.logger.warn "Security attempt: #{action} by user #{current_user&.id} from #{request.remote_ip}"

    # 可选：发送安全告警
    SecurityAlert.notify(action, current_user, request)
  end
end
```

### 3. 数据库安全

#### 敏感数据加密
```ruby
class User < ApplicationRecord
  # 加密敏感字段
  has_encrypted :phone, key: Rails.application.credentials.encryption_key

  # 审计日志
  has_many :audit_logs, as: :auditable
end
```

#### 权限相关索引
```ruby
# 优化权限查询性能
add_index :users, :role
add_index :users, :wx_openid, unique: true
add_index :reading_events, [:leader_id, :status]
add_index :reading_schedules, [:reading_event_id, :daily_leader_id]
```

## 故障排除

### 常见问题

#### 1. 权限检查失败

**问题**: 用户无法访问应有的资源

**排查步骤**:
```bash
# 1. 检查用户角色
rails console
> user = User.find_by(wx_openid: "test_user")
> user.role
> user.any_admin?

# 2. 检查权限方法
> user.can_manage_event_content?(event, schedule)

# 3. 运行权限检查工具
./scripts/qq-permissions.sh --debug --check-roles
```

**可能原因**:
- 用户角色设置错误
- 权限方法逻辑错误
- 时间窗口计算错误

#### 2. Token 认证问题

**问题**: JWT Token 验证失败

**排查步骤**:
```bash
# 1. 检查 Token 生成
rails console
> user = User.first
> token = user.generate_jwt_token
> decoded = User.decode_jwt_token(token)
> puts decoded

# 2. 检查 Token 过期
> exp = decoded['exp']
> Time.at(exp) > Time.current

# 3. 检查密钥配置
> Rails.application.credentials.jwt_secret_key
```

#### 3. 时间窗口权限问题

**问题**: 领读人权限异常

**排查步骤**:
```bash
# 1. 检查权限窗口计算
rails console
> leader = User.find_by(role: 'user')  # Daily Leader
> schedule = ReadingSchedule.find(date: Date.current)
> leader.can_manage_event_content?(schedule.reading_event, schedule)

# 2. 检查日期计算
> schedule_date = schedule.date
> permission_window = 1.day
> Date.current >= (schedule_date - permission_window)
> Date.current <= (schedule_date + permission_window)
```

### 调试技巧

#### 1. 启用详细日志
```ruby
# config/environments/development.rb
config.log_level = :debug
config.logger = Logger.new(STDOUT)
```

#### 2. 权限调试助手
```ruby
# app/controllers/concerns/debuggable_permissions.rb
module DebuggablePermissions
  extend ActiveSupport::Concern

  private

  def debug_permission_check(user, action, resource)
    return unless Rails.env.development?

    Rails.logger.debug "Permission Check:"
    Rails.logger.debug "  User: #{user.id} (#{user.role})"
    Rails.logger.debug "  Action: #{action}"
    Rails.logger.debug "  Resource: #{resource.class.name}##{resource.id}"
    Rails.logger.debug "  Result: #{yield}"
  end
end
```

#### 3. 权限可视化
```ruby
# lib/permission_visualizer.rb
class PermissionVisualizer
  def self.generate_matrix
    # 生成权限矩阵可视化
    # 用于权限文档和调试
  end
end
```

---

## 总结

QQClub 权限系统采用分层设计，确保安全性和灵活性的平衡。通过完善的权限检查工具和测试覆盖，可以保证权限系统的可靠性和安全性。

**关键要点**:
1. 严格遵循最小权限原则
2. 定期运行权限检查工具
3. 保持高测试覆盖率
4. 记录和审计权限操作
5. 及时修复权限相关问题

**工具使用**:
- 日常检查: `./scripts/qq-permissions.sh`
- 深度分析: `./scripts/permission_analyzer.rb`
- 调试模式: 添加 `--debug --verbose` 参数

通过遵循本指南和定期使用权限检查工具，可以确保 QQClub 项目的权限系统始终安全、可靠、高效运行。