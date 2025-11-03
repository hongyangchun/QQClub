# frozen_string_literal: true

# PostUpdateService - 帖子更新服务
# 专门负责帖子的更新逻辑，包括权限验证、内容更新等
class PostUpdateService < ApplicationService
  include ServiceInterface
  attr_reader :post, :user, :post_params

  def initialize(post:, user:, post_params:)
    super()
    @post = post
    @user = user
    @post_params = post_params
  end

  # 更新帖子
  def call
    handle_errors do
      validate_update_params
      check_edit_permission
      update_post
      process_post_update
      format_success_response
    end
    self
  end

  private

  # 验证更新参数
  def validate_update_params
    return failure!("帖子不能为空") unless post
    return failure!("用户不能为空") unless user
    return failure!("帖子不存在") unless post.persisted?
    return failure!("用户不存在") unless user.persisted?

    # 验证内容长度（如果提供）
    if post_params[:content].present?
      if post_params[:content].length < 10
        return failure!("内容长度不能少于10个字符")
      end

      if post_params[:content].length > 10000
        return failure!("内容长度不能超过10000个字符")
      end
    end

    # 验证标题长度（如果提供）
    if post_params[:title].present?
      if post_params[:title].length > 100
        return failure!("标题长度不能超过100个字符")
      end
    end
  end

  # 检查编辑权限
  def check_edit_permission
    unless post.can_edit?(user)
      failure!("无权限编辑此帖子")
      return false
    end

    true
  end

  # 更新帖子
  def update_post
    unless post.update(post_params)
      failure!(post.errors.full_messages)
      return false
    end

    true
  end

  # 处理帖子更新后的逻辑
  def process_post_update
    # 处理标签更新
    process_tags_update if post_params[:tags].present?

    # 处理图片更新
    process_images_update if post_params[:images].present?

    # 记录更新日志
    log_update_event

    # 发送更新通知（如果需要）
    send_update_notifications
  end

  # 处理标签更新
  def process_tags_update
    tags = post_params[:tags].map(&:strip).reject(&:blank?).uniq
    post.update!(tags: tags)
  end

  # 处理图片更新
  def process_images_update
    valid_images = post_params[:images].select { |url| valid_image_url?(url) }
    post.update!(images: valid_images)
  end

  # 验证图片URL
  def valid_image_url?(url)
    uri = URI.parse(url)
    uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
  rescue URI::InvalidURIError
    false
  end

  # 记录更新事件
  def log_update_event
    Rails.logger.info "Post updated: ID #{post.id} by User #{user.id}"
  end

  # 发送更新通知
  def send_update_notifications
    # 这里可以添加通知逻辑，比如通知关注者有更新
    # NotificationService.post_updated_notification(post)
  end

  # 格式化成功响应
  def format_success_response
    success!({
      message: "帖子更新成功",
      post: post_data(post)
    })
  end

  # 格式化帖子数据
  def post_data(post)
    post.as_json_for_api(current_user: user)
  end
end