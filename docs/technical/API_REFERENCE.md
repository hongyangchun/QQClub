# QQClub 技术设计文档

## 1. 系统架构概览

QQClub 是一个基于 Rails 8 API 构建的读书社区后端系统，采用微服务架构设计，支持论坛讨论、读书活动管理、打卡记录、小红花互动等核心功能。

### 1.1 技术栈
- **后端框架**: Ruby on Rails 8 (API模式)
- **数据库**: PostgreSQL 14+
- **认证**: JWT Token
- **测试**: RSpec
- **部署**: Docker + Kubernetes

### 1.2 核心设计原则
- RESTful API 设计
- 基于角色的权限控制 (RBAC)
- 数据一致性和完整性
- 可扩展的模块化架构

## 2. 权限层级设计

QQClub采用简化的3层权限体系，确保系统安全且易于维护：

### 2.1 权限层级概览
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

### 2.2 角色定义

#### 2.2.1 管理员级别 (Admin Level)

**Root (超级管理员)**
- 系统开发者角色
- 拥有系统最高权限
- 可以创建和管理工作员
- 可以审批读书活动
- 可以管理所有用户角色

**Admin (管理员)**
- 社区日常管理者
- 可以审批读书活动
- 可以置顶/隐藏论坛帖子
- 可以查看系统统计数据
- 可以管理用户角色（除Root外）

权限范围：
- 审批活动：`POST /api/events/:id/approve`
- 论坛管理：置顶、隐藏、删除帖子
- 用户管理：提升/降级用户角色
- 数据查看：查看系统统计、用户列表

#### 2.2.2 活动级别 (Event Level)

**Group Leader (小组长)**
- 读书活动的创建者
- 自动获得小组长身份
- 拥有整个活动期间的管理权限
- 可以作为领读人的备份

权限范围：
- 领读内容管理：整个活动期间
- 打卡内容管理：整个活动期间
- 小红花评选：整个活动期间
- 参与者管理：查看报名情况、设置随机领读

**Daily Leader (领读人)**
- 每日活动负责人
- 通过自由报名或随机分配产生
- 拥有3天权限窗口（前一天、当天、后一天）

权限窗口：
- 前一天：发布领读内容
- 当天：管理打卡和互动
- 后一天：评选小红花

权限范围：
- 领读内容：创建、编辑领读内容
- 打卡管理：查看、提醒参与者打卡
- 小红花：给优秀打卡发放小红花

#### 2.2.3 用户级别 (User Level)

**Forum User (论坛用户)**
- 所有用户的基础身份
- 可以浏览和参与论坛讨论
- 可以创建和编辑自己的帖子
- 可以评论和互动

**Participant (活动参与者)**
- 报名参加读书活动的用户
- 拥有活动相关的所有基础权限
- 可以进行每日打卡
- 可以领取打卡内容
- 可以给他人送小红花

权限范围：
- 论坛互动：发帖、评论、编辑自己的内容
- 活动参与：报名、打卡、领取内容、互动

### 2.3 权限实现机制

#### 2.3.1 基于角色的权限检查
```ruby
# User Model 权限检查方法
def can_approve_events?
  admin? || root?
end

def can_manage_users?
  root?
end

def can_view_admin_panel?
  admin? || root?
end

# 活动相关权限检查
def can_manage_event_content?(event, schedule)
  return true if admin? || root?
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

#### 2.3.2 权限验证 Concern
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

  def authenticate_event_leader!
    # 验证活动级别权限的具体逻辑
  end
end
```

## 3. 数据模型设计

### 3.1 核心实体关系图
```
User (用户)
├── Post (论坛帖子)
├── ReadingEvent (读书活动) [as leader]
├── Enrollment (报名记录)
├── CheckIn (打卡记录)
├── DailyLeading (领读内容)
└── Flower (小红花)

ReadingEvent (读书活动)
├── ReadingSchedule (阅读计划)
├── Enrollment (报名记录)
└── User (leader)

ReadingSchedule (阅读计划)
├── CheckIn (打卡记录)
├── DailyLeading (领读内容)
└── Flower (小红花)

Enrollment (报名记录)
├── CheckIn (打卡记录)
└── User (participant)
```

### 3.2 数据表设计

#### users 表
```sql
- id: integer (主键)
- wx_openid: string (微信OpenID, 唯一)
- wx_unionid: string (微信UnionID, 唯一)
- nickname: string (昵称)
- avatar_url: string (头像URL)
- phone: string (手机号)
- role: integer (角色: 0=user, 1=admin, 2=root)
- created_at: datetime
- updated_at: datetime
```

#### posts 表
```sql
- id: integer (主键)
- title: string (标题)
- content: text (内容)
- user_id: integer (外键 -> users.id)
- pinned: boolean (是否置顶)
- hidden: boolean (是否隐藏)
- created_at: datetime
- updated_at: datetime
```

#### reading_events 表
```sql
- id: integer (主键)
- title: string (活动标题)
- book_name: string (书名)
- book_cover_url: string (书籍封面)
- description: text (活动描述)
- start_date: date (开始日期)
- end_date: date (结束日期)
- max_participants: integer (最大参与人数)
- enrollment_fee: decimal (报名费用)
- status: integer (状态: 0=planned, 1=in_progress, 2=completed)
- leader_id: integer (外键 -> users.id)
- leader_assignment_type: integer (领读分配: 0=voluntary, 1=random)
- approval_status: integer (审批状态: 0=pending, 1=approved, 2=rejected)
- approved_by_id: integer (审批人ID)
- approved_at: datetime (审批时间)
- created_at: datetime
- updated_at: datetime
```

#### reading_schedules 表
```sql
- id: integer (主键)
- reading_event_id: integer (外键 -> reading_events.id)
- day_number: integer (第几天)
- date: date (日期)
- reading_progress: string (阅读进度)
- daily_leader_id: integer (当日领读人ID)
- created_at: datetime
- updated_at: datetime
```

#### daily_leadings 表
```sql
- id: integer (主键)
- reading_schedule_id: integer (外键 -> reading_schedules.id)
- leader_id: integer (外键 -> users.id)
- reading_suggestion: text (阅读建议)
- questions: text (思考题)
- created_at: datetime
- updated_at: datetime
```

#### check_ins 表
```sql
- id: integer (主键)
- user_id: integer (外键 -> users.id)
- reading_schedule_id: integer (外键 -> reading_schedules.id)
- enrollment_id: integer (外键 -> enrollments.id)
- content: text (打卡内容)
- word_count: integer (字数统计)
- status: integer (状态: 0=draft, 1=submitted)
- submitted_at: datetime (提交时间)
- created_at: datetime
- updated_at: datetime
```

#### flowers 表
```sql
- id: integer (主键)
- check_in_id: integer (外键 -> check_ins.id)
- giver_id: integer (外键 -> users.id)
- recipient_id: integer (外键 -> users.id)
- reading_schedule_id: integer (外键 -> reading_schedules.id)
- comment: text (留言)
- created_at: datetime
- updated_at: datetime
```

#### enrollments 表
```sql
- id: integer (主键)
- user_id: integer (外键 -> users.id)
- reading_event_id: integer (外键 -> reading_events.id)
- payment_status: integer (支付状态)
- role: integer (在活动中的角色)
- leading_count: integer (领读次数)
- paid_amount: decimal (已支付金额)
- refund_amount: decimal (退款金额)
- created_at: datetime
- updated_at: datetime
```

### 3.3 数据验证规则

#### User 模型验证
```ruby
validates :wx_openid, presence: true, uniqueness: true
validates :nickname, length: { maximum: 50 }
validates :role, inclusion: { in: %w[user admin root] }
```

#### Post 模型验证
```ruby
validates :title, presence: true, length: { maximum: 100 }
validates :content, presence: true, length: { minimum: 10, maximum: 5000 }
validates :user_id, presence: true
```

#### ReadingEvent 模型验证
```ruby
validates :title, :book_name, :start_date, :end_date, presence: true
validates :start_date, comparison: { less_than_or_equal_to: :end_date }
validates :max_participants, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
validates :enrollment_fee, numericality: { greater_than_or_equal_to: 0 }
```

## 4. API 设计

### 4.1 RESTful API 端点

#### 认证相关 (/api/auth)
- `POST /api/auth/mock_login` - 微信模拟登录
- `POST /api/auth/login` - 用户登录
- `GET /api/auth/me` - 获取当前用户信息
- `PUT /api/auth/profile` - 更新用户资料

#### 论坛相关 (/api/posts)
- `GET /api/posts` - 获取帖子列表
- `POST /api/posts` - 创建帖子
- `GET /api/posts/:id` - 获取帖子详情
- `PUT /api/posts/:id` - 更新帖子
- `DELETE /api/posts/:id` - 删除帖子
- `POST /api/posts/:id/pin` - 置顶帖子
- `POST /api/posts/:id/unpin` - 取消置顶
- `POST /api/posts/:id/hide` - 隐藏帖子
- `POST /api/posts/:id/unhide` - 显示帖子

#### 活动相关 (/api/events)
- `GET /api/events` - 获取活动列表
- `POST /api/events` - 创建活动
- `GET /api/events/:id` - 获取活动详情
- `PUT /api/events/:id` - 更新活动
- `DELETE /api/events/:id` - 删除活动
- `POST /api/events/:id/enroll` - 报名活动
- `POST /api/events/:id/approve` - 审批活动
- `POST /api/events/:id/reject` - 拒绝活动
- `POST /api/events/:id/claim_leadership` - 申领领读
- `POST /api/events/:id/complete` - 完成活动
- `GET /api/events/:id/backup_needed` - 检查是否需要补位

#### 阅读计划相关 (/api/reading_schedules/:schedule_id)
- `POST /api/reading_schedules/:schedule_id/check_ins` - 创建打卡
- `GET /api/reading_schedules/:schedule_id/check_ins` - 获取打卡列表
- `POST /api/reading_schedules/:schedule_id/daily_leading` - 创建领读内容
- `GET /api/reading_schedules/:schedule_id/daily_leading` - 获取领读内容
- `PUT /api/reading_schedules/:schedule_id/daily_leading` - 更新领读内容
- `GET /api/reading_schedules/:schedule_id/flowers` - 获取小红花列表

#### 打卡相关 (/api/check_ins)
- `GET /api/check_ins/:id` - 获取打卡详情
- `PUT /api/check_ins/:id` - 更新打卡内容
- `POST /api/check_ins/:id/flower` - 送小红花

#### 小红花相关 (/api/flowers)
- `GET /api/users/:user_id/flowers` - 获取用户收到的小红花

#### 管理员相关 (/api/admin)
- `GET /api/admin/dashboard` - 管理面板数据
- `GET /api/admin/users` - 用户列表
- `GET /api/admin/events/pending` - 待审批活动
- `PUT /api/admin/users/:id/promote_admin` - 提升管理员
- `PUT /api/admin/users/:id/demote` - 降级用户
- `POST /api/admin/init_root` - 初始化Root用户

### 4.2 响应格式规范

#### 成功响应
```json
{
  "message": "操作成功",
  "data": {
    // 具体数据
  }
}
```

#### 错误响应
```json
{
  "error": "错误描述",
  "errors": [
    // 详细错误信息数组
  ]
}
```

#### 分页响应
```json
{
  "data": [
    // 数据列表
  ],
  "pagination": {
    "current_page": 1,
    "total_pages": 10,
    "total_count": 100,
    "per_page": 10
  }
}
```

### 4.3 HTTP 状态码规范
- `200` - 成功
- `201` - 创建成功
- `400` - 请求参数错误
- `401` - 未认证
- `403` - 权限不足
- `404` - 资源不存在
- `422` - 数据验证失败
- `500` - 服务器内部错误

## 5. 业务流程设计

### 5.1 读书活动生命周期
1. **创建活动** - 用户创建读书活动
2. **活动审批** - 管理员审批活动
3. **开放报名** - 用户报名参加活动
4. **活动进行** - 按阅读计划进行打卡
5. **活动结束** - 完成活动总结

### 5.2 每日打卡流程
1. **领读准备** - 领读人发布领读内容
2. **用户打卡** - 参与者提交打卡
3. **互动交流** - 查看他人打卡，留言互动
4. **小红花评选** - 领读人评选优秀打卡
5. **次日总结** - 统计当日参与情况

### 5.3 权限验证流程
1. **身份认证** - JWT Token 验证
2. **角色检查** - 基于用户角色验证基础权限
3. **资源权限** - 检查对特定资源的操作权限
4. **时间窗口** - 验证时间相关的权限限制
5. **操作日志** - 记录关键操作审计日志

## 6. 安全设计

### 6.1 认证机制
- JWT Token 认证
- Token 过期时间控制
- 刷新Token机制
- 微信OAuth2集成

### 6.2 权限控制
- 基于角色的访问控制 (RBAC)
- 资源级别的权限检查
- API端点权限保护
- 前后端权限验证一致性

### 6.3 数据安全
- 输入参数验证和过滤
- SQL注入防护
- XSS攻击防护
- 敏感数据加密存储

### 6.4 业务安全
- 防重复提交
- 接口频率限制
- 异常操作监控
- 操作审计日志

## 7. 性能优化

### 7.1 数据库优化
- 合理的索引设计
- 查询优化和N+1问题解决
- 数据库连接池配置
- 读写分离（如需要）

### 7.2 缓存策略
- Redis缓存热点数据
- 活动列表缓存
- 用户权限信息缓存
- 静态资源CDN加速

### 7.3 API性能
- 分页查询优化
- 字段选择性返回
- 批量操作接口
- 异步任务处理

## 8. 监控和日志

### 8.1 应用监控
- 服务器性能监控
- 数据库性能监控
- API响应时间监控
- 错误率监控

### 8.2 业务监控
- 用户活跃度统计
- 活动参与度分析
- 关键业务指标监控
- 异常业务行为告警

### 8.3 日志管理
- 结构化日志记录
- 日志级别分类
- 日志聚合和分析
- 日志轮转和归档

## 9. 部署架构

### 9.1 容器化部署
- Docker镜像构建
- Kubernetes集群部署
- 服务发现和负载均衡
- 健康检查机制

### 9.2 环境管理
- 开发/测试/生产环境隔离
- 配置管理和密钥管理
- 数据库迁移和版本管理
- 蓝绿部署和灰度发布

### 9.3 备份和恢复
- 数据库定期备份
- 配置文件备份
- 灾难恢复预案
- 数据一致性校验

## 10. 开发规范

### 10.1 代码规范
- Ruby代码风格指南
- 命名规范和注释规范
- 代码审查流程
- 重构和优化标准

### 10.2 测试规范
- 单元测试覆盖率要求
- 集成测试策略
- API测试自动化
- 性能测试基准

### 10.3 版本控制
- Git工作流程
- 分支管理策略
- 提交信息规范
- 代码合并规范

---

*本文档持续更新，记录QQClub系统的技术架构和设计决策。*