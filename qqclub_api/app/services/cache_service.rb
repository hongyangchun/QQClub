# frozen_string_literal: true

# 缓存服务
# 提供统一的缓存接口，支持多种缓存策略和数据类型
class CacheService
  class << self
    # 缓存用户基本信息
    # @param user [User] 用户对象
    # @param ttl [Integer] 缓存时间（秒）
    # @return [Hash] 用户基本信息
    def cache_user_profile(user, ttl: 30.minutes)
      cache_key = "user_profile:#{user.id}"

      cached_data = Rails.cache.fetch(cache_key, expires_in: ttl) do
        {
          id: user.id,
          nickname: user.nickname,
          avatar_url: user.avatar_url,
          role: user.role_as_string,
          created_at: user.created_at,
          stats: {
            events_count: user.created_events.count,
            check_ins_count: user.check_ins.count,
            flowers_given: user.given_flowers.count,
            flowers_received: user.received_flowers.count
          }
        }
      end

      cached_data
    end

    # 缓存活动基本信息
    # @param event [ReadingEvent] 活动对象
    # @param ttl [Integer] 缓存时间（秒）
    # @return [Hash] 活动基本信息
    def cache_event_profile(event, ttl: 30.minutes)
      cache_key = "event_profile:#{event.id}"

      cached_data = Rails.cache.fetch(cache_key, expires_in: ttl) do
        {
          id: event.id,
          title: event.title,
          book_name: event.book_name,
          book_cover_url: event.book_cover_url,
          description: event.description&.truncate(200),
          status: event.status,
          approval_status: event.approval_status,
          start_date: event.start_date,
          end_date: event.end_date,
          max_participants: event.max_participants,
          leader: event.leader&.as_json_for_api,
          stats: {
            enrolled_count: event.event_enrollments.where(status: 'enrolled').count,
            check_ins_count: event.check_ins.count,
            flowers_count: event.flowers_count
          }
        }
      end

      cached_data
    end

    # 缓存排行榜数据
    # @param type [Symbol] 排行榜类型 (:flowers, :check_ins, :participation)
    # @param period [Symbol] 时间周期 (:today, :week, :month, :all_time)
    # @param limit [Integer] 返回记录数
    # @param ttl [Integer] 缓存时间（秒）
    # @return [Array] 排行榜数据
    def cache_leaderboard(type, period, limit: 10, ttl: 5.minutes)
      cache_key = "leaderboard:#{type}:#{period}:#{limit}"

      Rails.cache.fetch(cache_key, expires_in: ttl) do
        case type
        when :flowers
          AnalyticsService.leaderboards(:flowers, limit, period)
        when :check_ins
          AnalyticsService.leaderboards(:check_ins, limit, period)
        when :participation
          AnalyticsService.leaderboards(:participation, limit, period)
        else
          []
        end
      end
    end

    # 缓存用户统计信息
    # @param user [User] 用户对象
    # @param days [Integer] 统计天数
    # @param ttl [Integer] 缓存时间（秒）
    # @return [Hash] 用户统计信息
    def cache_user_analytics(user, days: 30, ttl: 10.minutes)
      cache_key = "user_analytics:#{user.id}:#{days}days"

      Rails.cache.fetch(cache_key, expires_in: ttl) do
        AnalyticsService.user_analytics(user, days)
      end
    end

    # 缓存系统统计信息
    # @param ttl [Integer] 缓存时间（秒）
    # @return [Hash] 系统统计信息
    def cache_system_overview(ttl: 1.hour)
      cache_key = "system_overview"

      Rails.cache.fetch(cache_key, expires_in: ttl) do
        AnalyticsService.system_overview
      end
    end

    # 缓存用户的未读通知数量
    # @param user [User] 用户对象
    # @param ttl [Integer] 缓存时间（秒）
    # @return [Integer] 未读通知数量
    def cache_unread_notifications_count(user, ttl: 1.minute)
      cache_key = "unread_notifications:#{user.id}"

      Rails.cache.fetch(cache_key, expires_in: ttl) do
        user.received_notifications.unread.count
      end
    end

    # 缓存用户的活动报名状态
    # @param user [User] 用户对象
    # @param event [ReadingEvent] 活动对象
    # @param ttl [Integer] 缓存时间（秒）
    # @return [Hash] 报名状态信息
    def cache_event_enrollment_status(user, event, ttl: 5.minutes)
      cache_key = "enrollment_status:#{user.id}:#{event.id}"

      Rails.cache.fetch(cache_key, expires_in: ttl) do
        enrollment = event.event_enrollments.find_by(user: user)

        {
          enrolled: enrollment.present?,
          status: enrollment&.status,
          enrollment_date: enrollment&.created_at,
          can_enroll: event.can_enroll?,
          is_full: event.full?,
          check_ins_count: enrollment&.check_ins_count || 0,
          completion_rate: enrollment&.completion_rate || 0
        }
      end
    end

    # 缓存今日小红花配额信息
    # @param user [User] 用户对象
    # @param event [ReadingEvent] 活动对象
    # @param ttl [Integer] 缓存时间（秒）
    # @return [Hash] 配额信息
    def cache_flower_quota_info(user, event, ttl: 1.minute)
      cache_key = "flower_quota:#{user.id}:#{event.id}:#{Date.current}"

      Rails.cache.fetch(cache_key, expires_in: ttl) do
        FlowerQuotaService.get_daily_quota(user, event, Date.current)
      end
    end

    # 批量缓存用户基本信息
    # @param users [Array<User>] 用户数组
    # @param ttl [Integer] 缓存时间（秒）
    # @return [Hash] 用户ID到缓存的映射
    def batch_cache_user_profiles(users, ttl: 30.minutes)
      return {} if users.empty?

      # 批量查找需要缓存的用户
      user_ids = users.map(&:id)
      existing_cache_keys = user_ids.map { |id| "user_profile:#{id}" }
      cached_data = Rails.cache.read_multi(*existing_cache_keys)

      # 找出需要重新缓存的用户
      uncached_users = users.reject { |user| cached_data.key?("user_profile:#{user.id}") }

      # 批量缓存未缓存的用户
      uncached_users.each do |user|
        cache_user_profile(user, ttl: ttl)
      end

      # 返回所有用户的缓存数据
      user_ids.index_with do |user_id|
        Rails.cache.read("user_profile:#{user_id}")
      end.to_h
    end

    # 缓存搜索结果
    # @param search_term [String] 搜索关键词
    # @param search_type [Symbol] 搜索类型
    # @param results [Array] 搜索结果
    # @param ttl [Integer] 缓存时间（秒）
    # @return [Array] 缓存的搜索结果
    def cache_search_results(search_term, search_type, results, ttl: 15.minutes)
      return results if search_term.blank? || results.empty?

      cache_key = "search:#{search_type}:#{Digest::MD5.hexdigest(search_term.downcase)}"

      Rails.cache.write(cache_key, results, expires_in: ttl)
      results
    end

    # 获取缓存的搜索结果
    # @param search_term [String] 搜索关键词
    # @param search_type [Symbol] 搜索类型
    # @return [Array, nil] 缓存的搜索结果或nil
    def get_cached_search_results(search_term, search_type)
      return nil if search_term.blank?

      cache_key = "search:#{search_type}:#{Digest::MD5.hexdigest(search_term.downcase)}"
      Rails.cache.read(cache_key)
    end

    # 缓存热门关键词
    # @param keywords [Array<String>] 关键词数组
    # @param ttl [Integer] 缓存时间（秒）
    # @return [Array<String>] 热门关键词
    def cache_popular_keywords(keywords, ttl: 1.hour)
      cache_key = "popular_keywords"

      Rails.cache.fetch(cache_key, expires_in: ttl) do
        keywords.first(10) # 只保留前10个
      end
    end

    # 缓存配置信息
    # @param ttl [Integer] 缓存时间（秒）
    # @return [Hash] 配置信息
    def cache_app_config(ttl: 1.hour)
      cache_key = "app_config"

      Rails.cache.fetch(cache_key, expires_in: ttl) do
        {
          max_flowers_per_check_in: 3,
          max_check_in_length: 2000,
          min_check_in_length: 50,
          default_event_duration: 30.days,
          max_event_participants: 100,
          flower_quota_daily: 3,
          notification_unread_limit: 50
        }
      end
    end

    # 清除用户相关的缓存
    # @param user [User] 用户对象
    def clear_user_cache(user)
      cache_patterns = [
        "user_profile:#{user.id}",
        "user_analytics:#{user.id}:*",
        "unread_notifications:#{user.id}",
        "enrollment_status:#{user.id}:*",
        "flower_quota:#{user.id}:*"
      ]

      cache_patterns.each do |pattern|
        if pattern.include?('*')
          Rails.cache.delete_matched(pattern)
        else
          Rails.cache.delete(pattern)
        end
      end
    end

    # 清除活动相关的缓存
    # @param event [ReadingEvent] 活动对象
    def clear_event_cache(event)
      cache_patterns = [
        "event_profile:#{event.id}",
        "enrollment_status:*:#{event.id}",
        "leaderboard:*:*:*" # 清除所有排行榜缓存
      ]

      cache_patterns.each do |pattern|
        if pattern.include?('*')
          Rails.cache.delete_matched(pattern)
        else
          Rails.cache.delete(pattern)
        end
      end
    end

    # 清除系统统计缓存
    def clear_system_cache
      Rails.cache.delete_matched("system_overview")
      Rails.cache.delete_matched("leaderboard:*")
      Rails.cache.delete_matched("popular_keywords")
    end

    # 预热缓存
    # 预加载常用数据到缓存中
    def warm_up_cache
      # 缓存系统概览
      cache_system_overview

      # 缓存热门排行榜
      [:flowers, :check_ins].each do |type|
        [:today, :week, :month].each do |period|
          cache_leaderboard(type, period)
        end
      end

      # 缓存应用配置
      cache_app_config

      Rails.logger.info "缓存预热完成"
    end

    # 获取缓存统计信息
    # @return [Hash] 缓存统计
    def cache_stats
      if Rails.cache.respond_to?(:stats)
        Rails.cache.stats
      else
        {
          cache_store: Rails.cache.class.name,
          message: "当前缓存存储不支持统计功能"
        }
      end
    end

    # 检查缓存健康状态
    # @return [Hash] 健康状态
    def cache_health_check
      test_key = "health_check_#{Time.current.to_i}"
      test_value = { test: true, timestamp: Time.current }

      begin
        # 写入测试
        Rails.cache.write(test_key, test_value, expires_in: 1.minute)

        # 读取测试
        cached_value = Rails.cache.read(test_key)

        # 清理测试数据
        Rails.cache.delete(test_key)

        {
          status: cached_value == test_value ? "healthy" : "unhealthy",
          cache_store: Rails.cache.class.name,
          test_time: Time.current
        }
      rescue => e
        {
          status: "error",
          cache_store: Rails.cache.class.name,
          error: e.message,
          test_time: Time.current
        }
      end
    end
  end
end