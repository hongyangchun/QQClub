# 小红花配额管理服务
# 负责管理用户的每日小红花配额
class FlowerQuotaService
  class << self
    # 检查用户是否可以在活动中赠送小红花（每日配额）
    def can_give_flower?(user, event, amount = 1, date = Date.current)
      return false unless user && event
      return false unless event.participants.include?(user)
      return false unless event.status.in?(['in_progress', 'approved'])

      # 检查是否是活动日
      return false unless activity_day?(event, date)

      quota = get_daily_quota(user, event, date)
      quota.can_give_flower?(amount)
    end

    # 获取用户在活动中的每日配额信息
    def get_user_daily_quota_info(user, event, date = Date.current)
      return { error: '用户或活动不存在' } unless user && event

      quota = get_daily_quota(user, event, date)

      {
        user_id: user.id,
        event_id: event.id,
        date: date,
        is_activity_day: activity_day?(event, date),
        used_flowers: quota.used_flowers,
        max_flowers: quota.max_flowers,
        remaining_flowers: quota.remaining_flowers,
        usage_percentage: quota.usage_percentage,
        can_give_more: quota.can_give_flower?(1),
        last_given_at: quota.last_given_at,
        give_count_today: quota.give_count_today,
        time_remaining: time_remaining_for_quota(date)
      }
    end

    # 获取用户在活动中的配额历史
    def get_user_quota_history(user, event, days: 7)
      return { error: '用户或活动不存在' } unless user && event

      end_date = Date.current
      start_date = end_date - days.days + 1

      quotas = []
      (start_date..end_date).each do |date|
        quota_info = get_user_daily_quota_info(user, event, date)
        quotas << quota_info
      end

      {
        user: user.as_json_for_api,
        event: event.as_json_for_api,
        period: "#{start_date} 至 #{end_date}",
        quotas: quotas
      }
    end

    # 活动开始时初始化所有参与者的每日配额
    def initialize_event_daily_quotas(event, max_flowers: 3, days: nil)
      return false unless event

      # 默认初始化活动期间的所有日期
      days ||= event.days_count

      event.participants.each do |user|
        event.start_date.upto(event.end_date) do |date|
          next if event.weekend_rest && (date.saturday? || date.sunday?)

          get_daily_quota(user, event, date, max_flowers)
        end
      end

      true
    end

    # 获取活动的每日配额统计
    def get_event_daily_quota_stats(event, date = Date.current)
      return { error: '活动不存在' } unless event

      # 获取当日的所有配额记录
      quotas = FlowerQuota.joins(:user)
                        .where(reading_event: event, quota_date: date)
                        .includes(:user)

      total_users = quotas.count
      total_used = quotas.sum(:used_flowers)
      total_max = quotas.sum(:max_flowers)
      users_with_remaining = quotas.select { |q| q.can_give_flower?(1) }.count
      users_exhausted = quotas.select { |q| q.remaining_flowers == 0 }.count

      {
        event: event.as_json_for_api,
        date: date,
        is_activity_day: activity_day?(event, date),
        statistics: {
          total_users: total_users,
          total_used: total_used,
          total_max: total_max,
          overall_usage_rate: total_max > 0 ? (total_used.to_f / total_max * 100).round(2) : 0,
          users_with_remaining: users_with_remaining,
          users_exhausted: users_exhausted
        },
        top_givers: quotas.order(give_count_today: :desc).limit(10).map do |quota|
          {
            user: quota.user.as_json_for_api,
            used_flowers: quota.used_flowers,
            give_count_today: quota.give_count_today,
            last_given_at: quota.last_given_at
          }
        end
      }
    end

    # 检查配额是否即将用完（提醒功能）
    def check_daily_quota_warning(user, event, date = Date.current, threshold: 0.8)
      return { should_warn: false } unless activity_day?(event, date)

      quota = get_daily_quota(user, event, date)
      return { should_warn: false } unless quota.max_flowers > 0

      usage_ratio = quota.used_flowers.to_f / quota.max_flowers

      if usage_ratio >= threshold
        {
          should_warn: true,
          remaining_flowers: quota.remaining_flowers,
          usage_percentage: quota.usage_percentage,
          message: "今日小红花配额即将用完，还剩余 #{quota.remaining_flowers} 朵",
          time_remaining: time_remaining_for_quota(date)
        }
      else
        {
          should_warn: false,
          remaining_flowers: quota.remaining_flowers,
          usage_percentage: quota.usage_percentage,
          time_remaining: time_remaining_for_quota(date)
        }
      end
    end

    # 使用配额（扣减数量）
    def use_quota!(user, event, amount, date = Date.current)
      quota = get_daily_quota(user, event, date)
      quota.use_flowers!(amount)
    end

    # 增加配额使用记录
    def record_quota_usage(quota, amount)
      quota.update!(
        last_given_at: Time.current,
        give_count_today: quota.give_count_today + amount
      )
    end

    private

    # 获取用户在指定日期的配额
    def get_daily_quota(user, event, date = Date.current, max_flowers = 3)
      FlowerQuota.find_or_initialize_by(
        user: user,
        reading_event: event,
        quota_date: date
      ).tap do |quota|
        if quota.new_record?
          quota.max_flowers = max_flowers
          quota.used_flowers = 0
          quota.give_count_today = 0
          quota.save!
        end
      end
    end

    # 检查指定日期是否是活动阅读日
    def activity_day?(event, date)
      return false unless event.start_date && event.end_date
      return false if date < event.start_date || date > event.end_date

      # 如果设置周末休息，跳过周末
      if event.weekend_rest && (date.saturday? || date.sunday?)
        return false
      end

      true
    end

    # 计算配额剩余时间
    def time_remaining_for_quota(date)
      return "已过期" if date < Date.current
      return "全天可用" if date > Date.current

      # 如果是今天，计算到23:59:59的剩余时间
      if date == Date.current
        end_of_day = Time.current.end_of_day
        remaining_seconds = end_of_day - Time.current
        remaining_hours = remaining_seconds / 1.hour
        "#{remaining_hours.round(1)} 小时"
      else
        "全天可用"
      end
    end
  end
end