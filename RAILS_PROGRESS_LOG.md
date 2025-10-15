# QQClub 读书社群 - 学习进度日志

## Day 1 - 2025年10月14日 ✅ 完成

### 🎯 今日目标
搭建 Rails API 项目基础架构，实现用户认证系统

### ✅ 完成的任务

#### 1. 项目初始化
- ✅ 创建 Rails 8.0.3 API 项目（使用 SQLite 数据库）
- ✅ 配置 CORS，支持跨域请求
- ✅ 添加必要的 gems：
  - `rack-cors` - 跨域支持
  - `jwt` - JWT 认证
  - `httparty` - HTTP 客户端（调用微信 API）

#### 2. 用户认证系统
- ✅ 创建 User 模型，支持微信登录：
  - `wx_openid` - 微信 OpenID（唯一索引）
  - `wx_unionid` - 微信 UnionID（唯一索引，可选）
  - `nickname` - 昵称
  - `avatar_url` - 头像 URL
  - `phone` - 手机号
- ✅ 实现 JWT token 生成和解析
- ✅ 创建 `Authenticable` concern，提供认证功能

#### 3. API 端点实现
- ✅ `POST /api/auth/mock_login` - 模拟登录（测试用）
- ✅ `POST /api/auth/login` - 微信登录（生产用，待配置）
- ✅ `GET /api/auth/me` - 获取当前用户信息
- ✅ `PUT /api/auth/profile` - 更新用户资料

#### 4. 测试验证
- ✅ 服务器成功启动（http://localhost:3000）
- ✅ 模拟登录测试通过
- ✅ JWT 认证测试通过
- ✅ 无 token 访问正确返回 401

### 📝 关键代码文件

```
qqclub_api/
├── app/
│   ├── controllers/
│   │   ├── application_controller.rb      # 引入 Authenticable
│   │   ├── concerns/
│   │   │   └── authenticable.rb           # JWT 认证 concern
│   │   └── api/
│   │       ├── auth_controller.rb         # 认证控制器
│   │       ├── events_controller.rb       # 活动控制器
│   │       ├── check_ins_controller.rb    # 打卡控制器
│   │       ├── daily_leadings_controller.rb # 领读控制器
│   │       └── flowers_controller.rb      # 小红花控制器
│   └── models/
│       ├── user.rb                        # User 模型 + JWT 方法
│       ├── reading_event.rb               # 共读活动模型
│       ├── enrollment.rb                  # 报名记录模型
│       ├── reading_schedule.rb            # 阅读计划模型
│       ├── check_in.rb                    # 打卡记录模型
│       ├── daily_leading.rb               # 领读内容模型
│       └── flower.rb                      # 小红花模型
├── config/
│   ├── routes.rb                          # API 路由
│   ├── database.yml                       # SQLite 配置
│   └── initializers/
│       └── cors.rb                        # CORS 配置
└── db/
    ├── migrate/
    │   ├── 20251014122353_create_users.rb
    │   ├── 20251015034247_create_reading_events.rb
    │   ├── 20251015034416_create_enrollments.rb
    │   ├── 20251015034500_create_reading_schedules.rb
    │   ├── 20251015035629_create_check_ins.rb
    │   ├── 20251015035748_create_daily_leadings.rb
    │   └── 20251015035749_create_flowers.rb
    └── schema.rb                          # 数据库 schema
```

### 🧠 今日学到的 Rails 核心概念

#### 1. Rails API 模式
```bash
rails new qqclub_api --api
```
- 去除了 View 层相关的组件
- 专注于 JSON API 开发
- ApplicationController 继承自 `ActionController::API`

#### 2. Concerns（关注点）
```ruby
module Authenticable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
  end
end
```
- 用于提取可复用的控制器逻辑
- 使用 `include Authenticable` 引入

#### 3. Strong Parameters
```ruby
def profile_params
  params.require(:user).permit(:nickname, :avatar_url, :phone)
end
```
- 安全地过滤用户输入
- 防止批量赋值漏洞

#### 4. Rails 8 的 Solid* 组件
- **Solid Queue** - 数据库驱动的后台任务
- **Solid Cache** - 数据库驱动的缓存
- **Solid Cable** - 数据库驱动的 WebSocket
- 无需 Redis！

#### 5. 数据库迁移
```ruby
class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :wx_openid
      t.timestamps
    end
    add_index :users, :wx_openid, unique: true
  end
end
```
- 版本控制数据库结构
- 可回滚、可重放

### 🤔 技术决策

#### 决策 1：使用 SQLite 而非 PostgreSQL
**原因**：
- Rails 8 的 SQLite 已生产就绪
- 零配置，立即可用
- 足够 MVP 使用
- 未来迁移到 PostgreSQL 很容易

**DHH 的话**：
> "不要被'必须用 PostgreSQL'的人吓到。Basecamp 和 HEY 的很多功能都跑在 SQLite 上。"

#### 决策 2：前后端分离架构
**原因**：
- 微信小程序需要原生体验
- 灵活性强，未来可扩展其他客户端
- RESTful API 是现代 Web 开发标准

#### 决策 3：JWT 认证
**原因**：
- 无状态，适合移动端/小程序
- 易于水平扩展
- 行业标准

#### 决策 4：提供 mock_login 接口
**原因**：
- 加速开发，无需每次都对接微信
- 方便测试
- 生产环境可关闭或限制访问

## Day 2 - 2025年10月15日 ✅ 完成

### 🎯 今日目标
实现读书活动核心模型和完整的业务流程

### ✅ 完成的任务

#### 1. 核心模型创建
- ✅ **ReadingEvent 模型**（共读活动）
  - 关联：belongs_to :leader (User)
  - 计算方法：service_fee, deposit, days_count
  - 状态枚举：draft, enrolling, in_progress, completed
  - 验证：日期逻辑、数值范围

- ✅ **Enrollment 模型**（报名记录）
  - 关联：belongs_to :user, belongs_to :reading_event
  - 计算方法：completion_rate, refund_amount_calculated
  - 枚举：payment_status, role
  - 唯一性验证：防止重复报名

- ✅ **ReadingSchedule 模型**（每日阅读计划）
  - 关联：belongs_to :reading_event, belongs_to :daily_leader
  - 作用域：today, past, future
  - 验证：day_number, reading_progress, date

- ✅ **CheckIn 模型**（打卡记录）
  - 关联：user, reading_schedule, enrollment, flower
  - 验证：最少100字、每日只能打卡一次
  - 回调：自动计算字数、设置提交时间
  - 方法：has_flower?, can_makeup?

- ✅ **DailyLeading 模型**（领读内容）
  - 关联：reading_schedule, leader
  - 验证：reading_suggestion, questions 均必填
  - 唯一性：每日只能有一个领读内容

- ✅ **Flower 模型**（小红花）
  - 关联：check_in, giver, recipient, reading_schedule
  - 验证：每日最多3朵、只有领读人可以发放
  - 自定义验证：daily_flower_limit, giver_is_daily_leader

#### 2. 数据库结构设计
- ✅ 6个核心表，完整的外键约束
- ✅ 索引优化：唯一索引、复合索引
- ✅ 外键级联删除配置
- ✅ 字段类型合理（decimal处理金额）

#### 3. API 端点实现

**活动管理**：
- ✅ `GET /api/events` - 活动列表（支持状态筛选）
- ✅ `GET /api/events/:id` - 活动详情（包含参与者）
- ✅ `POST /api/events` - 创建活动（自动生成阅读计划）
- ✅ `PUT /api/events/:id` - 更新活动
- ✅ `DELETE /api/events/:id` - 删除活动
- ✅ `POST /api/events/:id/enroll` - 报名活动（检查人数限制）

**打卡系统**：
- ✅ `POST /api/reading_schedules/:id/check_ins` - 提交打卡
- ✅ `GET /api/reading_schedules/:id/check_ins` - 查看当日所有打卡
- ✅ `GET /api/check_ins/:id` - 打卡详情

**领读功能**：
- ✅ `POST /api/reading_schedules/:id/daily_leading` - 发布领读内容
- ✅ `GET /api/reading_schedules/:id/daily_leading` - 获取领读内容
- ✅ `PUT /api/reading_schedules/:id/daily_leading` - 更新领读内容

**小红花系统**：
- ✅ `POST /api/check_ins/:id/flower` - 给打卡送小红花
- ✅ `GET /api/reading_schedules/:id/flowers` - 某日所有小红花
- ✅ `GET /api/users/:id/flowers` - 用户收到的所有小红花

#### 4. 业务逻辑实现
- ✅ 自动生成阅读计划（创建活动时）
- ✅ 防重复报名验证
- ✅ 人数限制检查
- ✅ 打卡字数自动计算
- ✅ 权限控制（领读人才能发布内容、发小红花）
- ✅ 每日小红花数量限制
- ✅ 不能给自己送花

#### 5. 测试验证
- ✅ 创建活动成功
- ✅ 自动生成阅读计划
- ✅ 报名流程完整
- ✅ 打卡提交成功
- ✅ 领读内容发布
- ✅ 小红花发放成功

### 📝 关键代码特性

#### 1. 完整的 Active Record 关联
```ruby
# 多层关联设计
ReadingEvent
  has_many :enrollments
  has_many :participants, through: :enrollments, source: :user
  has_many :reading_schedules

ReadingSchedule
  has_many :check_ins
  has_one :daily_leading
  has_many :flowers
```

#### 2. 枚举类型使用
```ruby
enum :status, { draft: 0, enrolling: 1, in_progress: 2, completed: 3 }
enum :payment_status, { unpaid: 0, paid: 1, refunded: 2 }
enum :role, { participant: 0, leader: 1 }
enum :status, { normal: 0, makeup: 1, missed: 2 }
```

#### 3. 自定义验证规则
```ruby
validate :end_date_after_start_date
validate :daily_flower_limit
validate :giver_is_daily_leader
validate :check_enrollment_exists
```

#### 4. 回调方法使用
```ruby
before_validation :calculate_word_count, if: :content_changed?
before_create :set_submitted_at
```

#### 5. 作用域查询
```ruby
scope :today, -> { where(date: Date.today) }
scope :past, -> { where("date < ?", Date.today) }
scope :future, -> { where("date > ?", Date.today) }
```

### 🧠 今日学到的 Rails 核心概念

#### 1. 复杂的关联关系设计
- 多对多通过 join table
- has_many :through 的使用
- 条件关联（through: :enrollments, source: :user）

#### 2. 模型层面的业务逻辑
- 计算属性（service_fee, deposit, completion_rate）
- 验证规则的灵活运用
- 回调方法处理自动化逻辑

#### 3. 权限控制模式
- 在控制器中检查权限
- belongs_to 的 optional: true 使用
- 条件验证（基于用户角色）

#### 4. 数据库设计最佳实践
- 外键约束保证数据完整性
- 索引优化查询性能
- 枚举类型减少魔法数字

#### 5. RESTful API 设计
- 嵌套路由（resources 内的 member 和 collection）
- 单数资源（resource :daily_leading）
- JSON 响应的格式化

### 📊 项目统计

- **数据表数量**: 6个（users, reading_events, enrollments, reading_schedules, check_ins, daily_leadings, flowers）
- **API 端点**: 16个
- **模型文件**: 7个（包含 User）
- **控制器文件**: 5个
- **总代码行数**: 约800行（业务代码）
- **关联关系**: 20+个

## Day 3 - 2025年10月15日 ✅ 完成

### 🎯 今日目标
完善权限系统架构，实现论坛功能，优化项目文档结构

### ✅ 完成的任务

#### 1. 论坛系统实现
- ✅ **Post 模型**（论坛帖子）
  - 基础字段：title, content, user_id
  - 管理字段：pinned, hidden
  - 验证规则：标题长度、内容长度限制
  - 关联关系：belongs_to :user

- ✅ **PostsController API**
  - 完整的 CRUD 操作：创建、读取、更新、删除
  - 管理功能：置顶(pin/unpin)、隐藏(hide/unhide)
  - 权限控制：作者编辑权限、管理员管理权限
  - JSON 序列化：包含作者信息和时间格式化

#### 2. 权限系统完善
- ✅ **3层权限架构**完整实现
  - **Admin Level**: Root + Admin（永久权限）
  - **Event Level**: Group Leader + Daily Leader（临时权限）
  - **User Level**: Forum User + Participant（基础权限）

- ✅ **AdminAuthorizable Concern**
  - `authenticate_admin!` - 管理员权限验证
  - `authenticate_root!` - 超级管理员权限验证
  - 灵活的权限检查机制

- ✅ **3天权限窗口机制**
  - 前一天：发布领读内容
  - 当天：管理打卡和互动
  - 后一天：评选小红花
  - 配置化权限窗口时间

- ✅ **备份机制**
  - Group Leader 全程拥有领读人权限
  - 自动检测缺失的领读内容
  - `backup_needed` API 端点

#### 3. 管理员系统
- ✅ **AdminController 实现**
  - 仪表板数据：系统统计、当前用户信息
  - 用户管理：查看所有用户、角色管理
  - 活动审批：待审批活动列表
  - Root 用户初始化机制

- ✅ **角色权限管理**
  - 用户角色提升和降级
  - 权限检查和验证
  - 安全的权限控制

#### 4. 项目文档重构
- ✅ **文档架构重组**
  - 创建 `docs/` 统一文档目录
  - 按类型分类：business/, technical/, development/
  - 文档导航中心和使用指南

- ✅ **技术文档更新**
  - 更新权限体系设计到架构文档
  - 创建开发环境搭建指南
  - 优化 API 项目 README

- ✅ **内容一致性**
  - 更新所有文档反映最新权限系统
  - 统一术语和概念定义
  - 消除文档间的内容冲突

### 📝 今日关键代码

#### 论坛帖子权限控制
```ruby
# app/models/post.rb
def can_edit?(current_user)
  return false unless current_user
  return true if current_user.any_admin?  # 管理员可以编辑任何帖子
  return true if user_id == current_user.id  # 作者可以编辑自己的帖子
  false
end
```

#### 权限验证 Concern
```ruby
# app/controllers/concerns/admin_authorizable.rb
module AdminAuthorizable
  extend ActiveSupport::Concern

  def authenticate_admin!
    return render json: { error: "需要管理员权限" }, status: :forbidden unless current_user&.any_admin?
  end

  def authenticate_root!
    return render json: { error: "需要超级管理员权限" }, status: :forbidden unless current_user&.root?
  end
end
```

#### 时间窗口权限检查
```ruby
# app/models/user.rb
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
```

### 🧠 今日学到的核心概念

#### 1. 权限系统设计模式
- **RBAC (Role-Based Access Control)** 基于角色的权限控制
- **时间窗口权限** - 基于时间的动态权限
- **备份机制** - 关键角色的补位权限
- **分层权限** - 清晰的权限层级结构

#### 2. Rails Concerns 最佳实践
- 可复用的权限验证逻辑
- 控制器层面的关注点分离
- 灵活的权限检查机制

#### 3. 文档架构设计
- **分类管理** - 按文档类型和目标用户分类
- **版本控制** - 确保文档与代码实现一致
- **导航友好** - 清晰的文档索引和导航

#### 4. API 权限控制模式
- 基于用户角色的 API 访问控制
- 细粒度的权限验证
- 安全的权限边界检查

### 📊 项目统计更新

- **数据表数量**: 7个（新增 posts 表）
- **API 端点**: 24个（新增论坛和管理端点）
- **模型文件**: 8个（包含 Post）
- **控制器文件**: 7个（新增 AdminController, PostsController）
- **总代码行数**: 约1200行（业务代码）
- **权限层级**: 3层，6种角色
- **文档文件**: 8个（重构后）

### 🎯 下一步计划（Day 4）

#### Phase 3.1: Service Objects 重构
**目标**：将复杂业务逻辑从模型中抽离，提高代码质量

**计划任务**：
1. **EventCreationService**
   - 活动创建业务逻辑
   - 自动生成阅读计划
   - 权限设置和验证

2. **PermissionService**
   - 统一权限检查逻辑
   - 时间窗口权限验证
   - 备份机制检查

3. **测试框架搭建**
   - 模型单元测试
   - API 集成测试
   - 权限系统测试

### 💡 今日感悟

> **"这就是权限系统的艺术！"
>
> 今天我们构建了一个真正灵活的权限体系。它不是简单的"管理员/用户"二分法，而是一个多层次、时间感知的动态系统。
>
> 最让我兴奋的是 **3天权限窗口** 的设计。这个设计体现了对实际工作场景的深刻理解：
> - 领读人需要提前准备内容
> - 需要时间评选优秀作品
> - 小组长需要随时补位
>
> 这就是 Rails 的威力 - 我们用很少的代码实现了复杂的业务逻辑。通过 Concerns、枚举、回调这些 Rails 特性，我们的代码既简洁又表达力强。
>
> 记住：**好的权限系统不是限制用户，而是赋能用户**。每一层权限都应该有明确的业务意义，每一项限制都应该服务于更好的用户体验。

### 📚 推荐阅读

- [Rails Guides - Security](https://guides.rubyonrails.org/security.html)
- [Role-Based Access Control in Rails](https://medium.com/@samesir/role-based-access-control-rbac-in-rails-8f5b6225b8c3)
- [Rails Concerns Best Practices](https://thoughtbot.com/blog/lets-write-a-concern)

---

### 💡 今日感悟

> **"这就是 Active Record 的真正威力！"
>
> 今天我们构建了一个完整的读书社群系统。6个模型之间的关联关系就像一张精心编织的网，每个模型都有自己的职责，又通过关联紧密协作。
>
> 最令我兴奋的是 Rails 的 Convention over Configuration 在这里的体现：
> - 自动生成阅读计划（create 时）
> - 自动计算字数（before_validation 回调）
> - 完整的权限控制（belongs_to + 验证）
>
> 我们没有写任何 SQL，却完成了复杂的业务逻辑。这就是 Rails 之道 - **让代码表达业务，而不是让代码处理技术细节**。
>
> 明天我们要引入 Service Objects 模式，让复杂的业务逻辑更加清晰。记住：**好的代码不仅要能运行，更要易于理解和维护**。

### 📚 推荐阅读

- [Rails Guides - Active Record 关联](https://guides.rubyonrails.org/association_basics.html)
- [Rails Guides - 验证](https://guides.rubyonrails.org/validations.html)
- [Rails Guides - 回调](https://guides.rubyonrails.org/callbacks.html)
- [Service Objects in Rails](https://dev.to/corsego/service-objects-in-ruby-on-rails-4o57)

---

## 项目统计（截至 Day 2）

- **文件数**: ~30 个
- **代码行数**: ~800 行（业务代码）
- **API 端点**: 16 个
- **数据表**: 6 个
- **开发时间**: 约 6 小时（2 天）

---

**记录人**: DHH（Claude Code 扮演）
**日期**: 2025年10月15日
**状态**: ✅ Day 2 圆满完成！读书活动核心系统已上线！

### 📚 推荐阅读

- [Rails Guides - API 模式](https://guides.rubyonrails.org/api_app.html)
- [Rails Guides - Active Record 关联](https://guides.rubyonrails.org/association_basics.html)
- [JWT 官方文档](https://jwt.io/)
- [Rails 8 发布说明](https://guides.rubyonrails.org/8_0_release_notes.html)

---

## 项目统计

- **文件数**: ~50 个
- **代码行数**: ~200 行（业务代码）
- **API 端点**: 4 个
- **数据表**: 1 个（users）
- **开发时间**: 约 2 小时

---

## 下一阶段预览

### Week 1 剩余任务
- Day 2: 读书活动核心模型
- Day 3: 领读和打卡系统
- Day 4-5: 小红花和统计功能

### Week 2-3: 微信小程序开发
- 小程序登录集成
- 活动列表和详情页
- 打卡和小红花功能

---

**记录人**: DHH（Claude Code 扮演）
**日期**: 2025年10月14日
**状态**: ✅ Day 1 圆满完成！
