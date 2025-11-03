# frozen_string_literal: true

# QueryCacheService - 查询缓存服务
# 提供多层缓存策略：内存缓存、Redis缓存、查询结果缓存
class QueryCacheService < ApplicationService
  include ServiceInterface

  # 缓存层级
  MEMORY_CACHE = {}
  CACHE_LOCKS = {}

  attr_reader :cache_key, :cache_options, :fallback_proc, :cache_level

  def initialize(cache_key:, cache_options: {}, fallback_proc: nil, cache_level: :memory)
    super()
    @cache_key = cache_key
    @cache_options = default_cache_options.merge(cache_options)
    @fallback_proc = fallback_proc
    @cache_level = cache_level
  end

  def call
    handle_errors do
      validate_parameters
      fetch_with_cache
    end
    self
  end

  # 类方法：缓存查询结果
  def self.fetch(cache_key, cache_options: {}, cache_level: :memory, &block)
    new(
      cache_key: cache_key,
      cache_options: cache_options,
      fallback_proc: block,
      cache_level: cache_level
    ).call.data
  end

  # 类方法：缓存帖子列表
  def self.fetch_posts_list(filters = {}, page: 1, per_page: 20, current_user: nil)
    cache_key = "posts_list:#{filters.to_query_hash}:#{page}:#{per_page}:#{current_user&.id}"

    fetch(cache_key,
          expires_in: 5.minutes,
          cache_level: :memory) do
      # 构建查询
      posts = Post.visible.includes(:user)
                  .order(pinned: :desc, created_at: :desc)

      # 应用筛选条件
      posts = posts.by_category(filters[:category]) if filters[:category].present?

      # 分页
      posts = posts.limit(per_page).offset((page - 1) * per_page)

      # 预加载权限和点赞状态
      if current_user
        post_ids = posts.map(&:id)
        permissions = PostPermissionService.batch_check_posts_permissions(
          post_ids, current_user.id
        )
        liked_post_ids = Like.where(
          user_id: current_user.id,
          target_type: 'Post',
          target_id: post_ids
        ).pluck(:target_id)

        posts.each do |post|
          post.instance_variable_set(:@permissions, permissions)
          post.instance_variable_set(:@current_user_liked, liked_post_ids.include?(post.id))
        end
      end

      posts
    end
  end

  # 类方法：缓存单个帖子
  def self.fetch_post(post_id, current_user: nil)
    cache_key = "post:#{post_id}:#{current_user&.id}"

    fetch(cache_key,
          expires_in: 10.minutes,
          cache_level: :memory) do
      post = Post.includes(:user).find(post_id)

      # 预加载权限和点赞状态
      if current_user
        permissions = PostPermissionService.batch_check_posts_permissions(
          [post_id], current_user.id
        )
        liked = Like.exists?(
          user_id: current_user.id,
          target_type: 'Post',
          target_id: post_id
        )

        post.instance_variable_set(:@permissions, permissions)
        post.instance_variable_set(:@current_user_liked, liked)
      end

      post
    end
  end

  # 类方法：缓存用户统计
  def self.fetch_user_stats(user_id)
    cache_key = "user_stats:#{user_id}"

    fetch(cache_key,
          expires_in: 1.hour,
          cache_level: :memory) do
      user = User.find(user_id)

      {
        posts_count: user.posts_count,
        comments_count: user.comments_count,
        flowers_given_count: user.flowers_given_count,
        flowers_received_count: user.flowers_received_count,
        likes_given_count: user.likes_given_count
      }
    end
  end

  # 类方法：缓存活动统计
  def self.fetch_event_stats(event_id)
    cache_key = "event_stats:#{event_id}"

    fetch(cache_key,
          expires_in: 30.minutes,
          cache_level: :memory) do
      event = ReadingEvent.find(event_id)

      {
        enrollments_count: event.enrollments_count,
        check_ins_count: event.check_ins_count,
        flowers_count: event.flowers_count,
        completion_rate: calculate_completion_rate(event)
      }
    end
  end

  # 类方法：清除缓存
  def self.clear_cache(pattern = nil)
    if pattern
      # 清除匹配模式的缓存
      if defined?(Rails) && Rails.cache.respond_to?(:delete_matched)
        Rails.cache.delete_matched(pattern)
      end

      # 清除内存缓存
      MEMORY_CACHE.delete_if { |key, _| key.match?(Regexp.new(pattern)) }
    else
      # 清除所有缓存
      if defined?(Rails) && Rails.cache.respond_to?(:clear)
        Rails.cache.clear
      end

      MEMORY_CACHE.clear
    end
  end

  # 类方法：预热缓存
  def self.warmup_popular_data
    # 预热热门帖子
    popular_posts = Post.visible.order(likes_count: :desc).limit(10)
    popular_posts.each do |post|
      fetch_post(post.id)
    end

    # 预热活动统计
    active_events = ReadingEvent.where(status: :active).limit(5)
    active_events.each do |event|
      fetch_event_stats(event.id)
    end

    Rails.logger.info "缓存预热完成"
  end

  def data
    @data
  end

  def cache_hit?
    @cache_hit
  end

  private

  def validate_parameters
    errors.add(:cache_key, "缓存键不能为空") if cache_key.blank?
    errors.add(:fallback_proc, "必须提供fallback_proc或代码块") if fallback_proc.nil?
  end

  def fetch_with_cache
    # 尝试从缓存获取
    cached_value = get_from_cache

    if cached_value.present?
      @cache_hit = true
      @data = cached_value
      Rails.logger.debug "缓存命中: #{cache_key}"
      return self
    end

    # 防止缓存击穿
    @cache_hit = false
    @data = fetch_with_lock

    # 存入缓存
    set_to_cache(@data)

    Rails.logger.debug "缓存未命中，已设置: #{cache_key}"
    self
  end

  def fetch_with_lock
    # 小应用简化实现：直接使用内存锁
    CACHE_LOCKS[cache_key] ||= Mutex.new
    CACHE_LOCKS[cache_key].synchronize do
      result = fallback_proc.call
      return result
    end
  end

  def get_from_cache
    case cache_level
    when :memory
      MEMORY_CACHE[cache_key]
    when :redis
      if defined?(Rails) && Rails.cache
        Rails.cache.read(cache_key)
      else
        nil
      end
    else
      nil
    end
  end

  def set_to_cache(value)
    return unless value

    case cache_level
    when :memory
      MEMORY_CACHE[cache_key] = value
    when :redis
      if defined?(Rails) && Rails.cache
        Rails.cache.write(cache_key, value, **cache_options)
      end
    end
  end

  def default_cache_options
    {
      expires_in: 30.minutes,
      race_condition_ttl: 30.seconds,
      compress: true
    }
  end

  def calculate_completion_rate(event)
    return 0 if event.enrollments_count == 0

    total_days = (event.end_date - event.start_date).to_i + 1
    expected_check_ins = event.enrollments_count * total_days

    return 0 if expected_check_ins == 0

    (event.check_ins_count.to_f / expected_check_ins * 100).round(2)
  end
end