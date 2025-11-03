# frozen_string_literal: true

# PostDataService - 帖子数据服务
# 专门负责帖子数据的格式化、序列化和展示逻辑
class PostDataService < ApplicationService
  include ServiceInterface
  attr_reader :post, :current_user, :options

  def initialize(post:, current_user: nil, options: {})
    super()
    @post = post
    @current_user = current_user
    @options = options.with_indifferent_access
  end

  # 格式化帖子数据
  def call
    handle_errors do
      validate_data_params
      format_post_data
    end
    self
  end

  # 生成帖子摘要
  def generate_summary(length: 100)
    return "" unless post&.content

    # 移除HTML标签（如果有）
    plain_content = post.content.gsub(/<[^>]+>/, '').strip

    # 截取指定长度
    if plain_content.length > length
      plain_content[0...length] + "..."
    else
      plain_content
    end
  end

  # 生成帖子统计信息
  def generate_stats
    return {} unless post

    {
      views_count: post.respond_to?(:views_count) ? post.views_count : 0,
      likes_count: post.respond_to?(:likes_count) ? post.likes_count : 0,
      comments_count: post.respond_to?(:comments_count) ? post.comments_count : 0,
      shares_count: post.respond_to?(:shares_count) ? post.shares_count : 0,
      bookmarks_count: post.respond_to?(:bookmarks_count) ? post.bookmarks_count : 0
    }
  end

  # 生成时间相关数据
  def generate_time_data
    return {} unless post

    {
      created_at: post.created_at,
      updated_at: post.updated_at,
      time_ago: time_ago_in_words(post.created_at),
      last_activity_ago: time_ago_in_words(post.updated_at)
    }
  end

  # 生成作者信息
  def generate_author_info
    return {} unless post&.user

    {
      id: post.user.id,
      nickname: post.user.nickname,
      avatar_url: post.user.avatar_url,
      role: post.user.role_display_name,
      is_verified: post.user.respond_to?(:verified?) ? post.user.verified? : false,
      followers_count: post.user.respond_to?(:followers_count) ? post.user.followers_count : 0,
      posts_count: post.user.respond_to?(:posts_count) ? post.user.posts_count : 0
    }
  end

  # 生成交互状态信息
  def generate_interaction_states
    return {} unless current_user && post

    {
      liked: post.liked_by?(current_user),
      bookmarked: post.bookmarked_by?(current_user),
      can_edit: PostPermissionService.can_edit?(post, current_user),
      can_delete: PostPermissionService.can_delete?(post, current_user),
      can_pin: PostPermissionService.can_pin?(post, current_user),
      can_hide: PostPermissionService.can_hide?(post, current_user),
      can_comment: PostPermissionService.can_comment?(post, current_user)
    }
  end

  # 生成分类信息
  def generate_category_info
    return {} unless post

    {
      category: post.category,
      category_name: post.category_name,
      category_color: category_color(post.category)
    }
  end

  # 生成标签信息
  def generate_tags_info
    return [] unless post&.tags

    post.tags.map do |tag|
      {
        name: tag,
        color: tag_color(tag),
        count: tag_post_count(tag)
      }
    end
  end

  # 生成图片信息
  def generate_images_info
    return [] unless post&.images

    post.images.map.with_index do |image_url, index|
      {
        url: image_url,
        thumbnail: thumbnail_url(image_url),
        alt: "#{post.title} - 图片#{index + 1}",
        width: image_width(image_url),
        height: image_height(image_url)
      }
    end
  end

  private

  # 验证数据参数
  def validate_data_params
    return failure!("帖子不能为空") unless post
    return failure!("帖子不存在") unless post.persisted?
    true
  end

  # 格式化帖子数据
  def format_post_data
    data = {
      id: post.id,
      title: post.title,
      content: formatted_content,
      summary: generate_summary,
      stats: generate_stats,
      time_data: generate_time_data,
      author: generate_author_info,
      category: generate_category_info,
      tags: generate_tags_info,
      images: generate_images_info,
      interactions: generate_interaction_states,
      metadata: generate_metadata
    }

    # 根据选项添加额外字段
    data.merge!(add_optional_fields)

    success!(data)
  end

  # 格式化内容
  def formatted_content
    return post.content unless options[:format_content]

    case options[:content_format]
    when :html
      format_content_as_html
    when :markdown
      format_content_as_markdown
    when :plain
      format_content_as_plain
    else
      post.content
    end
  end

  # HTML格式化
  def format_content_as_html
    # 这里可以添加HTML格式化逻辑
    post.content
  end

  # Markdown格式化
  def format_content_as_markdown
    # 这里可以添加Markdown格式化逻辑
    post.content
  end

  # 纯文本格式化
  def format_content_as_plain
    post.content.gsub(/<[^>]+>/, '').strip
  end

  # 生成元数据
  def generate_metadata
    {
      pinned: post.pinned?,
      hidden: post.hidden?,
      deleted: post.deleted?,
      featured: post.featured?,
      priority: post.priority || 0,
      source: post.source || 'web',
      device_type: post.device_type || 'unknown'
    }
  end

  # 添加可选字段
  def add_optional_fields
    additional_fields = {}

    # 包含完整内容
    if options[:include_full_content]
      additional_fields[:full_content] = post.content
    end

    # 包含SEO信息
    if options[:include_seo]
      additional_fields[:seo] = generate_seo_data
    end

    # 包含分享信息
    if options[:include_share]
      additional_fields[:share] = generate_share_data
    end

    # 包含相关帖子
    if options[:include_related]
      additional_fields[:related_posts] = generate_related_posts
    end

    additional_fields
  end

  # 生成SEO数据
  def generate_seo_data
    {
      title: post.title,
      description: generate_summary(length: 160),
      keywords: post.tags&.join(', '),
      url: post_url(post),
      image_url: post.images&.first
    }
  end

  # 生成分享数据
  def generate_share_data
    {
      url: post_url(post),
      title: post.title,
      description: generate_summary,
      image_url: post.images&.first
    }
  end

  # 生成相关帖子
  def generate_related_posts
    # 这里可以添加相关帖子推荐逻辑
    []
  end

  # 辅助方法：时间格式化
  def time_ago_in_words(time)
    return "" unless time

    seconds = Time.current - time
    minutes = seconds / 60
    hours = minutes / 60
    days = hours / 24

    if days > 0
      "#{days.to_i}天前"
    elsif hours > 0
      "#{hours.to_i}小时前"
    elsif minutes > 0
      "#{minutes.to_i}分钟前"
    else
      "刚刚"
    end
  end

  # 辅助方法：分类颜色
  def category_color(category)
    colors = {
      'reading' => '#FF6B6B',
      'discussion' => '#4ECDC4',
      'share' => '#45B7D1',
      'question' => '#96CEB4',
      'announcement' => '#FECA57'
    }
    colors[category] || '#95A5A6'
  end

  # 辅助方法：标签颜色
  def tag_color(tag)
    # 简单的标签颜色生成算法
    hash = Digest::MD5.hexdigest(tag)[0..5]
    "##{hash}"
  end

  # 辅助方法：标签帖子数量
  def tag_post_count(tag)
    # 这里可以添加缓存逻辑
    Post.where('tags LIKE ?', "%#{tag}%").count
  end

  # 辅助方法：缩略图URL
  def thumbnail_url(image_url)
    # 这里可以添加缩略图生成逻辑
    image_url
  end

  # 辅助方法：图片宽度
  def image_width(image_url)
    # 这里可以添加图片尺寸获取逻辑
    800
  end

  # 辅助方法：图片高度
  def image_height(image_url)
    # 这里可以添加图片尺寸获取逻辑
    600
  end

  # 辅助方法：帖子URL
  def post_url(post)
    "/posts/#{post.id}"
  end

  private

  # 使用预获取权限的帖子格式化方法
  def format_post_with_permissions(post, current_user: nil, options: {}, permissions: {})
    data = {
      id: post.id,
      title: post.title,
      content: formatted_content,
      summary: generate_summary,
      stats: generate_stats,
      time_data: generate_time_data,
      author: generate_author_info,
      category: generate_category_info,
      tags: generate_tags_info,
      images: generate_images_info,
      interactions: generate_interaction_states_with_permissions(post, current_user, permissions),
      metadata: generate_metadata
    }

    # 根据选项添加额外字段
    data.merge!(add_optional_fields)

    data
  end

  # 生成带预获取权限的交互状态
  def generate_interaction_states_with_permissions(post, current_user, permissions)
    return {} unless current_user && post

    post_id = post.id

    # 使用预获取的权限信息，如果没有则回退到原有方法
    {
      liked: post.liked_by?(current_user),
      bookmarked: post.bookmarked_by?(current_user),
      can_edit: permissions.dig(:edit, post_id) || PostPermissionService.can_edit?(post, current_user),
      can_delete: permissions.dig(:delete, post_id) || PostPermissionService.can_delete?(post, current_user),
      can_pin: permissions.dig(:pin, post_id) || PostPermissionService.can_pin?(post, current_user),
      can_hide: permissions.dig(:hide, post_id) || PostPermissionService.can_hide?(post, current_user),
      can_comment: permissions.dig(:comment, post_id) || PostPermissionService.can_comment?(post, current_user)
    }
  end

  # 批量获取点赞状态
  def self.batch_get_like_statuses(posts, current_user)
    return {} unless posts.any? && current_user

    post_ids = posts.map(&:id)

    # 假设有Like模型，批量查询用户对帖子的点赞状态
    if defined?(Like)
      likes = Like.where(user: current_user, target_id: post_ids, target_type: 'Post')
      likes.index_by(&:target_id).transform_values { true }
    else
      {}
    end
  rescue
    {}
  end

  # 批量获取收藏状态
  def self.batch_get_bookmark_statuses(posts, current_user)
    return {} unless posts.any? && current_user

    post_ids = posts.map(&:id)

    # 假设有Bookmark模型，批量查询用户对帖子的收藏状态
    # 如果没有Bookmark模型，返回空哈希
    {}
  rescue
    {}
  end

  # 类方法：快速格式化
  def self.format_post(post, current_user: nil, options: {})
    service = new(post: post, current_user: current_user, options: options)
    service.call
    service.instance_variable_get(:@data)
  end

  # 类方法：批量格式化
  def self.format_posts(posts, current_user: nil, options = {})
    posts.map do |post|
      format_post(post, current_user: current_user, options: options)
    end
  end

  # 批量格式化帖子 - 优化列表页面性能
  def self.batch_format_posts(posts, current_user: nil, options = {})
    return [] if posts.blank?

    # 预加载关联数据避免N+1查询
    posts = posts.includes(:user, :tags, :likes) if posts.respond_to?(:includes)

    # 如果有当前用户，批量获取权限信息
    permissions = {}
    if current_user && posts.any?
      post_ids = posts.map(&:id)
      permissions = PostPermissionService.batch_check_posts_permissions(
        post_ids,
        current_user.id,
        [:edit, :delete, :pin, :hide, :comment]
      )
    end

    # 批量处理帖子数据
    posts.map do |post|
      format_post_with_permissions(post, current_user: current_user, options: options, permissions: permissions)
    end
  end

  # 批量生成帖子交互状态 - 权限优化版本
  def self.batch_generate_interaction_states(posts, current_user)
    return {} unless current_user && posts.any?

    post_ids = posts.map(&:id)

    # 批量获取权限信息
    permissions = PostPermissionService.batch_check_posts_permissions(
      post_ids,
      current_user.id,
      [:edit, :delete, :pin, :hide, :comment]
    )

    # 批量获取点赞和收藏状态
    post_like_statuses = batch_get_like_statuses(posts, current_user)
    post_bookmark_statuses = batch_get_bookmark_statuses(posts, current_user)

    posts.map do |post|
      post_id = post.id
      {
        post_id: post_id,
        liked: post_like_statuses[post_id] || false,
        bookmarked: post_bookmark_statuses[post_id] || false,
        can_edit: permissions.dig(:edit, post_id) || false,
        can_delete: permissions.dig(:delete, post_id) || false,
        can_pin: permissions.dig(:pin, post_id) || false,
        can_hide: permissions.dig(:hide, post_id) || false,
        can_comment: permissions.dig(:comment, post_id) || false
      }
    end
  end
end