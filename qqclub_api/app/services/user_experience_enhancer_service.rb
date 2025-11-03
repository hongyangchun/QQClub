# frozen_string_literal: true

# UserExperienceEnhancerService - 用户体验增强服务
# 提供各种用户体验优化功能
class UserExperienceEnhancerService < ApplicationService
  include ServiceInterface

  attr_reader :user, :request_context, :enhancement_options

  def initialize(user:, request_context: {}, enhancement_options: {})
    super()
    @user = user
    @request_context = request_context
    @enhancement_options = enhancement_options
  end

  def call
    handle_errors do
      enhance_user_experience
    end
    self
  end

  def enhanced_response
    @enhanced_response
  end

  def recommendations
    @recommendations ||= generate_recommendations
  end

  def personalization_data
    @personalization_data ||= generate_personalization_data
  end

  # 类方法：增强API响应
  def self.enhance_api_response(response_data, user: nil, request_context: {})
    return response_data unless user

    enhancer = new(
      user: user,
      request_context: request_context,
      enhancement_options: { include_recommendations: true, include_personalization: true }
    ).call

    enhanced = response_data.dup
    enhanced[:user_experience] = {
      recommendations: enhancer.recommendations,
      personalization: enhancer.personalization_data,
      quick_actions: enhancer.generate_quick_actions,
      tips: enhancer.generate_contextual_tips
    }

    enhanced
  end

  private

  def enhance_user_experience
    @enhanced_response = {
      user_preferences: get_user_preferences,
      interface_settings: get_interface_settings,
      accessibility_options: get_accessibility_options,
      contextual_help: get_contextual_help
    }
  end

  def get_user_preferences
    {
      theme: user&.preferences&.dig('theme') || 'light',
      language: user&.preferences&.dig('language') || 'zh-CN',
      timezone: user&.preferences&.dig('timezone') || 'Asia/Shanghai',
      notification_settings: get_notification_settings,
      privacy_settings: get_privacy_settings
    }
  end

  def get_interface_settings
    {
      font_size: user&.interface_settings&.dig('font_size') || 'medium',
      compact_mode: user&.interface_settings&.dig('compact_mode') || false,
      animations_enabled: user&.interface_settings&.dig('animations_enabled') != false,
      auto_refresh_enabled: user&.interface_settings&.dig('auto_refresh_enabled') != false,
      refresh_interval: user&.interface_settings&.dig('refresh_interval') || 30
    }
  end

  def get_accessibility_options
    {
      high_contrast: user&.accessibility_settings&.dig('high_contrast') || false,
      large_text: user&.accessibility_settings&.dig('large_text') || false,
      screen_reader_support: user&.accessibility_settings&.dig('screen_reader_support') || false,
      keyboard_navigation: user&.accessibility_settings&.dig('keyboard_navigation') || false,
      reduced_motion: user&.accessibility_settings&.dig('reduced_motion') || false
    }
  end

  def get_notification_settings
    {
      email_notifications: user&.notification_settings&.dig('email') != false,
      push_notifications: user&.notification_settings&.dig('push') != false,
      sms_notifications: user&.notification_settings&.dig('sms') || false,
      notification_frequency: user&.notification_settings&.dig('frequency') || 'daily',
      quiet_hours: user&.notification_settings&.dig('quiet_hours') || {}
    }
  end

  def get_privacy_settings
    {
      profile_visibility: user&.privacy_settings&.dig('profile_visibility') || 'public',
      activity_visibility: user&.privacy_settings&.dig('activity_visibility') || 'friends',
      show_online_status: user&.privacy_settings&.dig('show_online_status') != false,
      allow_recommendations: user&.privacy_settings&.dig('allow_recommendations') != false,
      data_sharing_consent: user&.privacy_settings&.dig('data_sharing_consent') || false
    }
  end

  def get_contextual_help
    case request_context[:action]
    when 'create_post'
      {
        title: '创建新帖子',
        content: '分享您的想法、问题或经验。支持图片上传和富文本格式。',
        tips: [
          '使用清晰的标题吸引读者注意',
          '添加相关标签帮助他人发现您的内容',
          '检查拼写和语法错误'
        ],
        help_url: '/help/creating-posts'
      }
    when 'join_event'
      {
        title: '参加活动',
        content: '加入读书活动，与其他书友一起学习和成长。',
        tips: [
          '查看活动时间安排确保您能参与',
          '阅读活动要求做好准备工作',
          '积极参与讨论分享您的见解'
        ],
        help_url: '/help/joining-events'
      }
    else
      {
        title: '使用帮助',
        content: '如有疑问，请查看帮助文档或联系技术支持。',
        tips: [
          '使用搜索功能快速找到感兴趣的内容',
          '关注其他用户获取更新通知',
          '完善个人资料让其他用户更好地了解您'
        ],
        help_url: '/help'
      }
    end
  end

  def generate_recommendations
    recommendations = []

    # 基于用户行为推荐
    recommendations << generate_activity_recommendations
    recommendations << generate_content_recommendations
    recommendations << generate_connection_recommendations
    recommendations << generate_feature_recommendations

    recommendations.flatten.select(&:itself).first(5)
  end

  def generate_activity_recommendations
    # 基于用户参与的读书活动类型推荐相似活动
    user_activities = user&.reading_events&.where('enrollments.created_at > ?', 30.days.ago)

    return [] unless user_activities&.any?

    similar_activities = ReadingEvent.where
      .not(id: user_activities.pluck(:id))
      .where(status: :active)
      .where(category: user_activities.pluck(:category).uniq)
      .limit(3)

    similar_activities.map do |activity|
      {
        type: 'activity',
        title: "推荐活动: #{activity.title}",
        description: "基于您参与过的#{activity.category}类活动推荐",
        action_url: "/events/#{activity.id}",
        priority: 'high'
      }
    end
  end

  def generate_content_recommendations
    # 基于用户点赞和评论推荐帖子
    liked_categories = user&.likes&.joins(:post)
      .where('likes.created_at > ?', 30.days.ago)
      .group('posts.category')
      .count
      .keys

    return [] unless liked_categories&.any?

    popular_posts = Post.where
      .category: liked_categories
      .where('posts.created_at > ?', 7.days.ago)
      .order(likes_count: :desc)
      .limit(3)

    popular_posts.map do |post|
      {
        type: 'content',
        title: "热门帖子: #{post.title}",
        description: "您感兴趣的#{post.category}类别中的热门内容",
        action_url: "/posts/#{post.id}",
        priority: 'medium'
      }
    end
  end

  def generate_connection_recommendations
    # 推荐可能认识的用户
    mutual_connections = find_mutual_connections

    mutual_connections.first(3).map do |potential_user|
      {
        type: 'connection',
        title: "可能认识的用户: #{potential_user.nickname}",
        description: "您有#{mutual_connections[potential_user]}个共同好友",
        action_url: "/users/#{potential_user.id}",
        priority: 'low'
      }
    end
  end

  def generate_feature_recommendations
    features = []

    # 新功能推荐
    unless user&.preferences&.dig('new_features_shown')&.include?('reading_goals')
      features << {
        type: 'feature',
        title: '设置阅读目标',
        description: '为自己设定每月阅读目标，跟踪阅读进度',
        action_url: '/profile/reading-goals',
        priority: 'high',
        badge: 'NEW'
      }
    end

    # 功能使用提示
    if user&.posts&.count == 0
      features << {
        type: 'feature',
        title: '发布第一条帖子',
        description: '开始分享您的想法，与其他书友交流',
        action_url: '/posts/new',
        priority: 'medium'
      }
    end

    features
  end

  def find_mutual_connections
    # 简化版的共同好友推荐逻辑
    # 实际实现可以基于更复杂的社交网络分析
    User.joins(:received_flowers)
      .where(flowers: { giver_id: user.friends.pluck(:id) })
      .where.not(id: user.id)
      .distinct
      .limit(10)
  end

  def generate_personalization_data
    {
      user_level: calculate_user_level,
      achievement_progress: get_achievement_progress,
      reading_stats: get_reading_statistics,
      engagement_metrics: get_engagement_metrics,
      personalized_greeting: generate_personalized_greeting
    }
  end

  def calculate_user_level
    # 基于用户活跃度计算等级
    score = 0

    # 帖子贡献
    score += (user&.posts&.count || 0) * 10
    # 评论贡献
    score += (user&.comments&.count || 0) * 5
    # 点赞互动
    score += (user&.likes&.count || 0) * 2
    # 活动参与
    score += (user&.event_enrollments&.count || 0) * 15
    # 小红花获得
    score += (user&.received_flowers&.count || 0) * 8

    case score
    when 0..50
      { level: 1, title: '新手书友', next_level_score: 51, current_score: score }
    when 51..200
      { level: 2, title: '活跃书友', next_level_score: 201, current_score: score }
    when 201..500
      { level: 3, title: '资深书友', next_level_score: 501, current_score: score }
    when 501..1000
      { level: 4, title: '领读者', next_level_score: 1001, current_score: score }
    else
      { level: 5, title: '读书达人', next_level_score: nil, current_score: score }
    end
  end

  def get_achievement_progress
    # 获取用户成就进度
    achievements = [
      {
        id: 'first_post',
        name: '初次分享',
        description: '发布第一条帖子',
        progress: (user&.posts&.count || 0) >= 1 ? 100 : 0,
        completed: (user&.posts&.count || 0) >= 1,
        icon: 'post'
      },
      {
        id: 'ten_posts',
        name: '积极分享',
        description: '发布10条帖子',
        progress: [(user&.posts&.count || 0) * 10, 100].min,
        completed: (user&.posts&.count || 0) >= 10,
        icon: 'posts'
      },
      {
        id: 'first_comment',
        name: '初次评论',
        description: '发表第一条评论',
        progress: (user&.comments&.count || 0) >= 1 ? 100 : 0,
        completed: (user&.comments&.count || 0) >= 1,
        icon: 'comment'
      },
      {
        id: 'first_event',
        name: '初次参与',
        description: '参加第一个读书活动',
        progress: (user&.event_enrollments&.count || 0) >= 1 ? 100 : 0,
        completed: (user&.event_enrollments&.count || 0) >= 1,
        icon: 'event'
      }
    ]

    # 添加自定义成就
    achievements.concat(get_custom_achievements)
  end

  def get_custom_achievements
    # 基于用户行为的自定义成就
    custom_achievements = []

    # 连续签到成就
    check_in_streak = calculate_check_in_streak
    if check_in_streak > 0
      custom_achievements << {
        id: 'check_in_streak',
        name: "连续签到#{check_in_streak}天",
        description: '坚持每日签到',
        progress: [check_in_streak * 10, 100].min,
        completed: check_in_streak >= 10,
        icon: 'calendar'
      }
    end

    # 社交达人成就
    flowers_given = user&.flowers_given&.count || 0
    if flowers_given > 0
      custom_achievements << {
        id: 'social_butterfly',
        name: "送出#{flowers_given}朵小红花",
        description: '积极互动，鼓励他人',
        progress: [flowers_given * 2, 100].min,
        completed: flowers_given >= 50,
        icon: 'flower'
      }
    end

    custom_achievements
  end

  def calculate_check_in_streak
    # 计算连续签到天数
    return 0 unless user

    # 获取最近30天的签到记录
    check_ins = CheckIn.where(user: user)
      .where('created_at > ?', 30.days.ago)
      .order(created_at: :desc)

    return 0 if check_ins.empty?

    streak = 1
    check_ins.each_cons(2) do |current, previous|
      break unless (current.created_at.to_date - previous.created_at.to_date) == 1
      streak += 1
    end

    streak
  end

  def get_reading_statistics
    {
      books_read: user&.check_ins&.distinct.count(:reading_schedule_id) || 0,
      pages_read: calculate_pages_read,
      reading_time: calculate_reading_time,
      favorite_genres: get_favorite_genres,
      monthly_progress: get_monthly_progress
    }
  end

  def calculate_pages_read
    # 基于打卡数据估算阅读页数
    user&.check_ins&.sum(:pages_read) || 0
  end

  def calculate_reading_time
    # 基于打卡数据估算阅读时间
    total_minutes = user&.check_ins&.sum(:reading_duration) || 0
    hours = total_minutes / 60
    minutes = total_minutes % 60

    { hours: hours, minutes: minutes, total_minutes: total_minutes }
  end

  def get_favorite_genres
    # 获取用户最喜欢的阅读类型
    genre_counts = CheckIn.joins(reading_schedule: :reading_event)
      .where(user: user)
      .group('reading_events.category')
      .count

    genre_counts.sort_by { |_, count| -count }.first(3).map do |genre, count|
      { genre: genre, count: count }
    end
  end

  def get_monthly_progress
    # 获取本月阅读进度
    start_of_month = Time.current.beginning_of_month

    {
      posts_this_month: user&.posts&.where('created_at > ?', start_of_month).count || 0,
      comments_this_month: user&.comments&.where('created_at > ?', start_of_month).count || 0,
      events_this_month: user&.event_enrollments&.where('created_at > ?', start_of_month).count || 0,
      flowers_this_month: user&.received_flowers&.where('created_at > ?', start_of_month).count || 0
    }
  end

  def get_engagement_metrics
    {
      login_frequency: calculate_login_frequency,
      interaction_rate: calculate_interaction_rate,
      content_quality_score: calculate_content_quality_score,
      community_contribution: calculate_community_contribution
    }
  end

  def calculate_login_frequency
    # 计算登录频率（简化版）
    recent_logins = 30 # 假设数据，实际应从日志获取
    (recent_logins / 30.0).round(2)
  end

  def calculate_interaction_rate
    # 计算互动率
    total_interactions = (user&.comments&.count || 0) + (user&.likes&.count || 0)
    total_content = user&.posts&.count || 1

    (total_interactions.to_f / total_content).round(2)
  end

  def calculate_content_quality_score
    # 计算内容质量分
    total_likes = user&.posts&.sum(:likes_count) || 0
    total_comments = user&.posts&.sum(:comments_count) || 0
    total_posts = user&.posts&.count || 1

    score = ((total_likes * 2 + total_comments) / total_posts.to_f).round(2)
    [score, 10.0].min
  end

  def calculate_community_contribution
    # 计算社区贡献度
    contribution_score = 0

    # 发帖贡献
    contribution_score += (user&.posts&.count || 0) * 5
    # 评论贡献
    contribution_score += (user&.comments&.count || 0) * 3
    # 小红花贡献
    contribution_score += (user&.flowers_given&.count || 0) * 2
    # 活动贡献
    contribution_score += (user&.event_enrollments&.count || 0) * 8

    contribution_score
  end

  def generate_personalized_greeting
    hour = Time.current.hour
    time_greeting = case hour
                    when 5..11
                      '早上好'
                    when 12..17
                      '下午好'
                    when 18..22
                      '晚上好'
                    else
                      '夜深了'
                    end

    user_name = user&.nickname || '书友'
    activity_tip = generate_activity_tip

    "#{time_greeting}，#{user_name}！#{activity_tip}"
  end

  def generate_activity_tip
    case Time.current.hour
    when 5..9
      '新的一天开始了，要不要读几页书？'
    when 12..13
      '午休时间，看看书友们的分享吧'
    when 18..20
      '晚饭后是阅读的好时光'
    when 21..22
      '睡前阅读，有助于睡眠'
    else
      '注意休息，别太晚了哦'
    end
  end

  def generate_quick_actions
    actions = []

    case request_context[:current_page]
    when 'home'
      actions << { name: '发布新帖', url: '/posts/new', icon: 'edit' }
      actions << { name: '查看活动', url: '/events', icon: 'calendar' }
    when 'profile'
      actions << { name: '编辑资料', url: '/profile/edit', icon: 'user' }
      actions << { name: '设置', url: '/settings', icon: 'settings' }
    end

    # 基于用户状态添加快捷操作
    if user&.unread_notifications&.any?
      actions << { name: '查看通知', url: '/notifications', icon: 'bell', badge: user.unread_notifications.count }
    end

    actions
  end

  def generate_contextual_tips
    tips = []

    # 基于时间和用户行为的提示
    if Time.current.hour >= 22
      tips << {
        type: 'health',
        message: '夜深了，注意保护眼睛，适当休息',
        icon: 'moon'
      }
    end

    # 基于用户活跃度的提示
    if user&.last_sign_in_at && user.last_sign_in_at < 7.days.ago
      tips << {
        type: 'engagement',
        message: '您已经几天没有来了，看看朋友们的新动态吧',
        icon: 'users'
      }
    end

    # 新功能提示
    if user&.created_at && user.created_at < 30.days.ago && user.posts.count < 3
      tips << {
        type: 'encouragement',
        message: '分享您的读书心得，帮助更多书友',
        icon: 'book'
      }
    end

    tips
  end
end