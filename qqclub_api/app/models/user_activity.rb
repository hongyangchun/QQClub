# frozen_string_literal: true

# UserActivity - 用户活动模型
# 记录用户的各种行为和活动轨迹
class UserActivity < ApplicationRecord
  belongs_to :user

  validates :user, presence: true
  validates :action_type, presence: true
  validates :details, presence: true

  # 活动类型枚举
  enum :action_type, {
    # 内容相关
    post_created: 'post_created',
    post_updated: 'post_updated',
    post_deleted: 'post_deleted',
    comment_created: 'comment_created',
    comment_updated: 'comment_updated',
    comment_deleted: 'comment_deleted',
    like_given: 'like_given',
    like_removed: 'like_removed',

    # 活动相关
    event_joined: 'event_joined',
    event_left: 'event_left',
    event_completed: 'event_completed',
    check_in_created: 'check_in_created',
    flower_given: 'flower_given',
    flower_received: 'flower_received',

    # 社交相关
    profile_viewed: 'profile_viewed',
    user_followed: 'user_followed',
    user_unfollowed: 'user_unfollowed',

    # 系统相关
    login: 'login',
    logout: 'logout',
    password_changed: 'password_changed',
    profile_updated: 'profile_updated',
    settings_changed: 'settings_changed',

    # 页面浏览
    page_view: 'page_view',
    api_call: 'api_call'
  }

  # 作用域
  scope :recent, -> { order(created_at: :desc) }
  scope :today, -> { where(created_at: Date.current.all_day) }
  scope :this_week, -> { where(created_at: Date.current.beginning_of_week..Date.current.end_of_week) }
  scope :this_month, -> { where(created_at: Date.current.beginning_of_month..Date.current.end_of_month) }
  scope :by_action_type, ->(type) { where(action_type: type) }
  scope :by_user, ->(user) { where(user: user) }

  # 类方法：记录用户活动
  def self.track(user:, action_type:, details: {})
    return unless user

    create!(
      user: user,
      action_type: action_type,
      details: details.merge(
        timestamp: Time.current.iso8601,
        ip: details[:ip] || '0.0.0.0',
        user_agent: details[:user_agent] || 'Unknown'
      )
    )
  rescue => e
    Rails.logger.error "Failed to track user activity: #{e.message}"
  end

  # 类方法：获取用户活动统计
  def self.activity_stats(user, period = :week)
    case period
    when :day
      start_time = Date.current.beginning_of_day
      end_time = Date.current.end_of_day
    when :week
      start_time = Date.current.beginning_of_week
      end_time = Date.current.end_of_week
    when :month
      start_time = Date.current.beginning_of_month
      end_time = Date.current.end_of_month
    else
      start_time = 30.days.ago
      end_time = Time.current
    end

    activities = where(user: user)
      .where(created_at: start_time..end_time)

    {
      total_activities: activities.count,
      action_breakdown: activities.group(:action_type).count,
      most_active_day: find_most_active_day(activities),
      average_daily_activities: calculate_daily_average(activities, period)
    }
  end

  # 类方法：获取用户最近活动
  def self.recent_activities(user, limit = 10)
    where(user: user)
      .recent
      .limit(limit)
  end

  # 类方法：清理旧活动记录
  def self.cleanup_old_activities(days_to_keep = 90)
    cutoff_date = days_to_keep.days.ago

    where('created_at < ?', cutoff_date).delete_all
  end

  # 类方法：获取活动趋势
  def self.activity_trend(user, days = 7)
    end_date = Date.current
    start_date = days.days.ago.to_date

    activities = where(user: user)
      .where(created_at: start_date.beginning_of_day..end_date.end_of_day)
      .group_by_day(:created_at)
      .count

    trend_data = []
    (start_date..end_date).each do |date|
      trend_data << {
        date: date.iso8601,
        count: activities[date] || 0
      }
    end

    trend_data
  end

  # 类方法：获取用户活跃度评分
  def self.activity_score(user)
    # 基于最近30天的活动计算活跃度评分
    cutoff_date = 30.days.ago
    recent_activities = where(user: user)
      .where('created_at > ?', cutoff_date)

    score = 0

    # 内容创作得分
    content_actions = %w[post_created comment_created]
    content_score = recent_activities.where(action_type: content_actions).count * 10
    score += content_score

    # 社交互动得分
    social_actions = %w[like_given flower_given event_joined]
    social_score = recent_activities.where(action_type: social_actions).count * 5
    score += social_score

    # 登录活跃度得分
    login_actions = %w[login page_view api_call]
    login_score = [recent_activities.where(action_type: login_actions).count, 100].min
    score += login_score

    # 时间衰减因子（越近的活动权重越高）
    time_decay_factor = calculate_time_decay_factor(recent_activities)
    score = (score * time_decay_factor).round

    {
      score: score,
      level: activity_level(score),
      content_score: content_score,
      social_score: social_score,
      login_score: login_score,
      time_decay_factor: time_decay_factor
    }
  end

  # 实例方法：格式化活动描述
  def formatted_description
    case action_type
    when 'post_created'
      "发布了新帖子「#{details['post_title']}」"
    when 'comment_created'
      "评论了帖子「#{details['post_title']}」"
    when 'like_given'
      "点赞了#{details['target_type']}「#{details['target_title']}」"
    when 'event_joined'
      "参加了活动「#{details['event_title']}」"
    when 'flower_given'
      "给#{details['recipient_name']}送了一朵小红花"
    when 'login'
      "登录了系统"
    when 'page_view'
      "浏览了#{details['path']}页面"
    else
      action_type.humanize
    end
  end

  # 实例方法：获取活动图标
  def icon
    case action_type
    when 'post_created', 'post_updated'
      'edit'
    when 'comment_created', 'comment_updated'
      'comment'
    when 'like_given'
      'heart'
    when 'event_joined', 'event_completed'
      'calendar'
    when 'flower_given'
      'flower'
    when 'login'
      'log-in'
    when 'page_view'
      'eye'
    else
      'activity'
    end
  end

  # 实例方法：获取活动颜色
  def color
    case action_type
    when 'post_created', 'comment_created', 'like_given'
      'blue'
    when 'event_joined', 'event_completed'
      'green'
    when 'flower_given'
      'red'
    when 'login'
      'gray'
    else
      'default'
    end
  end

  # 实例方法：是否为重要活动
  def important?
    %w[post_created event_joined flower_given].include?(action_type)
  end

  # 实例方法：获取活动链接
  def activity_link
    case action_type
    when 'post_created', 'post_updated'
      "/posts/#{details['post_id']}" if details['post_id']
    when 'comment_created'
      "/posts/#{details['post_id']}#comment-#{details['comment_id']}" if details['post_id'] && details['comment_id']
    when 'event_joined', 'event_completed'
      "/events/#{details['event_id']}" if details['event_id']
    when 'profile_viewed'
      "/users/#{details['profile_user_id']}" if details['profile_user_id']
    else
      nil
    end
  end

  private

  def self.find_most_active_day(activities)
    day_counts = activities.group_by_day(:created_at).count
    return nil if day_counts.empty?

    most_active_date = day_counts.max_by { |_, count| count }&.first
    return nil unless most_active_date

    {
      date: most_active_date.iso8601,
      count: day_counts[most_active_date]
    }
  end

  def self.calculate_daily_average(activities, period)
    case period
    when :day
      activities.count.to_f
    when :week
      (activities.count / 7.0).round(2)
    when :month
      (activities.count / 30.0).round(2)
    else
      (activities.count / 7.0).round(2)
    end
  end

  def self.calculate_time_decay_factor(activities)
    return 0.0 if activities.empty?

    # 计算时间衰减因子，越近的活动权重越高
    total_weight = 0.0
    total_activities = activities.count

    activities.each do |activity|
      days_ago = (Time.current - activity.created_at) / 1.day
      weight = Math.exp(-days_ago / 7.0)  # 7天衰减常数
      total_weight += weight
    end

    (total_weight / total_activities).round(3)
  end

  def self.activity_level(score)
    case score
    when 0..10
      'inactive'
    when 11..50
      'low'
    when 51..150
      'moderate'
    when 151..300
      'high'
    else
      'very_high'
    end
  end
end