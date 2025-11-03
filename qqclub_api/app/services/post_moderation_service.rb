# frozen_string_literal: true

# PostModerationService - 帖子管理服务
# 专门负责帖子的管理操作，包括置顶、隐藏、删除等
class PostModerationService < ApplicationService
  include ServiceInterface
  attr_reader :post, :user, :action, :reason

  def initialize(post:, user:, action:, reason: nil)
    super()
    @post = post
    @user = user
    @action = action
    @reason = reason
  end

  # 执行管理操作
  def call
    handle_errors do
      validate_moderation_params
      check_moderation_permission
      execute_moderation_action
      process_moderation_result
      format_success_response
    end
    self
  end

  private

  # 验证管理参数
  def validate_moderation_params
    return failure!("帖子不能为空") unless post
    return failure!("用户不能为空") unless user
    return failure!("帖子不存在") unless post.persisted?
    return failure!("用户不存在") unless user.persisted?

    valid_actions = [:pin, :unpin, :hide, :unhide, :delete]
    unless valid_actions.include?(action)
      return failure!("不支持的管理操作: #{action}")
    end
  end

  # 检查管理权限
  def check_moderation_permission
    case action
    when :pin, :unpin
      unless post.can_pin?(user)
        failure!("无权限置顶此帖子")
        return false
      end
    when :hide, :unhide
      unless post.can_hide?(user)
        failure!("无权限隐藏此帖子")
        return false
      end
    when :delete
      unless post.can_edit?(user)
        failure!("无权限删除此帖子")
        return false
      end
    end

    true
  end

  # 执行管理操作
  def execute_moderation_action
    case action
    when :pin
      post.pin!
    when :unpin
      post.unpin!
    when :hide
      post.hide!
    when :unhide
      post.unhide!
    when :delete
      post.destroy!
    end

    true
  rescue => e
    Rails.logger.error "Post moderation error: #{e.message}"
    failure!("管理操作失败: #{e.message}")
    false
  end

  # 处理管理操作结果
  def process_moderation_result
    # 记录管理操作日志
    log_moderation_event

    # 发送相关通知
    send_moderation_notifications

    # 更新统计信息（如果需要）
    update_statistics

    # 清理缓存
    clear_cache
  end

  # 记录管理操作日志
  def log_moderation_event
    action_text = case action
                  when :pin then "置顶"
                  when :unpin then "取消置顶"
                  when :hide then "隐藏"
                  when :unhide then "显示"
                  when :delete then "删除"
                  end

    log_message = "Post #{action_text}: ID #{post.id} by User #{user.id}"
    log_message += " - Reason: #{reason}" if reason.present?

    Rails.logger.info log_message
  end

  # 发送管理操作通知
  def send_moderation_notifications
    case action
    when :pin
      # 通知帖子作者帖子被置顶
      send_pin_notification
    when :hide
      # 通知帖子作者帖子被隐藏
      send_hide_notification
    when :delete
      # 通知帖子作者帖子被删除
      send_delete_notification
    end
  end

  # 发送置顶通知
  def send_pin_notification
    return if user.id == post.user_id # 自己操作自己不通知

    # NotificationService.post_pinned_notification(post, user)
  end

  # 发送隐藏通知
  def send_hide_notification
    return if user.id == post.user_id

    # NotificationService.post_hidden_notification(post, user, reason)
  end

  # 发送删除通知
  def send_delete_notification
    return if user.id == post.user_id

    # NotificationService.post_deleted_notification(post, user, reason)
  end

  # 更新统计信息
  def update_statistics
    case action
    when :pin
      # 更新置顶帖子统计
      update_pin_statistics
    when :hide
      # 更新隐藏帖子统计
      update_hide_statistics
    when :delete
      # 更新删除统计
      update_delete_statistics
    end
  end

  # 更新置顶统计
  def update_pin_statistics
    # 统计逻辑 - 检查字段是否存在
    if post.user.respond_to?(:pinned_posts_count)
      if action == :pin
        post.user.increment!(:pinned_posts_count)
      else
        post.user.decrement!(:pinned_posts_count)
      end
    end
  end

  # 更新隐藏统计
  def update_hide_statistics
    # 统计逻辑
  end

  # 更新删除统计
  def update_delete_statistics
    # 更新用户帖子数量 - 检查字段是否存在
    post.user.decrement!(:posts_count) if post.user.respond_to?(:posts_count)
  end

  # 清理缓存
  def clear_cache
    # 清理帖子相关的缓存
    Rails.cache.delete("post_#{post.id}")
    Rails.cache.delete("user_posts_#{post.user_id}")
    Rails.cache.delete("posts_list")
  end

  # 格式化成功响应
  def format_success_response
    action_text = case action
                  when :pin then "置顶"
                  when :unpin then "取消置顶"
                  when :hide then "隐藏"
                  when :unhide then "显示"
                  when :delete then "删除"
                  end

    response_data = {
      message: "帖子#{action_text}成功"
    }

    # 对于非删除操作，返回更新后的帖子数据
    unless action == :delete
      response_data[:post] = post_data(post)
    end

    success!(response_data)
  end

  # 格式化帖子数据
  def post_data(post)
    return nil if action == :delete
    post.as_json_for_api(current_user: user)
  end
end