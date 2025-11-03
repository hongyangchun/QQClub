# QQClub 共读活动模块 - 实施指南

## 📋 文档说明

**目标读者**: 项目管理者、开发团队、测试工程师、运维人员
**文档内容**: 开发计划、实施步骤、测试策略、部署指南

---

## 🎯 开发优先级

### 第一阶段：核心功能 (MVP)
**目标**: 建立基础的共读活动流程

**核心功能清单**:
- [ ] 活动创建流程 (3步骤向导)
- [ ] 用户报名/围观机制
- [ ] 每日打卡功能
- [ ] 基础领读功能
- [ ] 小红花发放系统
- [ ] 简单的活动统计

**技术实现重点**:
```ruby
# 优先实现的模型和关联
class ReadingEvent < ApplicationRecord
  enum :status, { draft: 0, enrolling: 1, in_progress: 2, completed: 3 }
  enum :activity_mode, { note_checkin: 0, free_discussion: 1, video_conference: 2, offline_meeting: 3 }
  enum :fee_type, { free: 0, deposit: 1, paid: 2 }

  has_many :reading_schedules, -> { order(:day_number) }
  has_many :event_enrollments
end

class EventEnrollment < ApplicationRecord
  enum :enrollment_type, { participant: 0, observer: 1 }
  enum :status, { enrolled: 0, completed: 1, cancelled: 2 }
end
```

### 第二阶段：高级功能
**目标**: 完善用户体验和激励机制

**功能清单**:
- [ ] 证书生成系统
- [ ] 活动统计分析
- [ ] 领读内容模板
- [ ] 费用结算功能
- [ ] 通知系统

### 第三阶段：优化功能
**目标**: 性能优化和用户体验提升

**功能清单**:
- [ ] 移动端优化
- [ ] 缓存系统
- [ ] 数据导出
- [ ] 高级统计分析
- [ ] 会员制支持

---

## 📅 实施时间线

### 第1-2周：基础架构搭建
**数据库设计**:
```bash
# 创建迁移文件
rails g model ReadingEvent title:string book_name:string activity_mode:integer status:integer fee_type:integer
rails g model ReadingSchedule reading_event:integer day_number:date reading_progress:string
rails g model EventEnrollment reading_event:integer user:integer enrollment_type:integer status:integer
rails g model CheckIn user:integer reading_schedule:integer content:text word_count:integer
rails g model Flower check_in:integer giver:integer recipient:integer comment:string

# 执行迁移
rails db:migrate
```

**基础控制器**:
```ruby
# app/controllers/api/reading_events_controller.rb
class Api::ReadingEventsController < Api::BaseController
  before_action :authenticate_user!

  def index
    @events = ReadingEvent.includes(:leader, :event_enrollments)
                .filter_by_status(params[:status])
                .page(params[:page])
                .per(params[:per_page] || 10)

    render_success(data: @events.map(&:to_api_hash))
  end

  def create
    @event = ReadingEvent.new(event_params)
    @event.leader = current_user

    if @event.save
      render_success(data: @event.to_api_hash, message: '活动创建成功')
    else
      render_error(message: '活动创建失败', errors: @event.errors.full_messages)
    end
  end

  private

  def event_params
    params.require(:reading_event).permit(:title, :book_name, :description,
                                         :activity_mode, :fee_type, :fee_amount,
                                         :max_participants, :start_date, :end_date)
  end
end
```

### 第3-4周：核心业务逻辑
**完成率计算服务**:
```ruby
# app/services/completion_rate_calculator.rb
class CompletionRateCalculator
  def self.calculate_for_user(user, event)
    schedules = event.reading_schedules
    total_days = calculate_total_reading_days(schedules, event)

    return 0.0 if total_days == 0

    # 获取打卡次数
    check_ins_count = user.check_ins
      .where(reading_schedule: schedules)
      .where.not(status: 'supplement')
      .count

    # 获取担任领读天数
    leader_days_count = user.daily_leading_assignments
      .where(reading_schedule: schedules)
      .count

    completed_days = check_ins_count + leader_days_count
    (completed_days.to_f / total_days * 100).round(2)
  end

  private

  def self.calculate_total_reading_days(schedules, event)
    return schedules.count unless event.weekend_rest?

    # 排除周末
    schedules.select { |schedule| !schedule.date.saturday? && !schedule.date.sunday? }.count
  end
end
```

**费用结算服务**:
```ruby
# app/services/fee_settlement_service.rb
class FeeSettlementService
  def self.settle_event(event)
    return if event.fee_type == 'free'

    event.enrollments.participants.find_each do |enrollment|
      settlement_amount = calculate_settlement_amount(enrollment)

      if settlement_amount > 0
        create_refund_record(enrollment, settlement_amount)
        # TODO: 集成支付系统进行实际退款
      end
    end

    # 支付小组长报酬
    pay_leader_reward(event)
  end

  def self.calculate_settlement_amount(enrollment)
    event = enrollment.reading_event
    user = enrollment.user

    return 0.0 if event.fee_type == 'paid'

    completion_rate = CompletionRateCalculator.calculate_for_user(user, event)
    completion_standard = event.completion_standard || 80

    if completion_rate >= completion_standard
      fee_amount = event.fee_amount || 0.0
      leader_reward_percentage = event.leader_reward_percentage || 20.0
      leader_reward = fee_amount * (leader_reward_percentage / 100.0)

      # 退还押金池部分
      fee_amount - leader_reward
    else
      0.0
    end
  end
end
```

### 第5-6周：前端界面开发
**小程序页面结构**:
```
qqclub-miniprogram/
├── pages/
│   ├── event/
│   │   ├── create.js          # 活动创建页面
│   │   ├── create.wxml
│   │   ├── create.wxss
│   │   ├── list.js            # 活动列表页面
│   │   ├── list.wxml
│   │   ├── list.wxss
│   │   ├── detail.js          # 活动详情页面
│   │   ├── detail.wxml
│   │   ├── detail.wxss
│   │   ├── checkin.js         # 打卡页面
│   │   ├── checkin.wxml
│   │   └── checkin.wxss
│   └── profile/
│       ├── certificates.js    # 我的证书页面
│       └── statistics.js      # 统计页面
```

**API 工具类**:
```javascript
// utils/reading-event-api.js
const ReadingEventAPI = {
  // 获取活动列表
  getEvents(params = {}) {
    return wx.request({
      url: `${app.globalData.apiBaseUrl}/reading_events`,
      method: 'GET',
      data: params,
      header: this.getAuthHeader()
    });
  },

  // 创建活动
  createEvent(eventData) {
    return wx.request({
      url: `${app.globalData.apiBaseUrl}/reading_events`,
      method: 'POST',
      data: { reading_event: eventData },
      header: this.getAuthHeader()
    });
  },

  // 报名活动
  enrollEvent(eventId) {
    return wx.request({
      url: `${app.globalData.apiBaseUrl}/reading_events/${eventId}/enroll`,
      method: 'POST',
      header: this.getAuthHeader()
    });
  },

  // 提交打卡
  submitCheckIn(eventId, scheduleId, content) {
    return wx.request({
      url: `${app.globalData.apiBaseUrl}/reading_events/${eventId}/schedules/${scheduleId}/check_ins`,
      method: 'POST',
      data: { check_in: { content } },
      header: this.getAuthHeader()
    });
  },

  getAuthHeader() {
    const token = wx.getStorageSync('auth_token');
    return {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    };
  }
};
```

---

## 🧪 测试策略

### 单元测试
**模型测试**:
```ruby
# test/models/reading_event_test.rb
require 'test_helper'

class ReadingEventTest < ActiveSupport::TestCase
  test "should be valid with valid attributes" do
    event = build(:reading_event)
    assert event.valid?
  end

  test "should not be valid without title" do
    event = build(:reading_event, title: nil)
    assert_not event.valid?
    assert_includes event.errors[:title], "不能为空"
  end

  test "should calculate completion rates correctly" do
    event = create(:reading_event, :with_schedules)
    user = create(:user)

    # 创建打卡记录
    event.reading_schedules.first(3).each do |schedule|
      create(:check_in, user: user, reading_schedule: schedule)
    end

    completion_rate = CompletionRateCalculator.calculate_for_user(user, event)
    expected_rate = (3.0 / event.reading_schedules.count * 100).round(2)

    assert_equal expected_rate, completion_rate
  end
end
```

**服务测试**:
```ruby
# test/services/fee_settlement_service_test.rb
require 'test_helper'

class FeeSettlementServiceTest < ActiveSupport::TestCase
  test "should calculate correct refund amount for completing participant" do
    event = create(:reading_event, fee_type: 'deposit', fee_amount: 100.0,
                   leader_reward_percentage: 20.0, completion_standard: 80.0)
    user = create(:user)
    enrollment = create(:event_enrollment, user: user, reading_event: event)

    # 模拟完成率 85%
    mock_completion_rate = 85.0
    CompletionRateCalculator.stubs(:calculate_for_user).returns(mock_completion_rate)

    refund_amount = FeeSettlementService.calculate_settlement_amount(enrollment)

    # 100 - 20% = 80元应退还
    assert_equal 80.0, refund_amount
  end

  test "should calculate zero refund for non-completing participant" do
    event = create(:reading_event, fee_type: 'deposit', fee_amount: 100.0, completion_standard: 80.0)
    user = create(:user)
    enrollment = create(:event_enrollment, user: user, reading_event: event)

    # 模拟完成率 60%
    mock_completion_rate = 60.0
    CompletionRateCalculator.stubs(:calculate_for_user).returns(mock_completion_rate)

    refund_amount = FeeSettlementService.calculate_settlement_amount(enrollment)

    assert_equal 0.0, refund_amount
  end
end
```

### 集成测试
**API测试**:
```ruby
# test/controllers/api/reading_events_controller_test.rb
require 'test_helper'

class Api::ReadingEventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @auth_headers = auth_headers_for(@user)
  end

  test "should get reading events list" do
    create_list(:reading_event, 3)

    get api_reading_events_url, headers: @auth_headers

    assert_response :success
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert_equal 3, response_data['data'].length
  end

  test "should create reading event" do
    event_params = {
      title: '《三体》读书会',
      book_name: '三体',
      activity_mode: 'note_checkin',
      fee_type: 'deposit',
      fee_amount: 100.0,
      max_participants: 25
    }

    post api_reading_events_url, params: { reading_event: event_params }, headers: @auth_headers

    assert_response :success
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert_equal '《三体》读书会', response_data['data']['title']
  end

  test "should enroll in reading event" do
    event = create(:reading_event, status: 'enrolling')

    post enroll_api_reading_event_url(event), headers: @auth_headers

    assert_response :success
    response_data = JSON.parse(response.body)
    assert response_data['success']

    enrollment = EventEnrollment.find_by(user: @user, reading_event: event)
    assert enrollment.present?
    assert_equal 'participant', enrollment.enrollment_type
  end
end
```

### 前端测试
**小程序组件测试**:
```javascript
// pages/event/create/create.test.js
const createPage = require('./create.js')

describe('活动创建页面', () => {
  let page

  beforeEach(() => {
    page = createPage()
  })

  it('应该正确初始化页面数据', () => {
    expect(page.data.currentStep).toBe(1)
    expect(page.data.feeType).toBe('free')
    expect(page.data.activityMode).toBe('note_checkin')
  })

  it('应该验证必填字段', () => {
    // 测试标题验证
    page.setData({ title: '' })
    expect(page.validateStep1()).toBe(false)

    page.setData({ title: '《三体》读书会' })
    expect(page.validateStep1()).toBe(true)
  })

  it('应该正确计算活动天数', () => {
    page.setData({
      startDate: '2025-11-01',
      endDate: '2025-11-07'
    })

    expect(page.data.totalDays).toBe(7)
  })
})
```

---

## 🚀 部署指南

### 环境配置
**生产环境变量**:
```bash
# .env.production
RAILS_ENV=production
DATABASE_URL=postgresql://user:password@localhost/qqclub_production
REDIS_URL=redis://localhost:6379/1
SECRET_KEY_BASE=your_secret_key_base
JWT_SECRET=your_jwt_secret

# 文件存储
FILE_STORAGE=aliyun_oss
ALIYUN_OSS_BUCKET=qqclub-files
ALIYUN_OSS_REGION=oss-cn-hangzhou
ALIYUN_OSS_ACCESS_KEY_ID=your_access_key
ALIYUN_OSS_ACCESS_KEY_SECRET=your_secret_key

# 微信小程序配置
WECHAT_APP_ID=your_wechat_app_id
WECHAT_APP_SECRET=your_wechat_app_secret
```

### 数据库迁移
```bash
# 1. 备份现有数据库
pg_dump qqclub_production > backup_$(date +%Y%m%d_%H%M%S).sql

# 2. 执行新迁移
rails db:migrate RAILS_ENV=production

# 3. 验证数据完整性
rails db:seed RAILS_ENV=production
rails runner "puts 'Reading events count: ' + ReadingEvent.count"
```

### 服务部署
**Docker 配置**:
```dockerfile
# Dockerfile
FROM ruby:3.1-alpine

# 安装依赖
RUN apk add --no-cache build-base postgresql-dev tzdata

WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle install --deployment --without development test

COPY . .

# 预编译资产
RUN SECRET_KEY_BASE=dummy rails assets:precompile

EXPOSE 3000
CMD ["rails", "server", "-b", "0.0.0.0"]
```

**Docker Compose**:
```yaml
# docker-compose.production.yml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - RAILS_ENV=production
      - DATABASE_URL=postgresql://postgres:password@db:5432/qqclub_production
    depends_on:
      - db
      - redis
    volumes:
      - ./storage:/app/storage

  db:
    image: postgres:14
    environment:
      POSTGRES_DB: qqclub_production
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - app

volumes:
  postgres_data:
  redis_data:
```

### 监控和日志
**应用监控配置**:
```ruby
# config/initializers/monitoring.rb
Rails.application.configure do
  # 错误监控
  config.exceptions_app = self.routes

  # 性能监控
  config.log_level = :info
  config.log_tags = [:request_id, :user_id]

  # 健康检查
  config.after_initialize do
    Rails.logger.info "QQClub 共读活动模块启动成功"
  end
end

# app/controllers/concerns/health_check.rb
module HealthCheck
  extend ActiveSupport::Concern

  def health_check
    render json: {
      status: 'healthy',
      timestamp: Time.current,
      version: Rails.application.config.x.version,
      database: check_database_connection,
      redis: check_redis_connection
    }
  end

  private

  def check_database_connection
    ActiveRecord::Base.connection.execute('SELECT 1')
    'connected'
  rescue
    'disconnected'
  end

  def check_redis_connection
    Rails.cache.read('health_check') || Rails.cache.write('health_check', 'ok')
    'connected'
  rescue
    'disconnected'
  end
end
```

---

## 📈 性能优化

### 数据库优化
**索引策略**:
```sql
-- 活动查询优化
CREATE INDEX idx_reading_events_status ON reading_events(status);
CREATE INDEX idx_reading_events_leader_id ON reading_events(leader_id);
CREATE INDEX idx_reading_events_activity_mode ON reading_events(activity_mode);
CREATE INDEX idx_reading_events_fee_type ON reading_events(fee_type);

-- 用户报名查询优化
CREATE INDEX idx_event_enrollments_user_event ON event_enrollments(user_id, reading_event_id);
CREATE INDEX idx_event_enrollments_status ON event_enrollments(status);

-- 打卡查询优化
CREATE INDEX idx_check_ins_user_schedule ON check_ins(user_id, reading_schedule_id);
CREATE INDEX idx_check_ins_submitted_at ON check_ins(submitted_at);

-- 复合索引
CREATE INDEX idx_reading_events_status_dates ON reading_events(status, start_date, end_date);
CREATE INDEX idx_schedules_leader_date ON reading_schedules(daily_leader_id, date);
```

### 缓存策略
**Redis 缓存配置**:
```ruby
# app/models/concerns/cacheable.rb
module Cacheable
  extend ActiveSupport::Concern

  def cache_key(prefix, *args)
    "#{prefix}_#{id}_#{args.join('_')}"
  end

  def cache_fetch(key, expires_in: 1.hour, &block)
    Rails.cache.fetch(key, expires: expires_in, &block)
  end
end

# app/models/reading_event.rb
class ReadingEvent < ApplicationRecord
  include Cacheable

  def participants_count
    cache_fetch('participants_count', expires_in: 10.minutes) do
      event_enrollments.participants.count
    end
  end

  def completion_statistics
    cache_fetch('completion_stats', expires_in: 1.hour) do
      calculate_completion_statistics
    end
  end

  def invalidate_cache
    Rails.cache.delete_matched("reading_events_#{id}_*")
  end
end
```

### API 响应优化
**分页和预加载**:
```ruby
# app/controllers/api/reading_events_controller.rb
class Api::ReadingEventsController < Api::BaseController
  def index
    @events = ReadingEvent.includes(:leader, :reading_schedules)
                .filter_by_status(params[:status])
                .filter_by_mode(params[:activity_mode])
                .page(params[:page])
                .per(params[:per_page] || 10)

    render_success(
      data: @events.map(&:to_api_hash_with_details),
      pagination: pagination_meta(@events)
    )
  end

  private

  def pagination_meta(collection)
    {
      current_page: collection.current_page,
      total_pages: collection.total_pages,
      total_count: collection.total_count,
      per_page: collection.limit_value
    }
  end
end
```

---

## 🔧 维护和更新

### 数据备份策略
```bash
#!/bin/bash
# scripts/backup_reading_events.sh

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups/qqclub"

# 创建备份目录
mkdir -p $BACKUP_DIR

# 备份共读活动相关表
pg_dump -h localhost -U postgres -d qqclub_production \
  -t reading_events \
  -t reading_schedules \
  -t event_enrollments \
  -t check_ins \
  -t flowers \
  -t participation_certificates \
  > "${BACKUP_DIR}/reading_events_${DATE}.sql"

# 压缩备份文件
gzip "${BACKUP_DIR}/reading_events_${DATE}.sql"

# 保留最近30天的备份
find "${BACKUP_DIR}" -name "reading_events_*.sql.gz" -mtime +30 -delete

echo "备份完成: reading_events_${DATE}.sql.gz"
```

### 版本发布流程
```bash
#!/bin/bash
# scripts/deploy_reading_events.sh

echo "开始部署共读活动模块..."

# 1. 拉取最新代码
git pull origin main

# 2. 运行测试
bundle exec rails test test/models/reading_event_test.rb
bundle exec rails test test/controllers/api/reading_events_controller_test.rb

# 3. 数据库迁移
bundle exec rails db:migrate RAILS_ENV=production

# 4. 预编译资产
bundle exec rails assets:precompile RAILS_ENV=production

# 5. 重启服务
docker-compose restart app

# 6. 验证部署
curl -f http://localhost:3000/api/health || exit 1

echo "共读活动模块部署成功！"
```

---

## 📊 成功指标

### 技术指标
- **API 响应时间**: < 200ms (95th percentile)
- **数据库查询时间**: < 100ms (average)
- **缓存命中率**: > 80%
- **系统可用性**: > 99.5%
- **代码覆盖率**: > 80%

### 业务指标
- **活动创建成功率**: > 95%
- **用户报名成功率**: > 98%
- **打卡提交成功率**: > 99%
- **费用结算准确率**: 100%
- **证书生成成功率**: > 95%

---

## 🆘 故障排除

### 常见问题
**数据库连接问题**:
```ruby
# lib/tasks/database_health_check.rake
task database_health_check: :environment do
  begin
    ActiveRecord::Base.connection.execute('SELECT 1')
    puts "✅ 数据库连接正常"
  rescue => e
    puts "❌ 数据库连接失败: #{e.message}"
    exit 1
  end

  # 检查表是否存在
  required_tables = %w[reading_events reading_schedules event_enrollments check_ins flowers]
  missing_tables = required_tables - ActiveRecord::Base.connection.tables

  if missing_tables.any?
    puts "❌ 缺少数据表: #{missing_tables.join(', ')}"
    puts "请运行: rails db:migrate"
    exit 1
  else
    puts "✅ 所有必需数据表都存在"
  end
end
```

**性能问题诊断**:
```ruby
# app/controllers/concerns/performance_monitoring.rb
module PerformanceMonitoring
  extend ActiveSupport::Concern

  def monitor_request_performance
    start_time = Time.current

    yield

    duration = Time.current - start_time

    if duration > 1.second
      Rails.logger.warn "慢请求警告: #{request.path} 耗时 #{duration}s"
    end
  end
end
```

---

*本文档最后更新: 2025-10-17*