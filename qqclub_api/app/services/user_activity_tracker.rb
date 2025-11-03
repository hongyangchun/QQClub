# frozen_string_literal: true

# UserActivityTracker - 用户活动追踪服务
# 负责记录和管理用户的活动轨迹
class UserActivityTracker < ApplicationService
  include ServiceInterface

  attr_reader :user, :action_type, :details

  def initialize(user:, action_type:, details: {})
    super()
    @user = user
    @action_type = action_type
    @details = details
  end

  def call
    handle_errors do
      track_activity
    end
    self
  end

  # 类方法：便捷的活动记录方法
  def self.track(user:, action_type:, details: {})
    new(user: user, action_type: action_type, details: details).call
  end

  def self.track_post_creation(user, post)
    track(
      user: user,
      action_type: :post_created,
      details: {
        post_id: post.id,
        post_title: post.title,
        category: post.category,
        content_length: post.content&.length || 0
      }
    )
  end

  def self.track_comment_creation(user, comment)
    track(
      user: user,
      action_type: :comment_created,
      details: {
        comment_id: comment.id,
        post_id: comment.post_id,
        post_title: comment.post&.title,
        content_length: comment.content&.length || 0
      }
    )
  end

  def self.track_like_action(user, target)
    track(
      user: user,
      action_type: :like_given,
      details: {
        target_id: target.id,
        target_type: target.class.name,
        target_title: target.respond_to?(:title) ? target.title : target.class.name
      }
    )
  end

  def self.track_event_enrollment(user, event)
    track(
      user: user,
      action_type: :event_joined,
      details: {
        event_id: event.id,
        event_title: event.title,
        event_category: event.category
      }
    )
  end

  def self.track_flower_giving(user, flower)
    recipient = flower.recipient

    track(
      user: user,
      action_type: :flower_given,
      details: {
        flower_id: flower.id,
        recipient_id: recipient.id,
        recipient_name: recipient.nickname,
        message_length: flower.message&.length || 0,
        check_in_id: flower.check_in_id
      }
    )
  end

  def self.track_check_in(user, check_in)
    track(
      user: user,
      action_type: :check_in_created,
      details: {
        check_in_id: check_in.id,
        reading_schedule_id: check_in.reading_schedule_id,
        pages_read: check_in.pages_read || 0,
        reading_duration: check_in.reading_duration || 0
      }
    )
  end

  def self.track_login(user, request = nil)
    track(
      user: user,
      action_type: :login,
      details: {
        login_method: detect_login_method(request),
        ip: request&.remote_ip,
        user_agent: request&.user_agent
      }
    )
  end

  def self.track_page_view(user, path, request = nil)
    track(
      user: user,
      action_type: :page_view,
      details: {
        path: path,
        method: request&.method,
        ip: request&.remote_ip,
        user_agent: request&.user_agent,
        referer: request&.referer
      }
    )
  end

  def self.track_api_call(user, endpoint, request = nil)
    track(
      user: user,
      action_type: :api_call,
      details: {
        endpoint: endpoint,
        method: request&.method,
        ip: request&.remote_ip,
        user_agent: request&.user_agent
      }
    )
  end

  def self.track_profile_update(user, changes)
    track(
      user: user,
      action_type: :profile_updated,
      details: {
        changed_fields: changes.keys,
        changes_summary: summarize_changes(changes)
      }
    )
  end

  def self.track_settings_change(user, setting_key, old_value, new_value)
    track(
      user: user,
      action_type: :settings_changed,
      details: {
        setting_key: setting_key,
        old_value: sanitize_value(old_value),
        new_value: sanitize_value(new_value)
      }
    )
  end

  # 批量活动记录
  def self.track_batch_activities(user, activities)
    activities_to_create = activities.map do |activity_data|
      {
        user: user,
        action_type: activity_data[:action_type],
        details: activity_data[:details].merge(
          timestamp: Time.current.iso8601,
          batch_id: SecureRandom.uuid
        )
      }
    end

    UserActivity.insert_all(activities_to_create)
  rescue => e
    Rails.logger.error "Failed to track batch activities: #{e.message}"
  end

  # 异步活动记录（用于高频率活动）
  def self.track_async(user:, action_type:, details: {})
    # 使用后台任务处理高频率活动记录
    if Rails.env.production?
      ActivityTrackingJob.perform_later(
        user_id: user.id,
        action_type: action_type,
        details: details
      )
    else
      # 开发环境直接记录
      track(user: user, action_type: action_type, details: details)
    end
  end

  # 获取用户活动统计
  def self.get_user_stats(user, period = :week)
    UserActivity.activity_stats(user, period)
  end

  # 获取用户活跃度趋势
  def self.get_activity_trend(user, days = 7)
    UserActivity.activity_trend(user, days)
  end

  # 获取用户活跃度评分
  def self.get_activity_score(user)
    UserActivity.activity_score(user)
  end

  # 获取推荐内容（基于活动历史）
  def self.get_recommendations(user, limit = 5)
    # 基于用户活动历史生成推荐
    recent_activities = UserActivity.recent_activities(user, 50)

    # 分析用户兴趣偏好
    interests = analyze_user_interests(recent_activities)

    # 基于兴趣生成推荐
    generate_recommendations_from_interests(interests, limit)
  end

  # 清理旧活动记录
  def self.cleanup_old_activities(days_to_keep = 90)
    UserActivity.cleanup_old_activities(days_to_keep)
  end

  private

  def track_activity
    return false unless user
    return false unless action_type.present?

    # 限制高频活动的记录频率
    if should_throttle_activity?
      Rails.logger.debug "Throttled activity: #{action_type} for user #{user.id}"
      return false
    end

    # 创建活动记录
    activity = UserActivity.create!(
      user: user,
      action_type: action_type,
      details: sanitized_details
    )

    # 触发相关的后台任务
    trigger_post_activity_tasks(activity)

    activity
  rescue => e
    Rails.logger.error "Failed to track activity: #{e.message}"
    false
  end

  def sanitized_details
    # 清理敏感信息
    sanitized = details.dup

    # 移除敏感字段
    sanitized.delete(:password)
    sanitized.delete(:token)
    sanitized.delete(:session_id)

    # 限制字段长度
    sanitized.each do |key, value|
      if value.is_a?(String) && value.length > 1000
        sanitized[key] = "#{value[0..997]}..."
      end
    end

    sanitized
  end

  def should_throttle_activity?
    # 对某些高频率活动进行限流
    throttle_rules = {
      'page_view' => { count: 100, window: 1.hour },
      'api_call' => { count: 200, window: 1.hour }
    }

    rule = throttle_rules[action_type.to_s]
    return false unless rule

    recent_count = UserActivity.where(
      user: user,
      action_type: action_type
    ).where('created_at > ?', rule[:window].ago).count

    recent_count >= rule[:count]
  end

  def trigger_post_activity_tasks(activity)
    # 根据活动类型触发不同的后台任务
    case activity.action_type
    when 'post_created'
      # 更新用户统计缓存
      update_user_stats_cache
      # 可能触发推荐算法更新
      trigger_recommendation_update
    when 'like_given', 'comment_created'
      # 更新内容热度
      update_content_popularity(activity)
    end
  end

  def update_user_stats_cache
    # 更新用户统计的缓存
    Rails.cache.delete("user_stats_#{user.id}")
  end

  def trigger_recommendation_update
    # 异步触发推荐算法更新
    if Rails.env.production?
      RecommendationUpdateJob.perform_later(user.id)
    end
  end

  def update_content_popularity(activity)
    # 更新内容热度缓存
    target_id = activity.details['target_id'] || activity.details['post_id']
    target_type = activity.details['target_type'] || 'Post'

    if target_id
      Rails.cache.delete("content_stats_#{target_type}_#{target_id}")
    end
  end

  def self.detect_login_method(request)
    return 'unknown' unless request

    auth_header = request.headers['Authorization']
    if auth_header&.start_with?('Bearer ')
      'jwt_token'
    elsif request.params[:session]
      'session'
    else
      'unknown'
    end
  end

  def self.summarize_changes(changes)
    changes.map do |field, values|
      old_value, new_value = values
      "#{field}: #{sanitize_value(old_value)} → #{sanitize_value(new_value)}"
    end.join(', ')
  end

  def self.sanitize_value(value)
    return '[blank]' if value.blank?
    return '[password]' if value.to_s.match?(/password/i)
    return '[email]' if value.to_s.match?(/\A[^@\s]+@[^@\s]+\z/)
    return '[token]' if value.to_s.length > 50 && value.to_s.match?(/\A[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\z/)

    if value.is_a?(String) && value.length > 50
      "#{value[0..47]}..."
    else
      value.to_s
    end
  end

  def self.analyze_user_interests(activities)
    interests = {}

    activities.each do |activity|
      case activity.action_type
      when 'post_created', 'like_given', 'comment_created'
        category = activity.details['category']
        interests[category] = (interests[category] || 0) + 1
      when 'event_joined'
        category = activity.details['event_category']
        interests[category] = (interests[category] || 0) + 2
      end
    end

    interests.sort_by { |_, score| -score }.first(10)
  end

  def self.generate_recommendations_from_interests(interests, limit)
    return [] if interests.empty?

    # 基于兴趣生成推荐内容
    top_categories = interests.first(3).map(&:first)

    recommendations = []

    top_categories.each do |category|
      # 推荐相关帖子
      posts = Post.where(category: category)
        .where('created_at > ?', 7.days.ago)
        .order(likes_count: :desc)
        .limit(2)

      posts.each do |post|
        recommendations << {
          type: 'post',
          title: post.title,
          description: "您可能感兴趣的#{category}内容",
          url: "/posts/#{post.id}",
          score: interests[category]
        }
      end
    end

    recommendations.sort_by { |rec| -rec[:score] }.first(limit)
  end
end