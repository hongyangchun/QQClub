# frozen_string_literal: true

# UserExperienceEnhancer - 用户体验增强模块
# 为控制器添加用户体验增强功能
module UserExperienceEnhancer
  extend ActiveSupport::Concern

  # 在响应中添加用户体验增强数据
  def enhance_response_with_user_experience(response_data = nil)
    return response_data unless current_user

    enhanced_data = response_data || {}
    user_experience_data = build_user_experience_data

    # 将用户体验数据添加到响应中
    if enhanced_data.is_a?(Hash)
      enhanced_data[:user_experience] = user_experience_data
    else
      # 如果响应数据不是Hash，包装它
      enhanced_data = {
        data: enhanced_data,
        user_experience: user_experience_data
      }
    end

    enhanced_data
  end

  private

  def build_user_experience_data
    enhancer_service = UserExperienceEnhancerService.new(
      user: current_user,
      request_context: build_request_context,
      enhancement_options: enhancement_options
    )

    enhancer_service.call

    {
      recommendations: enhancer_service.recommendations,
      personalization: enhancer_service.personalization_data,
      quick_actions: enhancer_service.send(:generate_quick_actions),
      contextual_tips: enhancer_service.send(:generate_contextual_tips),
      preferences: build_preferences_data,
      notifications: build_notifications_data
    }
  end

  def build_request_context
    {
      action: action_name,
      controller: controller_name,
      current_page: detect_current_page,
      user_agent: request.user_agent,
      timestamp: Time.current,
      parameters: filtered_parameters
    }
  end

  def enhancement_options
    {
      include_recommendations: should_include_recommendations?,
      include_personalization: should_include_personalization?,
      include_quick_actions: should_include_quick_actions?,
      include_tips: should_include_tips?
    }
  end

  def should_include_recommendations?
    # 在主页、列表页面显示推荐
    %w[index show].include?(action_name) && !request.format.json?
  end

  def should_include_personalization?
    # 为认证用户显示个性化内容
    current_user.present?
  end

  def should_include_quick_actions?
    # 在所有页面显示快捷操作
    current_user.present?
  end

  def should_include_tips?
    # 根据时间和用户行为显示提示
    contextual_tips_enabled?
  end

  def contextual_tips_enabled?
    # 可以基于用户设置或系统配置
    current_user&.preferences&.dig('contextual_tips_enabled') != false
  end

  def detect_current_page
    case controller_name
    when 'posts'
      'posts'
    when 'reading_events'
      'events'
    when 'users'
      'profile'
    when 'notifications'
      'notifications'
    else
      'other'
    end
  end

  def build_preferences_data
    return {} unless current_user

    {
      theme: current_user.preferences&.dig('theme') || 'light',
      language: current_user.preferences&.dig('language') || 'zh-CN',
      notifications_enabled: current_user.preferences&.dig('notifications_enabled') != false,
      auto_refresh: current_user.preferences&.dig('auto_refresh') || false
    }
  end

  def build_notifications_data
    return {} unless current_user

    unread_count = current_user.notifications.where(read: false).count
    recent_notifications = current_user.notifications
      .order(created_at: :desc)
      .limit(5)

    {
      unread_count: unread_count,
      recent_count: recent_notifications.count,
      has_new_notifications: unread_count > 0,
      notification_types: get_notification_types(recent_notifications)
    }
  end

  def get_notification_types(notifications)
    types = notifications.pluck(:notification_type)
    types.group_by(&:itself).transform_values(&:count)
  end

  def filtered_parameters
    # 过滤敏感参数
    allowed_params = %w[page per_page sort_by sort_direction category status]
    params.to_h.select { |key, _| allowed_params.include?(key.to_s) }
  end

  # 重写渲染方法以自动添加用户体验增强
  def render_success_response(data: nil, message: 'Success', meta: {})
    enhanced_data = enhance_response_with_user_experience(data)
    super(data: enhanced_data, message: message, meta: meta)
  end

  def render_paginated_response(data:, pagination:, message: 'Success', meta: {})
    enhanced_data = enhance_response_with_user_experience(data)
    super(data: enhanced_data, pagination: pagination, message: message, meta: meta)
  end

  # 渲染增强的用户体验响应
  def render_enhanced_response(data: nil, message: 'Success', status: :ok)
    enhanced_response = {
      success: true,
      message: message,
      data: enhance_response_with_user_experience(data),
      timestamp: Time.current.iso8601,
      request_id: @request_id
    }

    render json: enhanced_response, status: status
  end

  # 添加用户行为追踪
  def track_user_action(action_type, details = {})
    return unless current_user

    UserActivityTracker.track(
      user: current_user,
      action_type: action_type,
      details: details.merge(
        controller: controller_name,
        action: action_name,
        ip: request.remote_ip,
        user_agent: request.user_agent
      )
    )
  end

  # 记录用户偏好
  def record_user_preference(preference_key, value)
    return unless current_user

    preferences = current_user.preferences || {}
    preferences[preference_key] = value

    current_user.update(preferences: preferences)
  end

  # 获取用户最近活动
  def get_recent_user_activities(limit = 5)
    return [] unless current_user

    UserActivity.where(user: current_user)
      .order(created_at: :desc)
      .limit(limit)
  end

  # 检查用户是否为新用户
  def new_user?
    return false unless current_user
    current_user.created_at > 7.days.ago
  end

  # 检查用户是否需要引导
  def needs_onboarding?
    return false unless current_user

    # 新用户且完成度低
    new_user? && user_completion_percentage < 50
  end

  def user_completion_percentage
    return 0 unless current_user

    completion_items = [
      current_user.nickname.present?,
      current_user.avatar.present?,
      current_user.posts.count > 0,
      current_user.comments.count > 0,
      current_user.event_enrollments.count > 0
    ]

    (completion_items.count(true) * 100 / completion_items.length).round
  end

  # 检查用户是否需要鼓励
  def needs_encouragement?
    return false unless current_user

    # 长时间未活跃的用户
    last_activity = current_user.posts.maximum(:created_at) || current_user.created_at
    last_activity < 7.days.ago
  end

  # 生成鼓励消息
  def generate_encouragement_message
    return nil unless needs_encouragement?

    messages = [
      "好久不见，想念您的分享！",
      "新的精彩内容等您发现",
      "朋友们都很想念您的参与",
      "分享您的读书心得吧"
    ]

    messages.sample
  end

  # 添加个性化响应头
  def add_personalization_headers
    return unless current_user

    response.headers['X-User-Level'] = calculate_user_level.to_s
    response.headers['X-New-User'] = new_user?.to_s
    response.headers['X-Needs-Onboarding'] = needs_onboarding?.to_s
    response.headers['X-User-Timezone'] = current_user.preferences&.dig('timezone') || 'Asia/Shanghai'
  end

  def calculate_user_level
    # 简化的用户等级计算
    score = 0
    score += (current_user.posts.count * 10)
    score += (current_user.comments.count * 5)
    score += (current_user.event_enrollments.count * 15)

    case score
    when 0..50
      1
    when 51..200
      2
    when 201..500
      3
    when 501..1000
      4
    else
      5
    end
  end

  # 检查并设置用户偏好
  def set_user_preferences_if_needed
    return unless current_user

    # 如果用户没有偏好设置，设置默认值
    if current_user.preferences.blank?
      default_preferences = {
        'theme' => 'light',
        'language' => 'zh-CN',
        'timezone' => 'Asia/Shanghai',
        'notifications_enabled' => true,
        'contextual_tips_enabled' => true,
        'auto_refresh' => false
      }

      current_user.update(preferences: default_preferences)
    end
  end

  # 在每个请求开始时调用
  def enhance_user_request
    return unless current_user

    # 设置用户偏好
    set_user_preferences_if_needed

    # 添加个性化响应头
    add_personalization_headers

    # 追踪用户活动
    track_user_action("page_view", {
      path: request.path,
      method: request.method
    })
  end
end