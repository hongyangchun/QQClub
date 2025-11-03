# frozen_string_literal: true

# PostCreationService - 帖子创建服务
# 专门负责帖子的创建逻辑，包括内容验证、分类处理等
class PostCreationService < ApplicationService
  include ServiceInterface
  attr_reader :user, :post_params, :post

  def initialize(user:, post_params:)
    super()
    @user = user
    @post_params = post_params
    @post = nil
  end

  # 创建帖子
  def call
    handle_errors do
      validate_creation_params
      create_post
      process_post_creation
      format_success_response
    end
    self
  end

  private

  # 验证创建参数
  def validate_creation_params
    return failure!("用户不能为空") unless user
    return failure!("用户不存在") unless user.persisted?
    return failure!("标题不能为空") if post_params[:title].blank?
    return failure!("内容不能为空") if post_params[:content].blank?

    # 验证内容长度
    if post_params[:content].length < 10
      return failure!("内容长度不能少于10个字符")
    end

    if post_params[:content].length > 10000
      return failure!("内容长度不能超过10000个字符")
    end

    # 验证标题长度
    if post_params[:title].length > 100
      return failure!("标题长度不能超过100个字符")
    end
  end

  # 创建帖子记录
  def create_post
    @post = user.posts.new(post_params)

    unless @post.save
      failure!(@post.errors.full_messages)
      return false
    end

    true
  end

  # 处理帖子创建后的逻辑
  def process_post_creation
    # 处理标签
    process_tags if @post.tags.present?

    # 处理图片
    process_images if @post.images.present?

    # 更新用户统计
    update_user_stats

    # 记录创建日志
    log_creation_event

    # 发送通知（如果需要）
    send_creation_notifications
  end

  # 处理标签
  def process_tags
    # 标签规范化处理
    tags = @post.tags.map(&:strip).reject(&:blank?).uniq
    @post.update!(tags: tags)
  end

  # 处理图片
  def process_images
    # 图片URL验证和处理
    valid_images = @post.images.select { |url| valid_image_url?(url) }
    @post.update!(images: valid_images) if valid_images.size != @post.images.size
  end

  # 验证图片URL
  def valid_image_url?(url)
    uri = URI.parse(url)
    uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
  rescue URI::InvalidURIError
    false
  end

  # 更新用户统计
  def update_user_stats
    # 检查用户模型是否有posts_count字段
    user.increment!(:posts_count) if user.respond_to?(:posts_count)
  end

  # 记录创建事件
  def log_creation_event
    Rails.logger.info "Post created: ID #{@post.id} by User #{user.id}"
  end

  # 发送创建通知
  def send_creation_notifications
    # 这里可以添加通知逻辑，比如通知关注者
    # NotificationService.post_created_notification(@post)
  end

  # 格式化成功响应
  def format_success_response
    success!({
      message: "帖子创建成功",
      post: post_data(@post)
    })
  end

  # 格式化帖子数据
  def post_data(post)
    post.as_json_for_api(current_user: user, include_stats: true)
  end
end