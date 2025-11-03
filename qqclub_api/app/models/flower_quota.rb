class FlowerQuota < ApplicationRecord
  self.table_name = 'flower_quotas'

  # 关联
  belongs_to :user
  belongs_to :reading_event

  # 验证
  validates :max_flowers, numericality: { greater_than: 0 }
  validates :used_flowers, numericality: { greater_than_or_equal_to: 0 }
  validates :quota_date, presence: true

  # 作用域
  scope :for_user, ->(user) { where(user: user) }
  scope :for_event, ->(event) { where(reading_event: event) }
  scope :for_date, ->(date) { where(quota_date: date) }
  scope :current, -> { where(quota_date: Date.current) }
  scope :recent, -> { order(quota_date: :desc) }

  # 实例方法

  # 检查是否还有赠送额度
  def can_give_flower?(amount = 1)
    (used_flowers + amount) <= max_flowers
  end

  # 获取剩余可赠送数量
  def remaining_flowers
    max_flowers - used_flowers
  end

  # 使用小红花（每日配额版本）
  def use_flowers!(amount = 1)
    return false unless can_give_flower?(amount)

    transaction do
      increment!(:used_flowers, amount)
      increment!(:give_count_today, amount)
      touch(:last_given_at)
    end
    true
  end

  # 重置使用数量（每日重置）
  def reset_daily_usage!
    update!(used_flowers: 0, give_count_today: 0)
  end

  # 获取使用率
  def usage_percentage
    return 0 if max_flowers == 0
    (used_flowers.to_f / max_flowers * 100).round(2)
  end

  # 检查是否为今日配额
  def for_today?
    quota_date == Date.current
  end

  # 检查是否为活动日
  def activity_day?(event)
    event.start_date <= quota_date && quota_date <= event.end_date && !event.weekend_rest?
  end

  # 类方法

  # 获取或创建每日配额
  def self.get_or_create_daily_quota(user, event, date = Date.current, max_flowers: 3)
    find_or_create_by(user: user, reading_event: event, quota_date: date) do |quota|
      quota.max_flowers = max_flowers
      quota.used_flowers = 0
      quota.give_count_today = 0
    end
  end

  # 兼容性方法 - 为用户和活动创建或获取配额
  def self.get_or_create_quota(user, event, max_flowers: 3)
    get_or_create_daily_quota(user, event, Date.current, max_flowers)
  end

  # 检查用户每日配额
  def self.check_daily_quota(user, event, date = Date.current, amount = 1)
    quota = find_by(user: user, reading_event: event, quota_date: date)
    return { can_give: false, remaining: 0, is_activity_day: false } unless quota

    {
      can_give: quota.can_give_flower?(amount),
      remaining: quota.remaining_flowers,
      used: quota.used_flowers,
      max: quota.max_flowers,
      is_activity_day: quota.activity_day?(event),
      quota_date: quota.quota_date
    }
  end

  # 检查用户在活动中的配额（兼容性方法）
  def self.check_quota(user, event, amount = 1)
    result = check_daily_quota(user, event, Date.current, amount)
    {
      can_give: result[:can_give],
      remaining: result[:remaining],
      used: result[:used],
      max: result[:max]
    }
  end

  # 获取用户在活动中的历史配额
  def self.user_quota_history(user, event, limit: 30)
    for_user(user).for_event(event).recent.limit(limit)
  end

  # 获取活动在某日的总配额统计
  def self.daily_quota_stats(event, date = Date.current)
    quotas = for_event(event).for_date(date)
    {
      date: date,
      total_users: quotas.count,
      total_flowers_available: quotas.sum(:max_flowers),
      total_flowers_used: quotas.sum(:used_flowers),
      usage_rate: quotas.count > 0 ? (quotas.sum(:used_flowers).to_f / quotas.sum(:max_flowers) * 100).round(2) : 0
    }
  end
end