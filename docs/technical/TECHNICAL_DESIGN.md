# QQClub 技术实现细节

## 📋 文档说明

**定位**: QQClub 系统的详细技术实现细节，包含权限设计、业务流程、安全考虑等技术深度内容
**目标读者**: 后端开发者、架构师、技术负责人、高级开发者
**文档深度**: 技术实现细节、设计决策、代码示例、最佳实践

---

## 🔐 权限系统设计

### 权限层级架构

QQClub 采用简化的 3 层权限体系，确保系统安全且易于维护：

#### 管理员级别 (Admin Level)
- **Root (超级管理员)**: 系统开发者，拥有最高权限
- **Admin (管理员)**: 社区管理者，负责日常管理

#### 活动级别 (Event Level)
- **Group Leader (小组长)**: 读书活动创建者，全程管理权限
- **Daily Leader (领读人)**: 每日活动负责人，3天权限窗口

#### 用户级别 (User Level)
- **Forum User (论坛用户)**: 基础权限，论坛发帖评论
- **Participant (活动参与者)**: 报名用户，活动参与权限

### 权限实现机制

#### 用户模型权限检查
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

  # 活动级别权限 - 带时间窗口检查
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

  # 内容管理权限
  def can_manage_post?(post)
    return true if any_admin?
    return true if post.user_id == id  # 作者可以管理自己的帖子
    false
  end

  # 活动报名权限
  def can_enroll_event?(event)
    return false if any_admin?  # 管理员不需要报名
    return false if event.leader_id == id  # 小组长不需要报名
    return false if event.enrollments.exists?(user_id: id)  # 已报名
    return false if event.max_participants <= event.current_participants  # 人数已满
    true
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

  def authenticate_post_author!(post)
    unless current_user&.can_manage_post?(post)
      render json: { error: "权限不足" }, status: :forbidden
    end
  end
end
```

#### 权限中间件
```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  include AdminAuthorizable

  private

  def current_user
    @current_user ||= User.find_by(id: decoded_token[:user_id]) if decoded_token
  end

  def decoded_token
    @decoded_token ||= JWT.decode(request.headers['Authorization']&.split(' ')&.last,
                               Rails.application.credentials.jwt_secret_key,
                               true,
                               algorithm: 'HS256')&.first
  rescue JWT::DecodeError
    nil
  end

  def authenticate_user!
    render json: { error: "请先登录" }, status: :unauthorized unless current_user
  end
end
```

---

## 🔄 业务流程设计

### 用户认证流程

#### 微信登录流程
```ruby
# app/controllers/auth_controller.rb
class AuthController < ApplicationController
  # 微信模拟登录
  def mock_login
    user = User.find_or_create_by(wx_openid: login_params[:openid]) do |u|
      u.nickname = login_params[:nickname]
      u.avatar_url = login_params[:avatar_url]
      u.role = :user
    end

    token = user.generate_jwt_token

    render json: {
      message: "登录成功",
      data: {
        token: token,
        user: user.as_json(only: [:id, :openid, :nickname, :avatar_url, :role, :created_at])
      }
    }
  end

  # 获取当前用户信息
  def me
    render json: {
      message: "获取成功",
      data: current_user.as_json(only: [:id, :openid, :nickname, :avatar_url, :role, :created_at, :updated_at])
    }
  end

  private

  def login_params
    params.require(:auth).permit(:openid, :nickname, :avatar_url)
  end
end
```

#### JWT Token 生成
```ruby
# app/models/user.rb
class User < ApplicationRecord
  def generate_jwt_token
    payload = {
      user_id: id,
      role: role,
      exp: 30.days.from_now.to_i,
      iat: Time.current.to_i
    }

    JWT.encode(payload, Rails.application.credentials.jwt_secret_key, 'HS256')
  end

  def self.from_jwt_token(token)
    decoded = JWT.decode(token, Rails.application.credentials.jwt_secret_key, true, algorithm: 'HS256').first
    User.find_by(id: decoded['user_id'])
  rescue JWT::DecodeError, JWT::ExpiredSignature
    nil
  end
end
```

### 活动管理流程

#### 活动创建与审批
```ruby
# app/controllers/events_controller.rb
class EventsController < ApplicationController
  before_action :authenticate_user!, only: [:create, :enroll]
  before_action :authenticate_admin!, only: [:approve, :reject]

  # 创建活动
  def create
    @event = ReadingEvent.new(event_params)
    @event.leader = current_user
    @event.status = :draft
    @event.approval_status = :pending

    if @event.save
      render json: {
        message: "活动创建成功，等待管理员审批",
        data: @event.as_json(include: :leader)
      }, status: :created
    else
      render json: {
        error: "创建失败",
        errors: @event.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # 管理员审批活动
  def approve
    @event = ReadingEvent.find(params[:id])
    @event.update!(approval_status: :approved, status: :enrolling, approved_by: current_user, approved_at: Time.current)

    render json: {
      message: "活动审批成功",
      data: @event.as_json(include: :leader)
    }
  end

  # 拒绝活动
  def reject
    @event = ReadingEvent.find(params[:id])
    @event.update!(approval_status: :rejected, status: :draft, rejection_reason: params[:reason])

    render json: {
      message: "活动已拒绝",
      data: @event.as_json(include: :leader)
    }
  end

  private

  def event_params
    params.require(:event).permit(:title, :book_name, :book_cover_url, :description,
                                :start_date, :end_date, :max_participants, :enrollment_fee,
                                :leader_assignment_type)
  end
end
```

#### 活动报名流程
```ruby
# app/controllers/enrollments_controller.rb
class EnrollmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_event

  def create
    unless current_user.can_enroll_event?(@event)
      return render json: { error: "无法报名此活动" }, status: :forbidden
    end

    enrollment = @event.enrollments.build(user: current_user)
    enrollment.payment_status = :paid
    enrollment.paid_amount = @event.enrollment_fee

    if enrollment.save
      render json: {
        message: "报名成功",
        data: enrollment.as_json(include: :user)
      }, status: :created
    else
      render json: {
        error: "报名失败",
        errors: enrollment.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  private

  def set_event
    @event = ReadingEvent.find(params[:event_id])
  end
end
```

### 打卡与小红花流程

#### 打卡提交
```ruby
# app/controllers/check_ins_controller.rb
class CheckInsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_schedule
  before_action :validate_enrollment

  def create
    check_in = current_user.check_ins.build(
      reading_schedule: @schedule,
      enrollment: @enrollment,
      content: params[:content],
      word_count: params[:content].length,
      status: :normal,
      submitted_at: Time.current
    )

    if check_in.save
      render json: {
        message: "打卡成功",
        data: check_in.as_json(include: :user, methods: :has_flower)
      }, status: :created
    else
      render json: {
        error: "打卡失败",
        errors: check_in.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # 补卡
  def update
    check_in = current_user.check_ins.find(params[:id])

    unless check_in.can_makeup?
      return render json: { error: "此打卡无法补卡" }, status: :forbidden
    end

    if check_in.update(content: params[:content], word_count: params[:content].length, status: :makeup)
      render json: {
        message: "补卡成功",
        data: check_in.as_json(include: :user)
      }
    else
      render json: {
        error: "补卡失败",
        errors: check_in.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  private

  def set_schedule
    @schedule = ReadingSchedule.find(params[:schedule_id])
  end

  def validate_enrollment
    @enrollment = current_user.enrollments.find_by(reading_event: @schedule.reading_event)
    render json: { error: "您未报名此活动" }, status: :forbidden unless @enrollment
  end
end
```

#### 小红花发放
```ruby
# app/controllers/flowers_controller.rb
class FlowersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_check_in
  before_action :validate_daily_leader_permissions

  def create
    # 检查每日小红花限制
    daily_flower_count = Flower.where(
      giver: current_user,
      reading_schedule: @check_in.reading_schedule
    ).count

    if daily_flower_count >= 3
      return render json: { error: "今日小红花发放已达上限" }, status: :forbidden
    end

    flower = @check_in.build_flower(
      giver: current_user,
      recipient: @check_in.user,
      reading_schedule: @check_in.reading_schedule,
      comment: params[:comment]
    )

    if flower.save
      render json: {
        message: "小红花发放成功",
        data: flower.as_json(include: [:giver, :recipient])
      }, status: :created
    else
      render json: {
        error: "发放失败",
        errors: flower.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # 撤销小红花
  def destroy
    @flower = Flower.find(params[:id])

    unless @flower.giver == current_user
      return render json: { error: "权限不足" }, status: :forbidden
    end

    @flower.destroy
    render json: { message: "小红花已撤销" }
  end

  private

  def set_check_in
    @check_in = CheckIn.find(params[:check_in_id])
  end

  def validate_daily_leader_permissions
    unless current_user.can_manage_event_content?(@check_in.reading_schedule.reading_event, @check_in.reading_schedule)
      render json: { error: "权限不足" }, status: :forbidden
    end
  end
end
```

---

## 🛡️ 安全设计

### 认证安全

#### JWT Token 安全
```ruby
# config/initializers/jwt.rb
Rails.application.configure do
  config.x.jwt.expiration_time = 30.days
  config.x.jwt.algorithm = 'HS256'
  config.x.jwt.issuer = 'qqclub-api'
end

# app/controllers/concerns/jwt_authenticable.rb
module JwtAuthenticable
  extend ActiveSupport::Concern

  private

  def authenticate_jwt!
    token = request.headers['Authorization']&.split(' ')&.last

    unless token.present?
      return render json: { error: "缺少认证Token" }, status: :unauthorized
    end

    begin
      payload = JWT.decode(token, jwt_secret, true, algorithm: jwt_algorithm).first

      # 验证Token有效期
      if payload['exp'] < Time.current.to_i
        return render json: { error: "Token已过期" }, status: :unauthorized
      end

      # 验证用户是否存在
      @current_user = User.find_by(id: payload['user_id'])
      unless @current_user
        return render json: { error: "用户不存在" }, status: :unauthorized
      end

    rescue JWT::DecodeError, JWT::ExpiredSignature
      render json: { error: "Token无效" }, status: :unauthorized
    end
  end

  def jwt_secret
    Rails.application.credentials.jwt_secret_key
  end

  def jwt_algorithm
    Rails.application.configuration.x.jwt.algorithm
  end
end
```

### 数据验证安全

#### 输入参数验证
```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  private

  def validate_json_payload
    unless request.content_type == 'application/json'
      render json: { error: "Content-Type必须为application/json" }, status: :unsupported_media_type
    end
  end

  def sanitize_params
    # XSS防护：清理HTML内容
    params.each do |key, value|
      if value.is_a?(String) && key.to_s.include?('content')
        params[key] = ActionController::Base.helpers.sanitize(value)
      end
    end
  end

  def validate_required_fields(required_fields)
    missing_fields = required_fields.select { |field| params[field].blank? }

    if missing_fields.any?
      render json: {
        error: "缺少必要参数",
        errors: ["缺少参数: #{missing_fields.join(', ')}"]
      }, status: :bad_request
    end
  end
end
```

#### 模型级验证
```ruby
# app/models/user.rb
class User < ApplicationRecord
  # 微信相关验证
  validates :wx_openid, presence: true, uniqueness: true, length: { maximum: 255 }
  validates :wx_unionid, uniqueness: true, allow_nil: true, length: { maximum: 255 }

  # 基础信息验证
  validates :nickname, presence: true, length: { maximum: 50 }
  validates :avatar_url, format: { with: URI::regexp(%w[http https]), message: "必须是有效的URL" }, allow_blank: true

  # 敏感信息处理
  def as_json(options = {})
    super(options.merge(except: [:wx_unionid]))
  end
end

# app/models/post.rb
class Post < ApplicationRecord
  belongs_to :user

  validates :title, presence: true, length: { minimum: 1, maximum: 100 }
  validates :content, presence: true, length: { minimum: 10, maximum: 5000 }

  # 防止SQL注入
  validate :validate_content_safety

  private

  def validate_content_safety
    # 内容安全检查
    if content.match?(/<script|javascript:|on\w+\s*=/i)
      errors.add(:content, "内容包含不安全的脚本")
    end
  end
end
```

### API 安全

#### 频率限制
```ruby
# app/controllers/concerns/rate_limitable.rb
module RateLimitable
  extend ActiveSupport::Concern

  private

  def rate_limit(identifier, max_requests: 100, window: 1.hour)
    key = "rate_limit:#{identifier}:#{request.remote_ip}"

    current_count = Rails.cache.increment(key, 1, expires_in: window)

    if current_count > max_requests
      render json: {
        error: "请求过于频繁，请稍后再试",
        retry_after: window.to_i
      }, status: :too_many_requests
    end
  end

  def rate_limit_by_user(max_requests: 1000, window: 1.hour)
    return unless current_user
    rate_limit("user:#{current_user.id}", max_requests: max_requests, window: window)
  end

  def rate_limit_by_ip(max_requests: 100, window: 1.hour)
    rate_limit("ip:#{request.remote_ip}", max_requests: max_requests, window: window)
  end
end
```

#### CORS 配置
```ruby
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'https://your-domain.com'  # 生产环境域名
    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true,
      max_age: 86400
  end
end
```

---

## 📊 数据库设计

### 数据模型关系
```ruby
# app/models/user.rb
class User < ApplicationRecord
  # 关联关系
  has_many :created_events, class_name: 'ReadingEvent', foreign_key: 'leader_id', dependent: :destroy
  has_many :enrollments, dependent: :destroy
  has_many :reading_events, through: :enrollments
  has_many :check_ins, dependent: :destroy
  has_many :posts, dependent: :destroy
  has_many :flowers_given, class_name: 'Flower', foreign_key: 'giver_id', dependent: :destroy
  has_many :flowers_received, class_name: 'Flower', foreign_key: 'recipient_id', dependent: :destroy

  # 权限相关方法已在前面定义
end

# app/models/reading_event.rb
class ReadingEvent < ApplicationRecord
  belongs_to :leader, class_name: 'User'
  has_many :enrollments, dependent: :destroy
  has_many :participants, through: :enrollments, source: :user
  has_many :reading_schedules, dependent: :destroy
  has_many :check_ins, through: :reading_schedules
  has_many :flowers, through: :reading_schedules

  validates :title, :book_name, :start_date, :end_date, presence: true
  validates :start_date, comparison: { less_than_or_equal_to: :end_date }
  validates :max_participants, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validates :enrollment_fee, numericality: { greater_than_or_equal_to: 0 }

  enum status: { draft: 0, enrolling: 1, in_progress: 2, completed: 3 }
  enum approval_status: { pending: 0, approved: 1, rejected: 2 }

  # 业务方法
  def current_participants
    enrollments.count
  end

  def can_enroll?
    approval_status == 'approved' && status.in?(['enrolling', 'in_progress']) &&
    current_participants < max_participants
  end

  def service_fee
    enrollment_fee * 0.2
  end

  def deposit
    enrollment_fee * 0.8
  end
end

# app/models/enrollment.rb
class Enrollment < ApplicationRecord
  belongs_to :user
  belongs_to :reading_event
  has_many :check_ins, dependent: :destroy

  validates :user_id, uniqueness: { scope: :reading_event_id }

  enum payment_status: { unpaid: 0, paid: 1, refunded: 2 }
  enum role: { participant: 0, leader: 1 }

  # 业务计算
  def completion_rate
    total_days = reading_event.reading_schedules.count
    return 0 if total_days.zero?

    completed_days = check_ins.where.not(status: 'missed').count
    (completed_days.to_f / total_days * 100).round(2)
  end

  def refund_amount
    reading_event.deposit * (completion_rate / 100.0)
  end
end
```

### 数据库索引策略
```ruby
# db/migrate/20250101000001_create_users.rb
class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :wx_openid, null: false, index: { unique: true }
      t.string :wx_unionid, index: { unique: true }
      t.string :nickname, null: false
      t.string :avatar_url
      t.string :phone
      t.integer :role, default: 0, null: false, index: true
      t.timestamps
    end
  end
end

# db/migrate/20250101000002_create_reading_events.rb
class CreateReadingEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :reading_events do |t|
      t.references :leader, null: false, foreign_key: { to_table: :users }, index: true
      t.string :title, null: false
      t.string :book_name, null: false
      t.string :book_cover_url
      t.text :description
      t.date :start_date, null: false, index: true
      t.date :end_date, null: false
      t.integer :max_participants, default: 30
      t.decimal :enrollment_fee, precision: 8, scale: 2, default: 100.0
      t.integer :status, default: 0, null: false, index: true
      t.integer :approval_status, default: 0, null: false, index: true
      t.references :approved_by, foreign_key: { to_table: :users }
      t.datetime :approved_at
      t.timestamps
    end

    add_index :reading_events, [:status, :approval_status]
    add_index :reading_events, [:start_date, :end_date]
  end
end
```

---

## ⚡ 性能优化

### 数据库优化

#### 查询优化
```ruby
# app/controllers/posts_controller.rb
class PostsController < ApplicationController
  # 使用 includes 避免 N+1 查询
  def index
    @posts = Post.includes(:user)
                   .order(created_at: :desc)
                   .page(params[:page])
                   .per(params[:per_page] || 10)

    render json: {
      data: @posts.as_json(include: :user),
      pagination: {
        current_page: @posts.current_page,
        total_pages: @posts.total_pages,
        total_count: @posts.total_count,
        per_page: @posts.limit_value
      }
    }
  end

  # 使用 select 只选择需要的字段
  def show
    @post = Post.select(:id, :title, :content, :user_id, :created_at, :updated_at, :pinned, :hidden)
                .includes(:user, comments: :user)
                .find(params[:id])

    render json: {
      data: @post.as_json(include: {
        user: { only: [:id, :nickname, :avatar_url] },
        comments: { include: :user }
      })
    }
  end
end
```

#### 缓存策略
```ruby
# app/models/reading_event.rb
class ReadingEvent < ApplicationRecord
  # 缓存热门活动
  def self.popular_events(limit = 10)
    Rails.cache.fetch("popular_events_#{limit}", expires_in: 1.hour) do
      joins(:enrollments)
        .group('reading_events.id')
        .select('reading_events.*, COUNT(enrollments.id) as participants_count')
        .order('participants_count DESC')
        .limit(limit)
    end
  end

  # 缓存用户统计数据
  def user_stats(user_id)
    Rails.cache.fetch("event_#{id}_user_#{user_id}_stats", expires_in: 30.minutes) do
      enrollment = enrollments.find_by(user_id: user_id)
      return nil unless enrollment

      {
        completion_rate: enrollment.completion_rate,
        flowers_count: flowers_received.where(recipient_id: user_id).count,
        check_ins_count: check_ins.where(user_id: user_id).count
      }
    end
  end
end
```

### API 性能优化

#### 分页优化
```ruby
# app/controllers/concerns/paginable.rb
module Paginable
  extend ActiveSupport::Concern

  private

  def paginate(collection)
    page = [params[:page].to_i, 1].max
    per_page = [[params[:per_page].to_i, 1].max, 50].min

    paginated_collection = collection.offset((page - 1) * per_page).limit(per_page)

    {
      data: paginated_collection,
      pagination: pagination_metadata(collection, page, per_page)
    }
  end

  def pagination_metadata(collection, page, per_page)
    total_count = collection.count
    total_pages = (total_count.to_f / per_page).ceil

    {
      current_page: page,
      total_pages: total_pages,
      total_count: total_count,
      per_page: per_page,
      has_next_page: page < total_pages,
      has_prev_page: page > 1
    }
  end
end
```

#### 响应压缩
```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  # 启用响应压缩
  include ActionController::MimeResponds

  before_action :set_default_response_format

  private

  def set_default_response_format
    request.format = :json if request.format.html?
  end
end

# config/application.rb
config.middleware.use Rack::Deflater
```

---

## 🔧 部署配置

### 环境变量配置
```ruby
# config/environments/production.rb
Rails.application.configure do
  # 强制HTTPS
  config.force_ssl = true

  # 日志级别
  config.log_level = :info

  # 缓存配置
  config.cache_store = :redis_cache_store, {
    url: ENV['REDIS_URL'],
    namespace: 'qqclub_cache'
  }

  # 数据库配置
  config.database_configuration = {
    'production' => {
      'adapter' => 'postgresql',
      'encoding' => 'unicode',
      'pool' => ENV['DB_POOL'] || 5,
      'database' => ENV['DB_NAME'],
      'username' => ENV['DB_USERNAME'],
      'password' => ENV['DB_PASSWORD'],
      'host' => ENV['DB_HOST'],
      'port' => ENV['DB_PORT'],
      'sslmode' => 'require'
    }
  }
end
```

### Docker 配置
```dockerfile
# Dockerfile
FROM ruby:3.3.0-alpine

# 安装系统依赖
RUN apk add --no-cache build-base postgresql-dev tzdata

# 设置工作目录
WORKDIR /app

# 复制Gemfile
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local deployment 'true' && bundle install --without development test

# 复制应用代码
COPY . .

# 编译资源
RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile

# 设置环境变量
ENV RAILS_ENV=production
ENV RAILS_LOG_TO_STDOUT=true
ENV RAILS_SERVE_STATIC_FILES=true

# 启动应用
EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
```

---

## 📈 监控与日志

### 应用监控
```ruby
# app/controllers/concerns/monitorable.rb
module Monitorable
  extend ActiveSupport::Concern

  private

  def log_api_request
    Rails.logger.info "API Request: #{request.method} #{request.path} - User: #{current_user&.id} - IP: #{request.remote_ip}"
  end

  def log_slow_request
    start_time = Time.current
    yield
    duration = Time.current - start_time

    if duration > 1.second
      Rails.logger.warn "Slow Request: #{request.method} #{request.path} - #{duration}s"
    end
  end

  def track_error(error)
    Rails.logger.error "Error in #{controller_name}##{action_name}: #{error.message}"
    Rails.logger.error error.backtrace.join("\n")

    # 发送错误通知到监控服务
    # ErrorTrackingService.notify(error, current_user, request)
  end
end
```

### 结构化日志
```ruby
# config/environments/production.rb
Rails.application.configure do
  config.log_formatter = proc do |severity, datetime, progname, msg|
    {
      timestamp: datetime.iso8601,
      level: severity,
      service: 'qqclub-api',
      message: msg,
      request_id: request&.request_id
    }.to_json + "\n"
  end
end
```

---

## 📖 相关文档

| 文档名称 | 用途 | 深度 |
|----------|------|------|
| [ARCHITECTURE.md](./ARCHITECTURE.md) | 系统架构概览 | 产品经理级别 |
| [API_REFERENCE.md](./API_REFERENCE.md) | API 接口规格 | 前端开发者级别 |
| [DATABASE_DESIGN.md](./DATABASE_DESIGN.md) | 数据库设计详解 | DBA 级别 |
| [PERMISSIONS_GUIDE.md](./PERMISSIONS_GUIDE.md) | 权限系统使用指南 | 用户级别 |
| [TESTING_GUIDE.md](./TESTING_GUIDE.md) | 测试框架和规范 | 测试者级别 |

---

*本文档最后更新: 2025-10-16*