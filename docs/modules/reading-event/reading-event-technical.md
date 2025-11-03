# QQClub 共读活动模块 - 技术设计

## 📋 文档说明

**目标读者**: 技术负责人、架构师、后端开发者
**文档内容**: 系统架构、核心算法、技术实现细节

---

## 🏗️ 系统架构

### 整体架构
```
┌─────────────────────────────────────┐
│         微信小程序前端                │
│  ┌─────────┐  ┌─────────┐           │
│  │  活动页面│  │  用户页面│           │
│  └─────────┘  └─────────┘           │
└─────────────┬───────────────────────┘
              │ API调用
┌─────────────▼───────────────────────┐
│        Ruby on Rails 8 后端          │
│  ┌─────────┐  ┌─────────┐           │
│  │ API控制器│  │ 业务服务 │           │
│  └─────────┘  └─────────┘           │
└─────────────┬───────────────────────┘
              │ 数据访问
┌─────────────▼───────────────────────┐
│        SQLite/PostgreSQL 数据库       │
│  ┌─────────┐  ┌─────────┐           │
│  │  活动表  │  │  用户表  │           │
│  └─────────┘  └─────────┘           │
└─────────────────────────────────────┘
```

### 技术栈
- **前端**: 微信小程序原生开发
- **后端**: Ruby on Rails 8
- **数据库**: SQLite (开发) / PostgreSQL (生产)
- **认证**: JWT Token
- **缓存**: Redis (可选)
- **部署**: Docker + 云服务

### 核心设计模式

#### 1. 策略模式 - 活动模式
```ruby
class ActivityMode
  def initialize(event)
    @event = event
  end

  def calculate_completion_rate(user)
    raise NotImplementedError
  end
end

class NoteCheckinMode < ActivityMode
  def calculate_completion_rate(user)
    # 笔记打卡模式算法
  end
end
```

#### 2. 状态机模式 - 活动状态
```ruby
class ReadingEvent < ApplicationRecord
  enum :status, { draft: 0, enrolling: 1, in_progress: 2, completed: 3 }

  def start!
    update!(status: :in_progress) if can_start?
  end

  def complete!
    update!(status: :completed) if can_complete?
  end
end
```

#### 3. 观察者模式 - 状态通知
```ruby
class EventObserver
  def self.notify(event, action, data = {})
    # 发送通知逻辑
  end
end
```

---

## 🔧 核心算法设计

### 1. 随机领读算法

#### 权重分配算法
```ruby
class LeaderAssignmentService
  def self.assign_daily_leader(event, schedule)
    participants = event.participants.active

    # 排除最近3天已担任领读的用户
    recent_leaders = get_recent_leaders(event, 3)
    available_participants = participants - recent_leaders

    # 如果排除后无人可选，则从全部参与者中选择
    available_participants = participants if available_participants.empty?

    # 基于权重的随机选择
    selected_leader = weighted_random_selection(available_participants)

    # 记录分配结果
    create_daily_leading_assignment(event, schedule, selected_leader)

    # 发送通知
    notify_leader_assignment(selected_leader, schedule)

    selected_leader
  end

  private

  def self.weighted_random_selection(participants)
    # 基于历史领读次数的权重算法
    # 领读次数越少，被选中概率越高
    weights = participants.map do |participant|
      leader_count = participant.leading_assignments.count
      [participant, 1.0 / (leader_count + 1)]
    end

    total_weight = weights.sum { |_, weight| weight }
    random_value = rand * total_weight

    current_weight = 0
    weights.each do |participant, weight|
      current_weight += weight
      return participant if current_weight >= random_value
    end

    participants.last
  end
end
```

### 2. 完成率计算算法

#### 通用计算器
```ruby
class CompletionRateCalculator
  def self.calculate_for_user(user, event)
    case event.activity_mode
    when 'note_checkin'
      calculate_note_checkin_completion(user, event)
    when 'free_discussion'
      calculate_free_discussion_completion(user, event)
    when 'video_conference'
      calculate_video_conference_completion(user, event)
    when 'offline_meeting'
      calculate_offline_meeting_completion(user, event)
    else
      0.0
    end
  end

  private

  def self.calculate_note_checkin_completion(user, event)
    schedules = event.reading_schedules
    total_days = calculate_total_reading_days(schedules, event)

    return 0.0 if total_days == 0

    # 获取实际打卡次数
    check_ins_count = user.check_ins
      .where(schedule: schedules)
      .where.not(status: 'supplement')
      .count

    # 获取担任领读天数
    leader_days_count = user.daily_leading_assignments
      .where(reading_schedule: schedules)
      .count

    # 计算完成率：(打卡次数 + 担任领读天数) / 总天数
    completed_days = check_ins_count + leader_days_count
    (completed_days.to_f / total_days * 100).round(2)
  end
end
```

### 3. 费用结算算法

#### 押金退还计算
```ruby
class DepositRefundCalculator
  def self.calculate_refund_amount(user, event)
    return 0.0 if event.fee_type != 'deposit'

    completion_rate = CompletionRateCalculator.calculate_for_user(user, event)
    completion_standard = event.completion_standard || 80
    fee_amount = event.fee_amount || 0.0
    leader_reward_percentage = event.leader_reward_percentage || 20.0

    # 计算押金池金额 (总费用 - 小组长报酬)
    leader_reward = fee_amount * (leader_reward_percentage / 100.0)
    deposit_pool = fee_amount - leader_reward

    # 基于活动设定的完成率标准计算退还比例
    refund_percentage = calculate_refund_percentage(completion_rate, completion_standard)
    (deposit_pool * refund_percentage).round(2)
  end

  def self.calculate_refund_percentage(completion_rate, completion_standard)
    # 全额退还押金池：达到或超过设定的完成率标准
    return 1.0 if completion_rate >= completion_standard

    # 不退还押金池：完成率低于标准
    return 0.0
  end

  def self.calculate_leader_reward(event)
    return 0.0 if event.fee_type == 'free'

    fee_amount = event.fee_amount || 0.0
    leader_reward_percentage = event.leader_reward_percentage || 20.0

    if event.fee_type == 'deposit'
      # 押金制：按比例计算小组长报酬
      (fee_amount * leader_reward_percentage / 100.0).round(2)
    elsif event.fee_type == 'paid'
      # 收费制：全部费用作为小组长报酬
      fee_amount
    else
      0.0
    end
  end
end
```

---

## 🔐 安全设计

### 1. 认证机制
```ruby
class AuthenticationController < ApplicationController
  def authenticate_user!
    token = request.headers['Authorization']&.split(' ')&.last
    @current_user = User.find_by(auth_token: token)

    render json: { error: 'Unauthorized' }, status: :unauthorized unless @current_user
  end

  def authorize_leader!
    return render json: { error: 'Forbidden' }, status: :forbidden unless @current_user.leader?
  end
end
```

### 2. 权限检查
```ruby
class AuthorizationService
  def self.can_manage_event?(user, event)
    return true if user.admin?
    return true if event.leader == user
    false
  end

  def self.can_participate?(user, event)
    return false if event.completed?
    return true if event.enrolling?
    false
  end
end
```

### 3. 数据验证
```ruby
class ReadingEvent < ApplicationRecord
  validates :title, presence: true, length: { minimum: 5, maximum: 50 }
  validates :fee_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :max_participants, numericality: { greater_than: 0, less_than_or_equal_to: 50 }

  validate :end_date_after_start_date

  private

  def end_date_after_start_date
    return if end_date.blank? || start_date.blank?

    if end_date < start_date
      errors.add(:end_date, "必须在开始日期之后")
    end
  end
end
```

---

## 📊 性能优化

### 1. 数据库优化
```ruby
class ReadingEvent < ApplicationRecord
  # 添加索引
  has_many :reading_schedules, -> { order(:day_number) }
  has_many :enrollments, dependent: :destroy

  # 预加载关联
  def self.with_details
    includes(:leader, :enrollments => :user, :reading_schedules)
  end

  # 批量操作
  def self.batch_update_status(event_ids, status)
    where(id: event_ids).update_all(status: status)
  end
end
```

### 2. 缓存策略
```ruby
class EventCache
  def self.get_completion_rates(event_id)
    Rails.cache.fetch("event_#{event_id}_completion_rates", expires_in: 1.hour) do
      # 计算完成率逻辑
      calculate_completion_rates(event_id)
    end
  end

  def self.invalidate_event_cache(event_id)
    Rails.cache.delete("event_#{event_id}_completion_rates")
    Rails.cache.delete("event_#{event_id}_participants")
  end
end
```

### 3. 异步处理
```ruby
class EventCompletionJob < ApplicationJob
  queue_as :default

  def perform(event_id)
    event = ReadingEvent.find(event_id)

    # 异步计算完成率
    event.enrollments.find_each do |enrollment|
      completion_rate = CompletionRateCalculator.calculate_for_user(enrollment.user, event)
      enrollment.update!(completion_rate: completion_rate)
    end

    # 生成证书
    CertificateGenerator.generate_for_event(event)

    # 发送通知
    EventObserver.notify(event, :completed)
  end
end
```

---

## 🔄 API设计原则

### 1. RESTful设计
```ruby
# 资源路由设计
resources :reading_events do
  member do
    post :enroll
    delete :enroll
    post :complete
    get :statistics
    get :participants
  end

  resources :reading_schedules do
    member do
      post :assign_leader
      get :daily_leading
    end
  end

  resources :check_ins do
    member do
      post :give_flower
    end
  end
end
```

### 2. 统一响应格式
```ruby
class Api::V1::BaseController < ApplicationController
  private

  def render_success(data: nil, message: '操作成功')
    render json: {
      success: true,
      message: message,
      data: data
    }
  end

  def render_error(message: '操作失败', errors: [], status: :unprocessable_entity)
    render json: {
      success: false,
      error: message,
      errors: errors
    }, status: status
  end
end
```

### 3. 错误处理
```ruby
class ApiError < StandardError
  attr_reader :code, :message, :status

  def initialize(code:, message:, status: :unprocessable_entity)
    @code = code
    @message = message
    @status = status
    super(message)
  end
end

class ValidationError < ApiError; end
class AuthorizationError < ApiError; end
class NotFoundError < ApiError; end
```

---

## 📈 监控和日志

### 1. 应用监控
```ruby
class EventMetrics
  def self.track_event_creation(event)
    # 记录活动创建指标
    Analytics.track('event_created', {
      event_id: event.id,
      fee_type: event.fee_type,
      activity_mode: event.activity_mode
    })
  end

  def self.track_participation(enrollment)
    # 记录参与指标
    Analytics.track('user_participated', {
      event_id: enrollment.reading_event_id,
      user_id: enrollment.user_id
    })
  end
end
```

### 2. 错误监控
```ruby
class ErrorReporter
  def self.report_error(exception, context = {})
    # 发送错误报告到监控系统
    Raven.capture_exception(exception, {
      extra: context,
      tags: { component: 'reading_events' }
    })

    # 记录到日志
    Rails.logger.error "Reading Events Error: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")
  end
end
```

### 3. 业务日志
```ruby
class EventLogger
  def self.log_event_action(event, action, user, details = {})
    Rails.logger.info "Event Action: #{action}", {
      event_id: event.id,
      user_id: user.id,
      details: details,
      timestamp: Time.current
    }
  end
end
```

---

## 🚀 部署架构

### Docker化部署
```dockerfile
FROM ruby:3.1-alpine

# 安装依赖
COPY Gemfile Gemfile.lock ./
RUN bundle install

# 复制应用代码
COPY . .

# 预编译资产
RUN bundle exec rails assets:precompile

# 启动应用
CMD ["rails", "server", "-b", "0.0.0.0", "-p", "3000"]
```

### 环境配置
```ruby
# config/environments/production.rb
Rails.application.configure do
  # 数据库配置
  config.database_configuration = YAML.load_file('config/database.yml')

  # 缓存配置
  config.cache_store = :redis_cache_store, {
    url: ENV['REDIS_URL'],
    namespace: 'reading_events'
  }

  # 后台任务
  config.active_job.queue_adapter = :sidekiq

  # 日志配置
  config.log_level = :info
  config.log_tags = [:request_id]
end
```

---

## 🔧 开发工具

### 1. 测试框架
```ruby
# spec/services/leader_assignment_service_spec.rb
RSpec.describe LeaderAssignmentService do
  describe '.assign_daily_leader' do
    let(:event) { create(:reading_event) }
    let(:schedule) { create(:reading_schedule, reading_event: event) }

    it 'assigns a leader to the schedule' do
      leader = LeaderAssignmentService.assign_daily_leader(event, schedule)

      expect(leader).to be_present
      expect(schedule.reload.daily_leader).to eq(leader)
    end

    it 'avoids recent leaders' do
      # 测试避免最近担任领读的用户
    end
  end
end
```

### 2. 开发脚本
```ruby
# lib/tasks/dev_tasks.rake
namespace :dev do
  task :setup_test_data => :environment do
    # 创建测试数据
    5.times { create(:reading_event, :with_schedules) }
    puts '测试数据创建完成'
  end

  task :simulate_activity => :environment do
    # 模拟活动进行
    EventSimulationService.run
  end
end
```

---

*本文档最后更新: 2025-10-17*