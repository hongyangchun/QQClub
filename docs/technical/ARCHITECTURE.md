# QQClub 读书社群 - 技术设计文档

## 一、整体架构

### 架构图
```
┌─────────────────────────────────────────────────────────┐
│                    微信生态                              │
│  ┌──────────────┐      ┌──────────────┐                │
│  │  微信小程序   │      │   微信支付    │                │
│  │  (前端UI)    │      │   (可选)     │                │
│  └──────┬───────┘      └──────────────┘                │
│         │                                               │
└─────────┼───────────────────────────────────────────────┘
          │ HTTPS/JSON
          │
┌─────────▼───────────────────────────────────────────────┐
│              Rails 8 API 后端                            │
│  ┌──────────────────────────────────────────────────┐  │
│  │  API Controllers (JSON only)                     │  │
│  ├──────────────────────────────────────────────────┤  │
│  │  Business Logic (Service Objects)                │  │
│  ├──────────────────────────────────────────────────┤  │
│  │  Models (Active Record)                          │  │
│  ├──────────────────────────────────────────────────┤  │
│  │  Authentication (JWT + 微信 OpenID)              │  │
│  └──────────────────────────────────────────────────┘  │
│                                                          │
│  Rails 8 核心特性:                                       │
│  • Solid Queue (后台任务)                                │
│  • Solid Cache (缓存)                                    │
│  • Action Mailer (邮件通知)                              │
└──────────────────┬───────────────────────────────────────┘
                   │
┌──────────────────▼───────────────────────────────────────┐
│              数据库 (SQLite/PostgreSQL)                   │
└──────────────────────────────────────────────────────────┘
```

---

## 二、技术栈选择

### 后端技术栈
| 技术 | 选择 | 理由 |
|------|------|------|
| **框架** | Ruby on Rails 8.0 | 成熟、高效、约定优于配置 |
| **API 模式** | `--api` 模式 | 纯 API，去除不必要的 View 层 |
| **数据库** | SQLite (开发) / PostgreSQL (生产) | Rails 8 的 SQLite 生产就绪，但建议生产用 PG |
| **认证** | JWT + `jwt` gem | 适合移动端/小程序的无状态认证 |
| **微信集成** | `rest-client` gem | 调用微信 API (code2session 等) |
| **后台任务** | Solid Queue | Rails 8 内置，无需 Redis |
| **缓存** | Solid Cache | Rails 8 内置，无需 Redis |
| **文件存储** | Active Storage + 云存储 (腾讯云 COS) | 小程序上传图片、书籍封面等 |
| **部署** | Kamal 2 | Rails 8 内置，零停机部署 |

### 前端技术栈
| 技术 | 选择 | 理由 |
|------|------|------|
| **框架** | 微信小程序原生 | 无需额外框架，微信生态最佳实践 |
| **UI 组件库** | Vant Weapp | 成熟的小程序 UI 组件库 |
| **状态管理** | MobX (可选) | 如果业务复杂可引入 |
| **HTTP 请求** | `wx.request` (封装) | 小程序原生 API |
| **本地存储** | `wx.storage` | 缓存用户 token 等 |

---

## 三、权限体系架构

### 3.1 权限层级概览

QQClub 采用简化的 3 层权限体系：

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

### 3.2 权限实现机制

#### 基于角色的权限检查
```ruby
# app/models/user.rb
class User < ApplicationRecord
  enum :role, {
    user: 0,           # 基础用户（论坛用户 + 活动参与者）
    admin: 1,          # 管理员
    root: 2            # 超级管理员（系统开发者）
  }

  # 管理员级别权限
  def any_admin?
    admin? || root?
  end

  def can_approve_events?
    admin? || root?
  end

  def can_manage_users?
    root?
  end

  def can_view_admin_panel?
    admin? || root?
  end

  # 活动级别权限
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

  def authenticate_event_leader!(event)
    unless current_user&.can_manage_event_content?(event, @schedule)
      render json: { error: "权限不足" }, status: :forbidden
    end
  end
end
```

### 3.3 权限矩阵

| 操作 | Root | Admin | Group Leader | Daily Leader | Forum User | Participant |
|------|------|-------|--------------|--------------|------------|-------------|
| 系统管理 | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| 用户管理 | ✅ | 部分 | ❌ | ❌ | ❌ | ❌ |
| 活动审批 | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| 论坛管理 | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| 活动创建 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 活动管理 | ✅ | ✅ | ✅(自己的) | ❌ | ❌ | ❌ |
| 领读内容 | ✅ | ✅ | ✅(全程) | ✅(3天窗口) | ❌ | ❌ |
| 打卡管理 | ✅ | ✅ | ✅(全程) | ✅(3天窗口) | ❌ | ✅(自己的) |
| 小红花评选 | ✅ | ✅ | ✅(全程) | ✅(3天窗口) | ❌ | ❌ |
| 论坛发帖 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 活动报名 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

---

## 四、核心功能模块设计

### 模块 1：用户认证（微信登录）

#### 流程图
```
[小程序]                [Rails API]              [微信服务器]
    │                        │                        │
    │  wx.login()            │                        │
    ├────────────────────────►                        │
    │  ← code                │                        │
    │                        │                        │
    │  POST /api/auth/login  │                        │
    │  { code }              │                        │
    ├────────────────────────►                        │
    │                        │                        │
    │                        │  GET code2session      │
    │                        │  code + appid + secret │
    │                        ├───────────────────────►│
    │                        │  ← openid + session_key│
    │                        │                        │
    │                        │  查找/创建 User        │
    │                        │  生成 JWT token        │
    │                        │                        │
    │  ← JWT token           │                        │
    │  { token, user_info }  │                        │
    │◄───────────────────────┤                        │
    │                        │                        │
    │  后续请求带 token       │                        │
    │  Authorization: Bearer │                        │
    ├────────────────────────►                        │
```

#### 数据模型
```ruby
# app/models/user.rb
class User < ApplicationRecord
  # 微信相关
  validates :wx_openid, presence: true, uniqueness: true
  validates :wx_unionid, uniqueness: true, allow_nil: true

  # 基础信息
  validates :nickname, presence: true

  # 关联关系
  has_many :created_events, class_name: 'ReadingEvent', foreign_key: 'leader_id'
  has_many :enrollments
  has_many :reading_events, through: :enrollments
  has_many :check_ins
  has_many :flowers_received, class_name: 'Flower', foreign_key: 'recipient_id'

  # 生成 JWT token
  def generate_jwt_token
    JWT.encode(
      { user_id: id, exp: 30.days.from_now.to_i },
      Rails.application.credentials.jwt_secret_key
    )
  end
end
```

#### API 端点
```
POST   /api/auth/login          微信登录
GET    /api/auth/me             获取当前用户信息
PUT    /api/auth/profile        更新用户资料
```

---

### 模块 2：共读活动管理

#### 数据模型
```ruby
# app/models/reading_event.rb
class ReadingEvent < ApplicationRecord
  belongs_to :leader, class_name: 'User'
  has_many :enrollments, dependent: :destroy
  has_many :participants, through: :enrollments, source: :user
  has_many :reading_schedules, dependent: :destroy

  validates :title, presence: true
  validates :book_name, presence: true
  validates :start_date, :end_date, presence: true
  validates :max_participants, numericality: { greater_than: 0 }
  validates :enrollment_fee, numericality: { greater_than_or_equal_to: 0 }

  enum status: { draft: 0, enrolling: 1, in_progress: 2, completed: 3 }

  # 计算相关
  def service_fee
    enrollment_fee * 0.2
  end

  def deposit
    enrollment_fee * 0.8
  end

  def days_count
    (end_date - start_date).to_i + 1
  end
end

# app/models/enrollment.rb
class Enrollment < ApplicationRecord
  belongs_to :user
  belongs_to :reading_event

  validates :user_id, uniqueness: { scope: :reading_event_id }

  enum payment_status: { unpaid: 0, paid: 1, refunded: 2 }
  enum role: { participant: 0, leader: 1 }

  # 计算打卡完成率
  def completion_rate
    total_days = reading_event.reading_schedules.count
    return 0 if total_days.zero?

    completed_days = check_ins.where.not(status: 'missed').count
    (completed_days.to_f / total_days * 100).round(2)
  end

  # 计算应退押金
  def refund_amount
    reading_event.deposit * (completion_rate / 100.0)
  end
end
```

#### API 端点
```
# 活动管理
GET    /api/events              获取活动列表
GET    /api/events/:id          获取活动详情
POST   /api/events              创建活动（小组长）
PUT    /api/events/:id          更新活动
DELETE /api/events/:id          删除活动

# 报名管理
POST   /api/events/:id/enroll   报名参加活动
GET    /api/events/:id/participants  获取参与者列表
```

---

### 模块 3：阅读计划与领读

#### 数据模型
```ruby
# app/models/reading_schedule.rb
class ReadingSchedule < ApplicationRecord
  belongs_to :reading_event
  belongs_to :daily_leader, class_name: 'User', optional: true
  has_one :daily_leading
  has_many :check_ins, dependent: :destroy

  validates :day_number, presence: true
  validates :reading_progress, presence: true

  scope :today, -> { where(date: Date.today) }
  scope :past, -> { where('date < ?', Date.today) }
  scope :future, -> { where('date > ?', Date.today) }
end

# app/models/daily_leading.rb
class DailyLeading < ApplicationRecord
  belongs_to :reading_schedule
  belongs_to :leader, class_name: 'User'

  validates :reading_suggestion, presence: true
  validates :questions, presence: true

  # questions 存储为 JSON array
  # 例如: ["问题1", "问题2", "问题3"]
end
```

#### API 端点
```
# 阅读计划
GET    /api/events/:id/schedules        获取活动的阅读计划
POST   /api/events/:id/schedules        创建阅读计划（小组长）
PUT    /api/schedules/:id               更新计划

# 领读
POST   /api/schedules/:id/leading       发布领读内容
GET    /api/schedules/:id/leading       获取领读内容
POST   /api/schedules/:id/claim_leader  认领领读人
```

---

### 模块 4：打卡系统

#### 数据模型
```ruby
# app/models/check_in.rb
class CheckIn < ApplicationRecord
  belongs_to :user
  belongs_to :reading_schedule
  belongs_to :enrollment
  has_one :flower, dependent: :destroy

  validates :content, presence: true, length: { minimum: 100 }
  validates :user_id, uniqueness: { scope: :reading_schedule_id }

  enum status: { normal: 0, makeup: 1, missed: 2 }

  # 是否可以补卡
  def can_makeup?
    reading_schedule.reading_event.status == 'in_progress' &&
    reading_schedule.date < Date.today
  end

  # 是否获得小红花
  def has_flower?
    flower.present?
  end
end
```

#### API 端点
```
# 打卡
POST   /api/schedules/:id/check_in      提交打卡
GET    /api/schedules/:id/check_ins     获取当日所有打卡
GET    /api/check_ins/:id               获取打卡详情
PUT    /api/check_ins/:id               更新打卡（补卡）

# 我的打卡记录
GET    /api/events/:id/my_check_ins     我在某活动的打卡记录
```

---

### 模块 5：小红花系统

#### 数据模型
```ruby
# app/models/flower.rb
class Flower < ApplicationRecord
  belongs_to :check_in
  belongs_to :giver, class_name: 'User'  # 领读人
  belongs_to :recipient, class_name: 'User'  # 打卡人
  belongs_to :reading_schedule

  validates :giver_id, :recipient_id, :check_in_id, presence: true
  validates :check_in_id, uniqueness: true  # 一个打卡只能获得一朵小红花

  # 领读人当天最多发3朵
  validate :daily_flower_limit

  private

  def daily_flower_limit
    daily_count = Flower.where(
      giver: giver,
      reading_schedule: reading_schedule
    ).count

    if daily_count >= 3 && !persisted?
      errors.add(:base, '每日最多发放3朵小红花')
    end
  end
end
```

#### API 端点
```
# 小红花
POST   /api/check_ins/:id/flower        给某打卡授予小红花（领读人）
DELETE /api/flowers/:id                 撤销小红花
GET    /api/events/:id/flower_ranking   活动小红花排行榜
```

---

### 模块 6：活动统计与结算

#### Service Object 示例
```ruby
# app/services/event_summary_service.rb
class EventSummaryService
  def initialize(reading_event)
    @event = reading_event
  end

  def generate_summary
    {
      event_id: @event.id,
      total_participants: @event.enrollments.count,
      completion_stats: completion_statistics,
      flower_ranking: flower_ranking,
      refund_calculations: calculate_refunds,
      top_winners: top_three_winners
    }
  end

  private

  def completion_statistics
    @event.enrollments.map do |enrollment|
      {
        user_id: enrollment.user_id,
        nickname: enrollment.user.nickname,
        completion_rate: enrollment.completion_rate,
        total_check_ins: enrollment.check_ins.count,
        flowers_count: enrollment.user.flowers_received
                                 .joins(check_in: :reading_schedule)
                                 .where(reading_schedules: { reading_event_id: @event.id })
                                 .count
      }
    end
  end

  def flower_ranking
    # 返回小红花排名
    # ...
  end

  def calculate_refunds
    @event.enrollments.map do |enrollment|
      {
        user_id: enrollment.user_id,
        refund_amount: enrollment.refund_amount
      }
    end
  end

  def top_three_winners
    # 返回前3名小红花获得者
    # ...
  end
end
```

#### API 端点
```
GET    /api/events/:id/summary          获取活动统计
POST   /api/events/:id/finalize         活动结算（小组长）
```

---

## 四、微信小程序前端设计

### 页面结构
```
pages/
├── index/              # 首页（活动列表）
│   ├── index.wxml
│   ├── index.wxss
│   └── index.js
├── event-detail/       # 活动详情
├── check-in/           # 打卡页面
├── leading/            # 领读发布页面
├── check-in-list/      # 打卡列表（看他人打卡）
├── ranking/            # 小红花排行榜
├── my-events/          # 我的活动
├── create-event/       # 创建活动（小组长）
└── profile/            # 个人中心
```

### 关键组件
```javascript
// utils/request.js - 封装 API 请求
const BASE_URL = 'https://your-api.com/api'

function request(url, method = 'GET', data = {}) {
  const token = wx.getStorageSync('jwt_token')

  return new Promise((resolve, reject) => {
    wx.request({
      url: BASE_URL + url,
      method,
      data,
      header: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      success: (res) => {
        if (res.statusCode === 200) {
          resolve(res.data)
        } else {
          reject(res)
        }
      },
      fail: reject
    })
  })
}

module.exports = { request }
```

### 微信登录实现
```javascript
// pages/index/index.js
const { request } = require('../../utils/request')

Page({
  onLoad() {
    this.checkLogin()
  },

  async checkLogin() {
    const token = wx.getStorageSync('jwt_token')
    if (!token) {
      await this.doLogin()
    }
  },

  async doLogin() {
    try {
      // 1. 获取微信 code
      const { code } = await wx.login()

      // 2. 发送到后端换取 JWT token
      const res = await request('/auth/login', 'POST', { code })

      // 3. 保存 token
      wx.setStorageSync('jwt_token', res.token)
      wx.setStorageSync('user_info', res.user)

      console.log('登录成功')
    } catch (error) {
      console.error('登录失败', error)
    }
  }
})
```

---

## 五、数据库 Schema 设计

### 核心表结构
```ruby
# db/schema.rb (预览)

create_table "users", force: :cascade do |t|
  t.string "wx_openid", null: false
  t.string "wx_unionid"
  t.string "nickname", null: false
  t.string "avatar_url"
  t.string "phone"
  t.timestamps
  t.index ["wx_openid"], unique: true
  t.index ["wx_unionid"], unique: true
end

create_table "reading_events", force: :cascade do |t|
  t.bigint "leader_id", null: false  # 小组长
  t.string "title", null: false
  t.string "book_name", null: false
  t.string "book_cover_url"
  t.text "description"
  t.date "start_date", null: false
  t.date "end_date", null: false
  t.integer "max_participants", default: 30
  t.decimal "enrollment_fee", precision: 8, scale: 2, default: 100.0
  t.integer "status", default: 0  # draft/enrolling/in_progress/completed
  t.timestamps
  t.index ["leader_id"]
  t.index ["status"]
end

create_table "enrollments", force: :cascade do |t|
  t.bigint "user_id", null: false
  t.bigint "reading_event_id", null: false
  t.integer "payment_status", default: 0  # unpaid/paid/refunded
  t.integer "role", default: 0  # participant/leader
  t.integer "leading_count", default: 0
  t.decimal "paid_amount", precision: 8, scale: 2
  t.decimal "refund_amount", precision: 8, scale: 2
  t.timestamps
  t.index ["user_id", "reading_event_id"], unique: true
end

create_table "reading_schedules", force: :cascade do |t|
  t.bigint "reading_event_id", null: false
  t.integer "day_number", null: false
  t.date "date", null: false
  t.string "reading_progress", null: false  # 例如："第1-3章" 或 "第10-30页"
  t.bigint "daily_leader_id"  # 领读人（可为空）
  t.timestamps
  t.index ["reading_event_id", "day_number"], unique: true
  t.index ["date"]
end

create_table "daily_leadings", force: :cascade do |t|
  t.bigint "reading_schedule_id", null: false
  t.bigint "leader_id", null: false
  t.text "reading_suggestion"
  t.json "questions"  # 存储 2-3 个问题的数组
  t.timestamps
  t.index ["reading_schedule_id"], unique: true
end

create_table "check_ins", force: :cascade do |t|
  t.bigint "user_id", null: false
  t.bigint "reading_schedule_id", null: false
  t.bigint "enrollment_id", null: false
  t.text "content", null: false
  t.integer "word_count", default: 0
  t.integer "status", default: 0  # normal/makeup/missed
  t.datetime "submitted_at"
  t.timestamps
  t.index ["user_id", "reading_schedule_id"], unique: true
  t.index ["enrollment_id"]
end

create_table "flowers", force: :cascade do |t|
  t.bigint "check_in_id", null: false
  t.bigint "giver_id", null: false  # 领读人
  t.bigint "recipient_id", null: false  # 打卡人
  t.bigint "reading_schedule_id", null: false
  t.text "comment"  # 领读人评语（可选）
  t.timestamps
  t.index ["check_in_id"], unique: true
  t.index ["recipient_id"]
  t.index ["reading_schedule_id", "giver_id"]
end
```

---

## 六、安全性考虑

### 1. API 认证
- 所有 API 请求必须携带有效的 JWT token
- Token 过期时间：30 天
- 刷新机制：过期前 3 天自动刷新

### 2. 权限控制
```ruby
# app/controllers/concerns/authorization.rb
module Authorization
  extend ActiveSupport::Concern

  def authorize_event_leader!(event)
    unless current_user == event.leader
      render json: { error: 'Unauthorized' }, status: :forbidden
    end
  end

  def authorize_daily_leader!(schedule)
    unless current_user == schedule.daily_leader
      render json: { error: 'Unauthorized' }, status: :forbidden
    end
  end
end
```

### 3. 数据验证
- 打卡内容最少 100 字
- 每日小红花最多 3 朵
- 领读次数限制

### 4. 微信 AppSecret 保护
```yaml
# config/credentials.yml.enc (加密存储)
wechat:
  app_id: wxxxxxxxxxxx
  app_secret: xxxxxxxxxxxxxxxx

jwt_secret_key: xxxxxxxxxxxxxx
```

---

## 七、部署架构

### 开发环境
```
本地开发:
- Rails 运行在 localhost:3000
- 小程序开发者工具连接本地 API
- SQLite 数据库
```

### 生产环境
```
云服务器 (推荐腾讯云):
- Rails 应用 (Kamal 部署)
- PostgreSQL 数据库
- Nginx (由 Kamal 自动配置)
- SSL 证书 (Let's Encrypt)

域名:
- API: api.qqclub.com
- 小程序必须使用 HTTPS
```

---

## 八、开发路线图（10 周计划）

### Week 1-2: Rails API 基础
- [ ] 创建 Rails API 项目
- [ ] 设置微信登录和 JWT 认证
- [ ] 实现 User 模型和 API
- [ ] 测试认证流程（Postman）

### Week 3-4: 核心业务模型
- [ ] ReadingEvent + Enrollment 模型和 API
- [ ] ReadingSchedule + DailyLeading 模型和 API
- [ ] CheckIn 模型和 API
- [ ] Flower 模型和 API

### Week 5-6: 业务逻辑与统计
- [ ] Service Objects（创建活动、打卡验证、结算等）
- [ ] 统计功能（完成率、排行榜）
- [ ] 后台任务（Solid Queue）

### Week 7-8: 微信小程序前端
- [ ] 小程序项目初始化
- [ ] 微信登录集成
- [ ] 核心页面开发（活动列表、详情、打卡）
- [ ] 领读和小红花功能

### Week 9: 支付与通知
- [ ] 微信支付集成
- [ ] 模板消息通知
- [ ] 分享卡片

### Week 10: 测试与部署
- [ ] 完整流程测试
- [ ] 性能优化
- [ ] Kamal 部署到生产环境
- [ ] 小程序提审上线

---

## 九、关键决策点总结

| 决策点 | 选择 | 理由 |
|--------|------|------|
| **架构** | 前后端分离 | 灵活、现代、用户体验好 |
| **后端** | Rails 8 API 模式 | 成熟、高效、快速开发 |
| **前端** | 微信小程序原生 | 微信生态最佳实践 |
| **认证** | JWT + 微信 OpenID | 适合移动端无状态认证 |
| **数据库** | PostgreSQL (生产) | 稳定、功能强大 |
| **部署** | Kamal 2 | Rails 8 推荐，简单高效 |

---

## 十、下一步行动

现在我们需要决定：

1. **你想从哪里开始？**
   - Option A: 先构建 Rails API 后端（推荐）
   - Option B: 先快速搭建 Rails 全栈原型，再改造成 API

2. **你的小程序开发经验如何？**
   - 如果零基础，我建议先专注 Rails，后续我再手把手教你小程序
   - 如果有基础，我们可以并行开发

3. **时间投入？**
   - 全职学习？还是业余时间？
   - 这会影响我们的节奏规划

**告诉我你的想法，我们开始动手！** 🚀
